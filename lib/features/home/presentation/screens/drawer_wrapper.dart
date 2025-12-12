// ignore: unused_import
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'home_screen.dart';
import 'menu_screen.dart';
import 'package:fieldawy_store/main.dart' as main_app;

class DrawerWrapper extends StatefulWidget {
  final int? initialTabIndex;
  final String? distributorId;
  
  const DrawerWrapper({
    super.key,
    this.initialTabIndex,
    this.distributorId,
  });

  @override
  State<DrawerWrapper> createState() => _DrawerWrapperState();
}

class _DrawerWrapperState extends State<DrawerWrapper> {
  final _drawerController = ZoomDrawerController();
  int? _effectiveTabIndex;
  String? _effectiveDistributorId;
  
  @override
  void initState() {
    super.initState();
    
    // Check for pending notification
    final pendingScreen = main_app.getPendingNotificationScreen();
    final pendingDistributorId = main_app.getPendingNotificationDistributorId();
    
    if (pendingScreen != null) {
      print('✅ DrawerWrapper: تطبيق الإشعار المؤجل - $pendingScreen, distributor: $pendingDistributorId');
      main_app.clearPendingNotification();
      
      if (pendingDistributorId != null && pendingDistributorId.isNotEmpty) {
        _effectiveDistributorId = pendingDistributorId;
        _effectiveTabIndex = null;
      } else {
        _effectiveTabIndex = _getTabIndex(pendingScreen);
        _effectiveDistributorId = null;
      }
    } else {
      // Use widget parameters
      _effectiveTabIndex = widget.initialTabIndex;
      _effectiveDistributorId = widget.distributorId;
    }
  }
  
  int _getTabIndex(String screen) {
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

  @override
  Widget build(BuildContext context) {
    return ZoomDrawer(
      controller: _drawerController,
      menuScreen: const MenuScreen(),
      mainScreen: HomeScreen(
        initialTabIndex: _effectiveTabIndex,
        distributorId: _effectiveDistributorId,
      ),
      borderRadius: 24.0,
      showShadow: true,
      angle: -10.0, // زاوية ميلان الشاشة الرئيسية
      drawerShadowsBackgroundColor: Colors.grey.shade300,
      slideWidth: MediaQuery.of(context).size.width * 0.75, // عرض القائمة
      mainScreenTapClose: true, // إغلاق القائمة عند الضغط على الشاشة الرئيسية
      menuBackgroundColor: Theme.of(context).colorScheme.primary,
      // دعم الاتجاه من اليمين لليسار
    );
  }
}
