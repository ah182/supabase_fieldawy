import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:fieldawy_store/features/authentication/presentation/screens/auth_gate.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/login_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/splash_screen.dart';
import 'package:fieldawy_store/features/home/presentation/screens/drawer_wrapper.dart';

import 'features/admin_dashboard/presentation/screens/admin_login_screen.dart';
import 'features/admin_dashboard/presentation/widgets/admin_scaffold.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  final String body = data['body'] ?? '';
  final String type = data['type'] ?? 'general';
  final String screen = data['screen'] ?? 'home';
  final String? distributorId = data['distributor_id'];
  
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  
  print('📋 Background notification check:');
  print('   Current User ID: ${currentUserId ?? "Not logged in"}');
  print('   Distributor ID: ${distributorId ?? "None"}');
  print('   Title: $title');
  
  // ⏭️ تخطي الإشعار إذا كان المرسل هو المستقبل (optional - يمكن تعطيله)
  // if (distributorId != null && currentUserId != null && distributorId == currentUserId) {
  //   print('⏭️ تم تخطي الإشعار: المرسل هو المستقبل');
  //   return;
  // }
  
  // ✅ فلترة الإشعارات حسب تفضيلات المستخدم
  bool shouldShow = true;
  try {
    shouldShow = await _shouldShowNotification(screen, distributorId: distributorId);
    print('   Should show: $shouldShow');
  } catch (e) {
    print('⚠️ خطأ في فحص الإشعارات في الخلفية: $e');
    // في حالة الخطأ، نعرض الإشعار
    shouldShow = true;
  }
  
  if (!shouldShow) {
    print('⏭️ تم تخطي الإشعار: $title (تم تعطيله في الإعدادات)');
    return;
  }

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

  print('📩 إشعار في الخلفية:');
  print('   العنوان: $title');
  print('   المحتوى: $body');
  print('   النوع: $type');
  print('   الموزع: ${distributorId ?? "عام"}');

  // Build payload: "screen|distributor_id" or just "screen"
  String payload = screen;
  if (distributorId != null && distributorId.isNotEmpty) {
    payload = '$screen|$distributorId';
  }

  // عرض الإشعار المحلي مع شعار التطبيق
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

// ✅ دالة للتحقق من تفضيلات الإشعارات
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
void _handleNotificationTap(String screen, {String? distributorId}) {
  print('🔔 معالجة النقر على الإشعار: $screen, distributor: $distributorId');
  
  final context = navigatorKey.currentContext;
  
  if (context != null) {
    // Context متاح، نفذ التنقل مباشرة
    print('✅ NavigatorContext متاح - بدء التنقل');
    _performNavigation(context, screen, distributorId);
  } else {
    // Context مش متاح، احفظ الـ notification للاستخدام لاحقاً
    print('⏳ NavigatorContext غير متاح - حفظ الإشعار للمعالجة لاحقاً');
    _pendingNotificationScreen = screen;
    _pendingNotificationDistributorId = distributorId;
  }
}

// دالة منفصلة لتنفيذ التنقل
void _performNavigation(BuildContext context, String screen, String? distributorId) {
  // إذا كان هناك distributorId، افتح صفحة الموزع
  if (distributorId != null && distributorId.isNotEmpty) {
    print('🔔 الانتقال إلى صفحة الموزع: $distributorId');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => DrawerWrapper(distributorId: distributorId),
      ),
      (route) => false,
    );
    return;
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
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase initialization
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      _handleNotificationTap(screen, distributorId: distributorId);
    }
  });

  // ✅ معالجة النقر على الإشعار عندما يكون التطبيق في الخلفية
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    print('🔔 تم فتح الإشعار من الخلفية: ${message.data}');
    final screen = message.data['screen'] ?? 'home';
    final distributorId = message.data['distributor_id'];
    _handleNotificationTap(screen, distributorId: distributorId);
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
        
        // Parse payload - format: "screen|distributor_id" or just "screen"
        final parts = response.payload!.split('|');
        final screen = parts[0];
        final distributorId = parts.length > 1 ? parts[1] : null;
        
        _handleNotificationTap(screen, distributorId: distributorId);
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
      final String body = data['body'] ?? '';
      final String type = data['type'] ?? 'general';
      final String screen = data['screen'] ?? 'home';
      final String? distributorId = data['distributor_id'];

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    
    print('📱 Foreground notification received:');
    print('   Current User ID: ${currentUserId ?? "Not logged in"}');
    print('   Distributor ID: ${distributorId ?? "None"}');
    print('   Title: $title');
    
    // ⏭️ تخطي الإشعار إذا كان المرسل هو المستقبل (optional - يمكن تعطيله)
    // if (distributorId != null && currentUserId != null && distributorId == currentUserId) {
    //   print('⏭️ تم تخطي الإشعار: المرسل هو المستقبل');
    //   return;
    // }

    // ✅ فلترة الإشعارات حسب تفضيلات المستخدم
    final shouldShow = await _shouldShowNotification(screen, distributorId: distributorId);
    print('   Should show: $shouldShow');
    
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

    // Build payload: "screen|distributor_id" or just "screen"
    String payload = screen;
    if (distributorId != null && distributorId.isNotEmpty) {
      payload = '$screen|$distributorId';
    }
    
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

  pdfrxFlutterInitialize();
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

  runApp(const ConnectivityHandler());
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
    final locale = ref.watch(languageProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      key: ValueKey(locale),
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
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const DrawerWrapper(),
        '/admin/login': (context) => const AdminLoginScreen(),
        '/admin/dashboard': (context) => const AdminScaffold(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (_) => const AuthGate());
      },
    );
  }
}
