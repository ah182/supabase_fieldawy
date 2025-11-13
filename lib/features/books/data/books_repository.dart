import 'package:fieldawy_store/features/books/domain/book_model.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BooksRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CachingService _cache;

  BooksRepository(this._cache);

  /// Get all books
  Future<List<Book>> getAllBooks() async {
    // استخدام Cache-First للكتب (تتغير ببطء)
    return await _cache.cacheFirst<List<Book>>(
      key: 'all_books',
      duration: CacheDurations.long, // ساعتين
      fetchFromNetwork: _fetchAllBooks,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => Book.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<Book>> _fetchAllBooks() async {
    try {
      final response = await _supabase.rpc('get_all_books');
      
      if (response == null) return [];
      
      final List<dynamic> data = response as List<dynamic>;
      // Cache as JSON List instead of Book objects
      _cache.set('all_books', data, duration: CacheDurations.long);
      return data.map((json) => Book.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load books: $e');
    }
  }

  /// Get current user's books
  Future<List<Book>> getMyBooks() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // استخدام Stale-While-Revalidate لكتب المستخدم
    return await _cache.staleWhileRevalidate<List<Book>>(
      key: 'my_books_$userId',
      duration: CacheDurations.medium, // 30 دقيقة
      staleTime: const Duration(minutes: 10), // تحديث بعد 10 دقائق
      fetchFromNetwork: _fetchMyBooks,
      fromCache: (data) {
        final List<dynamic> jsonList = data as List<dynamic>;
        return jsonList.map((json) => Book.fromJson(Map<String, dynamic>.from(json))).toList();
      },
    );
  }

  Future<List<Book>> _fetchMyBooks() async {
    try {
      final response = await _supabase.rpc('get_my_books');
      
      if (response == null) return [];
      
      final List<dynamic> data = response as List<dynamic>;
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        _cache.set('my_books_$userId', data, duration: CacheDurations.medium);
      }
      return data.map((json) => Book.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load my books: $e');
    }
  }

  /// Create a new book
  Future<String> createBook({
    required String name,
    required String author,
    required String description,
    required double price,
    required String phone,
    required String imageUrl,
  }) async {
    try {
      final response = await _supabase.rpc('create_book', params: {
        'p_name': name,
        'p_author': author,
        'p_description': description,
        'p_price': price,
        'p_phone': phone,
        'p_image_url': imageUrl,
      });
      
      // حذف الكاش بعد الإضافة
      _invalidateBooksCache();
      
      return response as String;
    } catch (e) {
      throw Exception('Failed to create book: $e');
    }
  }

  /// Update an existing book
  Future<bool> updateBook({
    required String bookId,
    required String name,
    required String author,
    required String description,
    required double price,
    required String phone,
    required String imageUrl,
  }) async {
    try {
      final response = await _supabase.rpc('update_book', params: {
        'p_book_id': bookId,
        'p_name': name,
        'p_author': author,
        'p_description': description,
        'p_price': price,
        'p_phone': phone,
        'p_image_url': imageUrl,
      });
      
      // حذف الكاش بعد التعديل
      _invalidateBooksCache();
      
      return response as bool;
    } catch (e) {
      throw Exception('Failed to update book: $e');
    }
  }

  /// Delete a book
  Future<bool> deleteBook(String bookId) async {
    try {
      final response = await _supabase.rpc('delete_book', params: {
        'p_book_id': bookId,
      });
      
      // حذف الكاش بعد الحذف
      _invalidateBooksCache();
      
      return response as bool;
    } catch (e) {
      throw Exception('Failed to delete book: $e');
    }
  }

  /// حذف كاش الكتب
  void _invalidateBooksCache() {
    _cache.invalidate('all_books');
    _cache.invalidateWithPrefix('my_books_');
    print('🧹 Books cache invalidated');
  }

  /// Increment book views
  Future<void> incrementBookViews(String bookId) async {
    try {
      await _supabase.rpc('increment_book_views', params: {
        'p_book_id': bookId,
      });
    } catch (e) {
      // Silent fail for views
      print('Failed to increment book views: $e');
    }
  }

  // ===================================================================
  // ADMIN METHODS
  // ===================================================================
  
  /// Admin: Get all books (for admin dashboard)
  Future<List<Book>> adminGetAllBooks() async {
    try {
      final response = await _supabase
          .from('vet_books')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List<dynamic>)
          .map((json) => Book.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load all books: $e');
    }
  }

  /// Admin: Delete any book
  Future<bool> adminDeleteBook(String bookId) async {
    try {
      await _supabase
          .from('vet_books')
          .delete()
          .eq('id', bookId);
      
      // حذف الكاش
      _invalidateBooksCache();
      
      return true;
    } catch (e) {
      throw Exception('Failed to delete book: $e');
    }
  }

  /// Admin: Update any book
  Future<bool> adminUpdateBook({
    required String bookId,
    required String name,
    required String author,
    required double price,
    required String phone,
    required String description,
  }) async {
    try {
      await _supabase
          .from('vet_books')
          .update({
            'name': name,
            'author': author,
            'price': price,
            'phone': phone,
            'description': description,
          })
          .eq('id', bookId);
      
      // حذف الكاش
      _invalidateBooksCache();
      
      return true;
    } catch (e) {
      throw Exception('Failed to update book: $e');
    }
  }
}

// Provider
final booksRepositoryProvider = Provider<BooksRepository>((ref) {
  final cache = ref.watch(cachingServiceProvider);
  return BooksRepository(cache);
});
