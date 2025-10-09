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

// ✅ handler للرسائل في الخلفية
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
  
  // ✅ فلترة الإشعارات حسب تفضيلات المستخدم
  if (!await _shouldShowNotification(screen)) {
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
    payload: data['screen'] ?? 'home',
  );
}

// ✅ دالة للتحقق من تفضيلات الإشعارات
Future<bool> _shouldShowNotification(String screen) async {
  try {
    // تحديد نوع الإشعار من screen name
    String notificationType;
    
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
        return true;
    }
    
    // التحقق من تفضيلات المستخدم
    final isEnabled = await NotificationPreferencesService.isNotificationEnabled(notificationType);
    return isEnabled;
  } catch (e) {
    print('⚠️ خطأ في فحص تفضيلات الإشعارات: $e');
    // في حالة الخطأ، نعرض الإشعار (افتراضي)
    return true;
  }
}

// دالة للتعامل مع النقر على الإشعارات
void _handleNotificationTap(String screen) {
  print('🔔 معالجة النقر على الإشعار: $screen');
  
  // تأخير بسيط للتأكد من أن التطبيق جاهز
  Future.delayed(const Duration(milliseconds: 500), () {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('❌ NavigatorContext غير متاح');
      return;
    }

    // تحديد tab index بناءً على screen
    // سيتم استخدامه عند تحديث DrawerWrapper لقبول initialTabIndex
    final tabIndex = _getTabIndexFromScreen(screen);
    
    print('🔔 الانتقال إلى Tab: $tabIndex ($screen)');

    // الانتقال إلى HomeScreen
    // TODO: عند إضافة initialTabIndex لـ DrawerWrapper، استخدم:
    // Navigator.of(context).pushAndRemoveUntil(
    //   MaterialPageRoute(
    //     builder: (context) => DrawerWrapper(initialTabIndex: tabIndex),
    //   ),
    //   (route) => false,
    // );
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const DrawerWrapper(),
      ),
      (route) => false,
    );
  });
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
  await FirebaseMessaging.instance.subscribeToTopic('all_users');
  print('✅ تم الاشتراك في topic: all_users');
  
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
      _handleNotificationTap(screen);
    }
  });

  // ✅ معالجة النقر على الإشعار عندما يكون التطبيق في الخلفية
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    print('🔔 تم فتح الإشعار من الخلفية: ${message.data}');
    final screen = message.data['screen'] ?? 'home';
    _handleNotificationTap(screen);
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
        _handleNotificationTap(response.payload!);
      }
    },
  );

  // ✅ listen للإشعارات أثناء فتح التطبيق (data-only messages)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final data = message.data;

    // استخراج البيانات من data payload
    final String title = data['title'] ?? 'إشعار جديد';
    final String body = data['body'] ?? '';
    final String type = data['type'] ?? 'general';
    final String screen = data['screen'] ?? 'home';

    // ✅ فلترة الإشعارات حسب تفضيلات المستخدم
    if (!await _shouldShowNotification(screen)) {
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
      payload: screen,
    );
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
  await Hive.openBox<String>('favorites');
  await Hive.openBox('api_cache');

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
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      
      if (event == AuthChangeEvent.signedIn) {
        print('🔐 تم تسجيل الدخول - جاري حفظ FCM Token...');
        fcmService.getAndSaveToken();
      } else if (event == AuthChangeEvent.signedOut) {
        print('🚪 تم تسجيل الخروج');
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
