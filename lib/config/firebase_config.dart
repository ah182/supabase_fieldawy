/// Firebase Configuration
///
/// This file controls Firebase services availability.
/// Set [isFirebaseEnabled] to false when the Firebase project is suspended.
///
/// ⚠️ IMPORTANT: Remember to set this back to true when Firebase is restored!

class FirebaseConfig {
  /// Set this to false to disable all Firebase services
  /// Use this when:
  /// - Firebase project is suspended
  /// - Testing without Firebase
  /// - Running in environments where Firebase is not available
  ///
  /// When disabled:
  /// - Push notifications will not work
  /// - FCM tokens will not be generated
  /// - Topic subscriptions will be skipped
  ///
  /// Other features (Supabase, UI, etc.) will continue to work normally.
  static const bool isFirebaseEnabled = false;

  /// Message to show when Firebase is disabled
  static const String firebaseDisabledMessage =
      '⚠️ خدمات Firebase معطلة مؤقتاً - الإشعارات لن تعمل';

  /// Check if Firebase services should be used
  static bool get shouldUseFirebase => isFirebaseEnabled;
}
