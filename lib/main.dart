import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:fieldawy_store/core/services/http_overrides.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:fieldawy_store/features/authentication/presentation/screens/auth_gate.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/login_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/splash_screen.dart';
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';
import 'package:fieldawy_store/features/reviews/products_reviews_screen.dart';
import 'package:fieldawy_store/features/reviews/review_system.dart';

// ignore: unused_import
import 'features/admin_dashboard/presentation/screens/admin_login_screen.dart';
import 'features/admin_dashboard/presentation/screens/admin_login_real.dart';
import 'features/admin_dashboard/presentation/widgets/admin_scaffold.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ignore: unused_import
import 'package:pdfrx/pdfrx.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/language_provider.dart';
import 'features/authentication/data/storage_service.dart';
import 'services/app_state_manager.dart';
import 'services/fcm_token_service.dart';
import 'services/notification_preferences_service.dart';
import 'services/distributor_subscription_service.dart';
import 'services/subscription_cache_service.dart';
import 'core/supabase/supabase_init.dart';
import 'package:fieldawy_store/features/authentication/domain/user_model.dart';
import 'package:fieldawy_store/core/caching/caching_service.dart';
import 'package:fieldawy_store/features/orders/domain/order_item_model.dart';
import 'package:fieldawy_store/features/products/domain/product_model.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Firebase imports
import 'package:firebase_core/firebase_core.dart';

// ✅ ملف إعدادات Firebase
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: "AIzaSyAySg6p5glXrsJUV2xPqzx47DDj0f3hy3c",
      appId: "1:665551059689:android:cd266cedbef84f5c888e78",
      messagingSenderId: "665551059689",
      projectId: "fieldawy-store-app",
      storageBucket: "fieldawy-store-app.firebasestorage.app",
    );
  }
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// GlobalKey للـ navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Store pending notification data when app is not ready
String? _pendingNotificationScreen;
String? _pendingNotificationDistributorId;

// Getters for pending notification
String? getPendingNotificationScreen() => _pendingNotificationScreen;
String? getPendingNotificationDistributorId() => _pendingNotificationDistributorId;
void clearPendingNotification() {
  _pendingNotificationScreen = null;
  _pendingNotificationDistributorId = null;
}

// ✅ handler للرسائل في الخلفية
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    print('🔵 === Background handler started ===');
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  
  // Initialize Hive for background operations (for subscription cache)
  try {
    await Hive.initFlutter();
  } catch (e) {
    print('Hive already initialized in background: $e');
  }
  
  // Initialize subscription cache service
  await SubscriptionCacheService.init();
  
  // Initialize Supabase for background operations
  try {
    await Supabase.initialize(
      url: 'https://rkukzuwerbvmueuxadul.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrdWt6dXdlcmJ2bXVldXhhZHVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc4NTcwODcsImV4cCI6MjA3MzQzMzA4N30.Rs69KRvvB8u6A91ZXIzkmWebO_IyavZXJrO-SXa2_mc',
    );
  } catch (e) {
    // Supabase already initialized
    print('Supabase already initialized in background: $e');
  }
  
  final data = message.data;
  
  // إنشاء وتهيئة notification plugin في background
  final FlutterLocalNotificationsPlugin localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@drawable/ic_notification');
  await localNotifications.initialize(
    const InitializationSettings(android: androidSettings),
  );

  // إنشاء القنوات
  const AndroidNotificationChannel ordersChannel = AndroidNotificationChannel(
    'orders_channel',
    'طلبات جديدة',
    description: 'إشعارات الطلبات والمبيعات',
    importance: Importance.max,
  );

  const AndroidNotificationChannel offersChannel = AndroidNotificationChannel(
    'offers_channel',
    'العروض والتخفيضات',
    description: 'إشعارات العروض الخاصة والتخفيضات',
    importance: Importance.high,
  );

  const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
    'general_channel',
    'إشعارات عامة',
    description: 'إشعارات عامة من التطبيق',
    importance: Importance.defaultImportance,
  );

  await localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(ordersChannel);

  await localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(offersChannel);

  await localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(generalChannel);

  // استخراج البيانات
  final String title = data['title'] ?? 'إشعار جديد';
  String body = data['body'] ?? '';
  final String type = data['type'] ?? 'general';
  final String screen = data['screen'] ?? 'home';
  final String? distributorId = data['distributor_id'];
  final String? productName = data['product_name'];
  final String? distributorName = data['distributor_name'];
  
  // ✅ تخطي الإشعارات الفارغة
  if (body.trim().isEmpty && productName == null) {
    print('⏭️ تم تخطي إشعار فارغ (بدون body أو product name)');
    return;
  }
  
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  
  print('📋 Background notification check:');
  print('   Current User ID: ${currentUserId ?? "Not logged in"}');
  print('   Distributor ID: ${distributorId ?? "None"}');
  print('   Title: $title');
  
  // ⏭️ تخطي الإشعار إذا كان المرسل هو المستقبل (لا يجب أن يستقبل إشعاراته الخاصة)
  if (distributorId != null && currentUserId != null && distributorId == currentUserId) {
    print('⏭️ تم تخطي الإشعار: المرسل هو المستقبل');
    return;
  }
  
  // ✅ فلترة الإشعارات حسب تفضيلات المستخدم المستقبل (وليس المرسل)
  // هنا نفحص إعدادات الاستقبال الخاصة بالمستخدم الحالي
  // المرسل (الموزع) يمكنه إرسال الإشعارات حتى لو كان قافل استقباله لنفس النوع
  bool shouldShow = true;
  bool isSubscribedToDistributor = false;
  try {
    shouldShow = await _shouldShowNotification(screen, distributorId: distributorId);
    print('   Should show: $shouldShow');
    
    // Check subscription status for price updates from distributors
    if (shouldShow && (screen == 'price_action' || screen == 'expire_soon_price') && distributorId != null && distributorId.isNotEmpty) {
      if (currentUserId != null) {
        isSubscribedToDistributor = await DistributorSubscriptionService.isSubscribed(distributorId);
      } else {
        isSubscribedToDistributor = await SubscriptionCacheService.isSubscribedCached(distributorId);
      }
      print('   Is subscribed to distributor: $isSubscribedToDistributor');
      print('   Product name: $productName');
      print('   Distributor name: $distributorName');
      
      // Customize body based on subscription status
      if (isSubscribedToDistributor && productName != null && distributorName != null && distributorName.isNotEmpty) {
        // User IS subscribed - show distributor name first, then product name
        body = '$distributorName\n$productName';
        print('   Body customized (subscribed): $body');
      } else if (productName != null && productName.isNotEmpty) {
        // User is NOT subscribed OR distributor name not available
        // Show product name only
        body = productName;
        print('   Body customized (not subscribed or no distributor name): $body');
      }
    }
  } catch (e) {
    print('⚠️ خطأ في فحص الإشعارات في الخلفية: $e');
    // في حالة الخطأ، نعرض الإشعار
    shouldShow = true;
  }
  
  if (!shouldShow) {
    print('⏭️ تم تخطي الإشعار: $title (تم تعطيله في الإعدادات)');
    return;
  }

  print('📩 إشعار في الخلفية:');
  print('   العنوان: $title');
  print('   المحتوى (قبل التخصيص): $body');
  print('   النوع: $type');
  print('   الموزع: ${distributorId ?? "عام"}');

  // ✅ إشعارات التقييمات فيها notification payload من FCM - مش محتاجين نعرضها
  // FCM بيعرضهم تلقائياً → لو عرضناهم هنا هيتكرروا!
  if (type == 'new_product_review' || type == 'new_review_request') {
    print('⏭️ Skipping review notification - FCM already shows it');
    print('🔵 === Background handler completed successfully ===');
    return;
  }

  // ✅ نعرض الإشعار مع التخصيص الكامل (نفس الـ foreground)
  // باقي الإشعارات (منتجات، موزعين، إلخ) محتاجين نعرضها هنا
  
  // تحديد القناة واللون
  String channelId = 'general_channel';
  String channelName = 'إشعارات عامة';
  Color color = const Color(0xFF2196F3);

  if (type == 'order') {
    channelId = 'orders_channel';
    channelName = 'طلبات جديدة';
    color = const Color(0xFF4CAF50);
  } else if (type == 'offer') {
    channelId = 'offers_channel';
    channelName = 'العروض والتخفيضات';
    color = const Color(0xFFFF9800);
  }

  // Build payload: JSON string with all data
  final payloadData = {
    'screen': screen,
    'distributor_id': distributorId,
    'type': type,
    'review_request_id': data['review_request_id'],
    'product_id': data['product_id'],
    'product_type': data['product_type'],
  };
  final payload = jsonEncode(payloadData);

  print('   المحتوى النهائي: $body');
  print('   Payload: $payload');
  
  // عرض الإشعار المخصص
  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'إشعارات $channelName',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        color: color,
        colorized: true,
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        styleInformation: body.length > 50
            ? BigTextStyleInformation(
                body,
                contentTitle: title,
                summaryText: 'Fieldawy Store',
              )
            : null,
        ticker: title,
        showWhen: true,
        category: AndroidNotificationCategory.message,
        tag: 'fieldawy_${DateTime.now().millisecondsSinceEpoch}', // منع التكرار
      ),
    ),
    payload: payload,
  );
  
  print('🔵 === Background handler completed successfully ===');
  } catch (e, stackTrace) {
    print('❌❌❌ FATAL ERROR in background handler: $e');
    print('Stack trace: $stackTrace');
  }
}

// ✅ دالة للتحقق من تفضيلات الإشعارات للمستقبل فقط
// هذه الدالة تفحص إعدادات استقبال الإشعارات للمستخدم الحالي (المستقبل)
// ولا تتأثر بإعدادات المرسل - فالموزع يمكنه إرسال إشعارات حتى لو قافل استقباله
Future<bool> _shouldShowNotification(String screen, {String? distributorId}) async {
  print('🔍 _shouldShowNotification called: screen=$screen, distributor=$distributorId');
  try {
    // تحديد نوع الإشعار من screen name
    String? notificationType;
    
    switch (screen) {
      case 'price_action':
        notificationType = 'price_action';
        break;
      case 'expire_soon':
        notificationType = 'expire_soon';
        break;
      case 'offers':
        notificationType = 'offers';
        break;
      case 'surgical':
        notificationType = 'surgical_tools';
        break;
      default:
        // أنواع أخرى (home, orders, إلخ) تُعرض دائماً
        notificationType = null;
    }
    
    // أولاً: فحص إذا كان الإشعار من موزع معين
    if (distributorId != null && distributorId.isNotEmpty) {
      // Check if user is logged in
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      bool isSubscribedToDistributor;
      if (userId != null) {
        // User is logged in, check from Supabase
        isSubscribedToDistributor = await DistributorSubscriptionService.isSubscribed(distributorId);
      } else {
        // User not logged in (background isolate), check from local cache
        print('📦 Checking subscription from local cache (background mode)');
        isSubscribedToDistributor = await SubscriptionCacheService.isSubscribedCached(distributorId);
      }
      
      if (isSubscribedToDistributor) {
        // إذا كان مشترك في الموزع، يستقبل كل إشعاراته (override للإعدادات العامة)
        print('✅ إشعار من موزع مشترك فيه - سيُعرض');
        return true;
      }
      // إذا لم يكن مشترك، نكمل للإعدادات العامة
      print('ℹ️ إشعار من موزع غير مشترك - نفحص الإعدادات العامة');
    }
    
    // ثانياً: فحص الإعدادات العامة
    if (notificationType == null) {
      // أنواع أخرى تُعرض دائماً
      return true;
    }
    
    // التحقق من تفضيلات المستخدم العامة
    final isEnabled = await NotificationPreferencesService.isNotificationEnabled(notificationType);
    print('📋 فحص الإعدادات العامة لـ $notificationType: ${isEnabled ? "مفعل" : "معطل"}');
    return isEnabled;
  } catch (e) {
    print('⚠️ خطأ في فحص تفضيلات الإشعارات: $e');
    // في حالة الخطأ، نعرض الإشعار (افتراضي)
    return true;
  }
}

// دالة للتعامل مع النقر على الإشعارات
void _handleNotificationTap(String screen, {String? distributorId, Map<String, dynamic>? data}) {
  print('🔔 معالجة النقر على الإشعار: $screen, distributor: $distributorId, data: $data');
  
  final context = navigatorKey.currentContext;
  
  if (context != null) {
    // Context متاح، نفذ التنقل مباشرة
    print('✅ NavigatorContext متاح - بدء التنقل');
    _performNavigation(context, screen, distributorId, data: data);
  } else {
    // Context مش متاح، احفظ الـ notification للاستخدام لاحقاً
    print('⏳ NavigatorContext غير متاح - حفظ الإشعار للمعالجة لاحقاً');
    _pendingNotificationScreen = screen;
    _pendingNotificationDistributorId = distributorId;
  }
}

// دالة منفصلة لتنفيذ التنقل
void _performNavigation(BuildContext context, String screen, String? distributorId, {Map<String, dynamic>? data}) async {
  // ✅ معالجة إشعارات التقييمات
  if (data != null && data['type'] != null) {
    final type = data['type'];
    
    // إشعار طلب تقييم جديد → صفحة التقييمات العامة
    if (type == 'new_review_request') {
      print('🔔 الانتقال إلى صفحة التقييمات العامة');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ProductsWithReviewsScreen(),
        ),
      );
      return; 
    }
    
    // إشعار تعليق/تقييم جديد → صفحة تفاصيل التقييمات للمنتج
    if (type == 'new_product_review') {
      final reviewRequestId = data['review_request_id'];
      if (reviewRequestId != null) {
        print('🔔 الانتقال إلى صفحة تفاصيل التقييمات: $reviewRequestId');
        
        // جلب بيانات الـ request من Supabase
        try {
          final response = await Supabase.instance.client
              .from('review_requests')
              .select()
              .eq('id', reviewRequestId)
              .single();
          
          final request = ReviewRequestModel.fromJson(response);
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductReviewDetailsScreen(request: request),
            ),
          );
        } catch (e) {
          print('❌ خطأ في جلب بيانات التقييم: $e');
          // في حالة الخطأ، نروح للصفحة العامة
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ProductsWithReviewsScreen(),
            ),
          );
        }
        return;
      }
    }
  }
  
  // ✅ فقط منتج جديد (home) + مشترك → صفحة الموزع
  // باقي الحالات → التاب المناسب
  if (distributorId != null && distributorId.isNotEmpty && screen == 'home') {
    // فحص الاشتراك
    final userId = Supabase.instance.client.auth.currentUser?.id;
    bool isSubscribed = false;
    
    if (userId != null) {
      isSubscribed = await DistributorSubscriptionService.isSubscribed(distributorId);
    } else {
      isSubscribed = await SubscriptionCacheService.isSubscribedCached(distributorId);
    }
    
    if (isSubscribed) {
      print('🔔 منتج جديد من موزع مشترك - الانتقال إلى صفحة الموزع: $distributorId');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => DrawerWrapper(distributorId: distributorId),
        ),
        (route) => false,
      );
      return;
    } else {
      print('🔔 منتج جديد من موزع غير مشترك - الانتقال إلى Home tab');
      // هنكمل للكود العادي (home tab)
    }
  }

  // تحديد tab index بناءً على screen
  final tabIndex = _getTabIndexFromScreen(screen);
  
  print('🔔 الانتقال إلى Tab: $tabIndex ($screen)');

  // الانتقال إلى HomeScreen مع التاب المحدد
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (context) => DrawerWrapper(initialTabIndex: tabIndex),
    ),
    (route) => false,
  );
}

// دالة مساعدة لتحديد tab index من screen name
int _getTabIndexFromScreen(String screen) {
  switch (screen) {
    case 'home':
      return 0;
    case 'price_action':
      return 1;
    case 'expire_soon':
      return 2;
    case 'surgical':
      return 3;
    case 'offers':
      return 4;
    default:
      return 0;
  }
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase initialization
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ تعطيل Firebase Messaging على الويب (للـ Admin Dashboard)
  // فقط للموبايل
  if (!kIsWeb) {
    // ✅ إعداد handler للخلفية
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ✅ طلب إذن من المستخدم
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // ✅ الحصول على FCM Token وحفظه في Supabase (سيتم بعد تسجيل الدخول)
    String? fcmToken = await FirebaseMessaging.instance.getToken();
  print('═══════════════════════════════════════════════════════════');
  print('🔑 FCM TOKEN للاختبار:');
  print('═══════════════════════════════════════════════════════════');
  if (fcmToken != null) {
    print(fcmToken);
    print('═══════════════════════════════════════════════════════════');
    print('✅ تم الحصول على FCM Token بنجاح');
    print('💾 سيتم حفظه في Supabase بعد تسجيل الدخول');
  } else {
    print('❌ فشل الحصول على FCM Token');
  }
  print('═══════════════════════════════════════════════════════════');

  // ✅ الاشتراك في Topics تلقائياً
  try {
    await FirebaseMessaging.instance.subscribeToTopic('all_users');
    print('✅ تم الاشتراك في topic: all_users بنجاح');
  } catch (e) {
    print('❌ خطأ في الاشتراك في topic: $e');
  }
  
  // ✅ حفظ FCM Token في Supabase (للاختبار)
  if (fcmToken != null) {
    print('📤 محاولة حفظ FCM Token في Supabase...');
  }
  
  // يمكنك إضافة topics أخرى حسب نوع المستخدم
  // await FirebaseMessaging.instance.subscribeToTopic('orders');
  // await FirebaseMessaging.instance.subscribeToTopic('offers');

  // ✅ الاستماع لتحديثات الـ Token
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print('🔄 تم تحديث FCM Token الجديد');
    // سيتم حفظه تلقائياً عبر FCMTokenService
  });

  // ✅ معالجة النقر على الإشعار عندما يكون التطبيق مغلق
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      print('🔔 تم فتح التطبيق من الإشعار: ${message.data}');
      final screen = message.data['screen'] ?? 'home';
      final distributorId = message.data['distributor_id'];
      _handleNotificationTap(screen, distributorId: distributorId, data: message.data);
    }
  });

  // ✅ معالجة النقر على الإشعار عندما يكون التطبيق في الخلفية
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    print('🔔 تم فتح الإشعار من الخلفية: ${message.data}');
    final screen = message.data['screen'] ?? 'home';
    final distributorId = message.data['distributor_id'];
    _handleNotificationTap(screen, distributorId: distributorId, data: message.data);
  });

  // ✅ إعدادات الإشعارات المحلية
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // إنشاء قنوات الإشعارات
  const AndroidNotificationChannel ordersChannel = AndroidNotificationChannel(
    'orders_channel',
    'طلبات جديدة',
    description: 'إشعارات الطلبات والمبيعات',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  const AndroidNotificationChannel offersChannel = AndroidNotificationChannel(
    'offers_channel',
    'العروض والتخفيضات',
    description: 'إشعارات العروض الخاصة والتخفيضات',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
    'general_channel',
    'إشعارات عامة',
    description: 'إشعارات عامة من التطبيق',
    importance: Importance.defaultImportance,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  // تسجيل القنوات
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(ordersChannel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(offersChannel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(generalChannel);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_notification');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  // معالجة النقر على الإشعار
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        print('🔔 تم النقر على الإشعار: ${response.payload}');
        
        try {
          // Parse JSON payload
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          final screen = data['screen'] ?? 'home';
          final distributorId = data['distributor_id'];
          
          _handleNotificationTap(screen, distributorId: distributorId, data: data);
        } catch (e) {
          print('❌ خطأ في parse الـ payload: $e');
          // Fallback: old format "screen|distributor_id"
          final parts = response.payload!.split('|');
          final screen = parts[0];
          final distributorId = parts.length > 1 ? parts[1] : null;
          _handleNotificationTap(screen, distributorId: distributorId);
        }
      }
    },
  );

    // ✅ listen للإشعارات أثناء فتح التطبيق (data-only messages)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    try {
      print('🟢 === Foreground handler started ===');
      
      final data = message.data;

      // استخراج البيانات من data payload
      final String title = data['title'] ?? 'إشعار جديد';
      String body = data['body'] ?? '';
      final String type = data['type'] ?? 'general';
      final String screen = data['screen'] ?? 'home';
      final String? distributorId = data['distributor_id'];
      final String? productName = data['product_name'];
      final String? distributorName = data['distributor_name'];

      // ✅ تخطي الإشعارات الفارغة
      if (body.trim().isEmpty && productName == null) {
        print('⏭️ تم تخطي إشعار فارغ (بدون body أو product name)');
        return;
      }

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    
    print('📱 Foreground notification received:');
    print('   Current User ID: ${currentUserId ?? "Not logged in"}');
    print('   Distributor ID: ${distributorId ?? "None"}');
    print('   Title: $title');
    
    // ⏭️ تخطي الإشعار إذا كان المرسل هو المستقبل (لا يجب أن يستقبل إشعاراته الخاصة)
    if (distributorId != null && currentUserId != null && distributorId == currentUserId) {
      print('⏭️ تم تخطي الإشعار: المرسل هو المستقبل');
      return;
    }

    // ✅ فلترة الإشعارات حسب تفضيلات المستخدم المستقبل (وليس المرسل)
    // هنا نفحص إعدادات الاستقبال الخاصة بالمستخدم الحالي
    // المرسل (الموزع) يمكنه إرسال الإشعارات حتى لو كان قافل استقباله لنفس النوع
    bool shouldShow = true;
    bool isSubscribedToDistributor = false;
    try {
      shouldShow = await _shouldShowNotification(screen, distributorId: distributorId);
      print('   Should show: $shouldShow');
      
      // Check subscription status for price updates from distributors
      if (shouldShow && (screen == 'price_action' || screen == 'expire_soon_price') && distributorId != null && distributorId.isNotEmpty) {
        isSubscribedToDistributor = await DistributorSubscriptionService.isSubscribed(distributorId);
        print('   Is subscribed to distributor: $isSubscribedToDistributor');
        print('   Product name: $productName');
        print('   Distributor name: $distributorName');
        
        // Customize body based on subscription status
        if (isSubscribedToDistributor && productName != null && distributorName != null && distributorName.isNotEmpty) {
          // User IS subscribed - show distributor name first, then product name
          body = '$distributorName\n$productName';
          print('   Body customized (subscribed): $body');
        } else if (productName != null && productName.isNotEmpty) {
          // User is NOT subscribed OR distributor name not available
          // Show product name only
          body = productName;
          print('   Body customized (not subscribed or no distributor name): $body');
        }
      }
    } catch (e) {
      print('⚠️ خطأ في فحص الإشعارات: $e');
      shouldShow = true;
    }
    
    if (!shouldShow) {
      print('⏭️ تم تخطي الإشعار: $title (تم تعطيله في الإعدادات)');
      return;
    }

    // تحديد نوع الإشعار والقناة المناسبة
    String channelId = 'general_channel';
    String channelName = 'إشعارات عامة';
    Color color = const Color(0xFF2196F3);

    if (type == 'order') {
      channelId = 'orders_channel';
      channelName = 'طلبات جديدة';
      color = const Color(0xFF4CAF50);
    } else if (type == 'offer') {
      channelId = 'offers_channel';
      channelName = 'العروض والتخفيضات';
      color = const Color(0xFFFF9800);
    }

    print('📩 إشعار جديد: $title');
    print('📝 المحتوى: $body');
    print('🏷️ النوع: $type');
    print('👤 الموزع: ${distributorId ?? "عام"}');

    // Build payload: JSON string with all data
    final payloadData = {
      'screen': screen,
      'distributor_id': distributorId,
      'type': type,
      'review_request_id': data['review_request_id'],
      'product_id': data['product_id'],
      'product_type': data['product_type'],
    };
    final payload = jsonEncode(payloadData);
    
    flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'إشعارات $channelName',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          color: color,
          colorized: true,
          icon: '@drawable/ic_notification',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
          styleInformation: body.length > 50
              ? BigTextStyleInformation(
                  body,
                  contentTitle: title,
                  summaryText: 'Fieldawy Store',
                  htmlFormatContentTitle: true,
                  htmlFormatSummaryText: true,
                )
              : null,
          ticker: title,
          showWhen: true,
          category: AndroidNotificationCategory.message,
        ),
      ),
      payload: payload,
    );
    
      print('🟢 === Foreground handler completed successfully ===');
    } catch (e, stackTrace) {
      print('❌❌❌ FATAL ERROR in foreground handler: $e');
      print('Stack trace: $stackTrace');
    }
    });
  } // End of if (!kIsWeb) for Firebase Messaging

  // pdfrxFlutterInitialize(); // Not needed in pdfrx 1.3.5
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Hive.initFlutter();
  Hive.registerAdapter(ProductModelAdapter());
  Hive.registerAdapter(OrderItemModelAdapter());
  Hive.registerAdapter(CacheEntryAdapter());
  Hive.registerAdapter(UserModelAdapter());
  await Hive.openBox<OrderItemModel>('orders');
  await Hive.openBox('favorites'); // Store as Map<String, Map<String, dynamic>>
  await Hive.openBox('api_cache');
  
  // Initialize subscription cache for background notifications
  await SubscriptionCacheService.init();
  print('✅ Subscription cache initialized');

  // Wrap with ProviderScope for Riverpod
  runApp(
    const ProviderScope(
      child: ConnectivityHandler(),
    ),
  );
}

class ConnectivityHandler extends StatefulWidget {
  const ConnectivityHandler({super.key});

  @override
  State<ConnectivityHandler> createState() => _ConnectivityHandlerState();
}

class _ConnectivityHandlerState extends State<ConnectivityHandler> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOffline = result.contains(ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Stack(
        children: [
          const InitializedApp(),
          if (_isOffline) const NoInternetScreen(),
        ],
      ),
    );
  }
}

class InitializedApp extends ConsumerStatefulWidget {
  const InitializedApp({super.key});

  @override
  ConsumerState<InitializedApp> createState() => _InitializedAppState();
}

class _InitializedAppState extends ConsumerState<InitializedApp> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    await initSupabase();
    unawaited(StorageService().cleanupTempImages());
    
    // ✅ إعداد FCM Token Service لحفظ Token في Supabase
    _setupFCMTokenService();
  }

  void _setupFCMTokenService() {
    final fcmService = FCMTokenService();
    
    // حفظ Token إذا كان المستخدم مسجل دخول بالفعل
    if (Supabase.instance.client.auth.currentUser != null) {
      print('👤 المستخدم مسجل دخول - جاري حفظ FCM Token...');
      fcmService.getAndSaveToken();
    }
    
    // الاستماع لتغييرات حالة المصادقة
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      
      if (event == AuthChangeEvent.signedIn) {
        print('🔐 تم تسجيل الدخول - جاري حفظ FCM Token...');
        fcmService.getAndSaveToken();
        
        // Sync distributor subscriptions to local cache
        print('📦 Syncing subscriptions to local cache...');
        try {
          final subscriptions = await DistributorSubscriptionService.getSubscribedDistributorIds();
          print('✅ Synced ${subscriptions.length} subscriptions to cache');
        } catch (e) {
          print('⚠️ Error syncing subscriptions: $e');
        }
      } else if (event == AuthChangeEvent.signedOut) {
        print('🚪 تم تسجيل الخروج');
        // Clear subscription cache on logout
        await SubscriptionCacheService.clearCache();
        print('🗑️ Subscription cache cleared');
      }
    });
    
    // إعداد مستمع لتحديثات Token
    fcmService.setupTokenRefreshListener();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
              child: Text('Error initializing app: ${snapshot.error}'));
        }

        return ProviderScope(
          child: EasyLocalization(
            supportedLocales: const [Locale('ar'), Locale('en')],
            path: 'assets/translations',
            fallbackLocale: const Locale('ar'),
            child: AppStateManager(
              child: const FieldawyStoreApp(),
            ),
          ),
        );
      },
    );
  }
}

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off,
                size: 100,
                color: Colors.grey,
              ),
              const SizedBox(height: 20),
              Text(
                'No Internet Connection'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Please check your internet connection and try again.'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FieldawyStoreApp extends ConsumerStatefulWidget {
  const FieldawyStoreApp({super.key});

  @override
  ConsumerState<FieldawyStoreApp> createState() => _FieldawyStoreAppState();
}

class _FieldawyStoreAppState extends ConsumerState<FieldawyStoreApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentRouteProvider.notifier).restoreLastRoute();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider); // Watch for language changes
    final themeMode = ref.watch(themeNotifierProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Fieldawy Store',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 200),
      themeAnimationCurve: Curves.easeOutCubic,
      // For Web: start with Admin Login, for Mobile: start with regular app
      initialRoute: kIsWeb ? '/admin/login' : '/',
      onGenerateRoute: (settings) {
        // Check if it's an admin route
        if (settings.name != null && settings.name!.startsWith('/admin')) {
          if (settings.name == '/admin/login') {
            return MaterialPageRoute(builder: (_) => const AdminLoginRealScreen());
          }
          if (settings.name == '/admin/dashboard') {
            return MaterialPageRoute(builder: (_) => const AdminScaffold());
          }
        }
        
        // Handle regular routes
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const AuthGate());
          case '/splash':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const DrawerWrapper());
          default:
            return MaterialPageRoute(builder: (_) => const AuthGate());
        }
      },
    );
  }
}
