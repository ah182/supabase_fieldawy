import 'package:fieldawy_store/features/clinics/presentation/screens/select_clinic_location_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/location_service.dart';
import '../../data/clinic_repository.dart';
import '../../../authentication/data/user_repository.dart';

class LocationPermissionDialog extends ConsumerStatefulWidget {
  final String userId;
  final String userName;

  const LocationPermissionDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<LocationPermissionDialog> createState() =>
      _LocationPermissionDialogState();
}

class _LocationPermissionDialogState
    extends ConsumerState<LocationPermissionDialog> {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _requestLocationAndSave() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current position with high accuracy
      final position = await _locationService.getHighAccuracyPosition();

      if (position == null) {
        setState(() {
          _errorMessage =
              'لم نتمكن من الحصول على موقعك. تأكد من تفعيل خدمات الموقع.';
          _isLoading = false;
        });
        return;
      }

      // Get address from coordinates
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Get user's phone number
      final user = await ref.read(userRepositoryProvider).getUser(widget.userId);
      final phoneNumber = user?.whatsappNumber;

      // Save clinic to database
      final success = await ref.read(clinicRepositoryProvider).upsertClinic(
            userId: widget.userId,
            clinicName: widget.userName,
            latitude: position.latitude,
            longitude: position.longitude,
            address: address,
            phoneNumber: phoneNumber,
          );

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      if (success && mounted) {
        // Show success message for the initial save
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ الموقع المبدئي, يمكنك الآن تعديله يدويًا'),
            backgroundColor: Colors.green,
          ),
        );
        // Close the dialog
        navigator.pop(true);

        // THEN, navigate to the manual selection screen
        navigator.push(
          MaterialPageRoute(
            builder: (context) => SelectClinicLocationScreen(
              initialPosition: LatLng(position.latitude, position.longitude),
              userId: widget.userId,
              userName: widget.userName,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء حفظ الموقع. حاول مرة أخرى.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue, size: 28),
          SizedBox(width: 10),
          Text('تحديد موقع العيادة'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'هل تسمح للتطبيق بتحديد موقع العيادة على الخريطة؟',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لماذا نحتاج موقعك؟',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• سيظهر موقع عيادتك على الخريطة للمستخدمين الآخرين\n'
                  '• يمكنك تحديث الموقع في أي وقت من الإعدادات\n'
                  '• يساعد هذا المستخدمين في العثور على عيادتك',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_isLoading) ...[
            const SizedBox(height: 20),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text(
                    'جاري تحديد الموقع...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('لاحقاً'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _requestLocationAndSave,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('السماح وحفظ الموقع'),
        ),
      ],
    );
  }
}

// Helper function to show the dialog
Future<bool?> showLocationPermissionDialog(
  BuildContext context,
  String userId,
  String userName,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => LocationPermissionDialog(
      userId: userId,
      userName: userName,
    ),
  );
}
