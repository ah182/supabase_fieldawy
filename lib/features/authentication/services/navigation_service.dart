import 'package:flutter/material.dart';
import 'package:fieldawy_store/features/home/presentation/screens/home_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/role_selection_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/rejection_screen.dart';
import 'package:fieldawy_store/features/authentication/presentation/screens/pending_review_screen.dart';

class NavigationService {
  static Widget getScreenForUserStatus(String? accountStatus) {
    switch (accountStatus) {
      case 'approved':
      case 'pending_review':
        return const HomeScreen();
      case 'pending_re_review':
        return const PendingReviewScreen();
      case 'rejected':
        return const RejectionScreen();
      default:
        return const RoleSelectionScreen();
    }
  }
}