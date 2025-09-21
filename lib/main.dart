import 'dart:async';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/localization/language_provider.dart';
import 'features/authentication/data/storage_service.dart';
import 'services/app_state_manager.dart';
import 'core/supabase/supabase_init.dart';

// الشاشات
import 'features/authentication/presentation/screens/auth_gate.dart';
import 'features/authentication/presentation/screens/splash_screen.dart';
import 'features/authentication/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/drawer_wrapper.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: ".env");

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
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
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
          if (_isOffline)
            const NoInternetScreen(),
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
    // This can be run in parallel
    unawaited(StorageService().cleanupTempImages());
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
          return Center(child: Text('Error initializing app: ${snapshot.error}'));
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
    // استدعاء مرة واحدة فقط بعد أول frame
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
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (_) => const AuthGate());
      },
    );
  }
}
