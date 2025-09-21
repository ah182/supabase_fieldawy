import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'home_screen.dart';
import 'menu_screen.dart';

class DrawerWrapper extends StatefulWidget {
  const DrawerWrapper({super.key});

  @override
  State<DrawerWrapper> createState() => _DrawerWrapperState();
}

class _DrawerWrapperState extends State<DrawerWrapper> {
  final _drawerController = ZoomDrawerController();

  @override
  Widget build(BuildContext context) {
    return ZoomDrawer(
      controller: _drawerController,
      menuScreen: const MenuScreen(),
      mainScreen: const HomeScreen(),
      borderRadius: 24.0,
      showShadow: true,
      angle: -10.0, // زاوية ميلان الشاشة الرئيسية
      drawerShadowsBackgroundColor: Colors.grey.shade300,
      slideWidth: MediaQuery.of(context).size.width * 0.75, // عرض القائمة
      mainScreenTapClose: true, // إغلاق القائمة عند الضغط على الشاشة الرئيسية
      menuBackgroundColor: Theme.of(context).colorScheme.primary,
      isRtl:
          context.locale.languageCode == 'ar', // دعم الاتجاه من اليمين لليسار
    );
  }
}
