import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'caching_service.g.dart';

/// استراتيجيات الكاش المختلفة
enum CacheStrategy {
  /// Cache-First: يعطي الأولوية للكاش، مناسب للبيانات النادرة التغيير
  cacheFirst,
  
  /// Network-First: يعطي الأولوية للشبكة، مناسب للبيانات الحساسة
  networkFirst,
  
  /// Stale-While-Revalidate: يعيد البيانات المخزنة فوراً ويحدثها في الخلفية
  staleWhileRevalidate,
}

/// مدد الكاش المحددة مسبقاً
class CacheDurations {
  static const Duration veryShort = Duration(minutes: 5);    // للبيانات الحساسة
  static const Duration short = Duration(minutes: 15);       // للبيانات المتغيرة بسرعة
  static const Duration medium = Duration(minutes: 30);      // للبيانات المتوسطة
  static const Duration long = Duration(hours: 2);           // للبيانات النادرة التغيير
  static const Duration veryLong = Duration(hours: 24);      // للبيانات الثابتة
}

@HiveType(typeId: 2)
class CacheEntry {
  @HiveField(0)
  final dynamic data;

  @HiveField(1)
  final DateTime expiryTime;

  @HiveField(2)
  final DateTime createdAt;

  CacheEntry(this.data, this.expiryTime, [DateTime? createdAt]) 
      : createdAt = createdAt ?? DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiryTime);
  
  Duration get age => DateTime.now().difference(createdAt);
}

/// إحصائيات الكاش
class CacheStats {
  int hits = 0;
  int misses = 0;
  int sets = 0;
  int invalidations = 0;

  double get hitRate => (hits + misses) == 0 ? 0 : hits / (hits + misses);
  
  Map<String, dynamic> toMap() => {
    'hits': hits,
    'misses': misses,
    'sets': sets,
    'invalidations': invalidations,
    'hit_rate': hitRate,
  };
}

class CachingService {
  final Box _box;
  final CacheStats _stats = CacheStats();
  
  CachingService(this._box);

  /// الحصول على الإحصائيات
  CacheStats get stats => _stats;

  /// الطريقة الأساسية: الحصول على البيانات من الكاش
  T? get<T>(String key) {
    final entry = _box.get(key) as CacheEntry?;

    if (entry != null && !entry.isExpired) {
      _stats.hits++;
      if (kDebugMode) {
        print('✅ Cache HIT for key: $key (age: ${entry.age.inMinutes}m)');
      }
      return entry.data as T;
    }

    _stats.misses++;
    if (kDebugMode) {
      print('❌ Cache MISS for key: $key');
    }
    return null;
  }

  /// الطريقة الأساسية: حفظ البيانات في الكاش
  void set<T>(String key, T data, {Duration duration = const Duration(minutes: 10)}) {
    final expiryTime = DateTime.now().add(duration);
    _box.put(key, CacheEntry(data, expiryTime));
    _stats.sets++;
    if (kDebugMode) {
      print('💾 Cache SET for key: $key (expires in ${duration.inMinutes}m)');
    }
  }

  /// استراتيجية Cache-First مع Fallback للشبكة
  /// مناسبة للبيانات النادرة التغيير (Clinics, Static Data)
  Future<T> cacheFirst<T>({
    required String key,
    required Future<T> Function() fetchFromNetwork,
    Duration duration = const Duration(minutes: 30),
    T Function(dynamic)? fromCache,
  }) async {
    // محاولة الحصول على البيانات من الكاش أولاً
    final cached = get(key);
    if (cached != null) {
      return fromCache != null ? fromCache(cached) : cached as T;
    }

    // إذا لم تكن موجودة، جلبها من الشبكة
    // ملاحظة: fetchFromNetwork مسؤول عن حفظ البيانات في الكاش
    final data = await fetchFromNetwork();
    return data;
  }

  /// استراتيجية Network-First مع Fallback للكاش
  /// مناسبة للبيانات الحساسة (User Profile, Critical Data)
  Future<T> networkFirst<T>({
    required String key,
    required Future<T> Function() fetchFromNetwork,
    Duration duration = const Duration(minutes: 10),
    T Function(dynamic)? fromCache,
  }) async {
    try {
      // محاولة جلب البيانات من الشبكة أولاً
      // ملاحظة: fetchFromNetwork مسؤول عن حفظ البيانات في الكاش
      final data = await fetchFromNetwork();
      return data;
    } catch (e) {
      // في حالة الفشل، استخدم الكاش
      final cached = get(key);
      if (cached != null) {
        if (kDebugMode) {
          print('⚠️ Network failed, using stale cache for: $key');
        }
        return fromCache != null ? fromCache(cached) : cached as T;
      }
      rethrow;
    }
  }

  /// استراتيجية Stale-While-Revalidate
  /// تعيد البيانات القديمة فوراً وتحدثها في الخلفية
  /// مناسبة للبيانات المتغيرة بانتظام (Products, Offers)
  Future<T> staleWhileRevalidate<T>({
    required String key,
    required Future<T> Function() fetchFromNetwork,
    Duration duration = const Duration(minutes: 30),
    Duration staleTime = const Duration(minutes: 15),
    T Function(dynamic)? fromCache,
  }) async {
    final entry = _box.get(key) as CacheEntry?;
    
    // إذا كانت البيانات موجودة وغير منتهية الصلاحية
    if (entry != null && !entry.isExpired) {
      final data = fromCache != null ? fromCache(entry.data) : entry.data as T;
      
      // إذا كانت البيانات قديمة (stale)، حدثها في الخلفية
      if (entry.age > staleTime) {
        if (kDebugMode) {
          print('🔄 Returning stale cache and revalidating: $key');
        }
        // تحديث في الخلفية بدون انتظار
        // ملاحظة: fetchFromNetwork مسؤول عن حفظ البيانات في الكاش
        fetchFromNetwork().then((_) {
          // Success - data refreshed in background
        }).catchError((e) {
          if (kDebugMode) {
            print('⚠️ Background revalidation failed for: $key - $e');
          }
        });
      }
      
      _stats.hits++;
      return data;
    }

    // إذا لم تكن موجودة أو منتهية الصلاحية، جلبها من الشبكة
    _stats.misses++;
    // ملاحظة: fetchFromNetwork مسؤول عن حفظ البيانات في الكاش
    final data = await fetchFromNetwork();
    return data;
  }

  /// الطريقة الأساسية: حذف مفتاح معين
  void invalidate(String key) {
    _box.delete(key);
    _stats.invalidations++;
    if (kDebugMode) {
      print('🗑️ Cache INVALIDATED for key: $key');
    }
  }

  /// حذف جميع المفاتيح التي تبدأ بـ prefix معين
  void invalidateWithPrefix(String prefix) {
    final keysToDelete = _box.keys.where((k) => k is String && k.startsWith(prefix));
    _box.deleteAll(keysToDelete);
    _stats.invalidations += keysToDelete.length;
    if (kDebugMode) {
      print('🗑️ Cache INVALIDATED for prefix: $prefix (${keysToDelete.length} keys)');
    }
  }

  /// حذف البيانات المنتهية الصلاحية فقط
  Future<int> cleanupExpired() async {
    int cleaned = 0;
    final keysToDelete = <dynamic>[];
    
    for (var key in _box.keys) {
      final entry = _box.get(key);
      if (entry is CacheEntry && entry.isExpired) {
        keysToDelete.add(key);
        cleaned++;
      }
    }
    
    await _box.deleteAll(keysToDelete);
    
    if (kDebugMode && cleaned > 0) {
      print('🧹 Cleaned up $cleaned expired cache entries');
    }
    
    return cleaned;
  }

  /// مسح جميع البيانات
  Future<void> clear() async {
    await _box.clear();
    if (kDebugMode) {
      print('🗑️ Cache CLEARED');
    }
  }

  /// الحصول على حجم الكاش
  int get size => _box.length;

  /// الحصول على جميع المفاتيح
  Iterable<dynamic> get keys => _box.keys;
}

final cachingServiceProvider = Provider<CachingService>((ref) {
  final box = Hive.box('api_cache');
  return CachingService(box);
});