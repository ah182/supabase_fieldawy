import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/clinics/data/clinic_repository.dart';
import 'package:fieldawy_store/core/services/location_service.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class SelectClinicLocationScreen extends ConsumerStatefulWidget {
  final LatLng initialPosition;
  final String userId;
  final String userName;

  const SelectClinicLocationScreen({
    super.key,
    required this.initialPosition,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<SelectClinicLocationScreen> createState() =>
      _SelectClinicLocationScreenState();
}

class _SelectClinicLocationScreenState
    extends ConsumerState<SelectClinicLocationScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  late LatLng _currentCenter;
  bool _isLoading = false;
  bool _isCentering = false;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialPosition;
  }

  Future<void> _onConfirmLocation() async {
    setState(() => _isLoading = true);
    
    // Fetch existing clinic data to check for previous name
    String? existingClinicName;
    try {
      final existingClinic = await ref.read(clinicRepositoryProvider).getClinicByUserId(widget.userId);
      if (existingClinic != null) {
        existingClinicName = existingClinic.clinicName;
      }
    } catch (e) {
      // Ignore error, just proceed with default name
    }
    
    setState(() => _isLoading = false);
    
    if (!mounted) return;

    // Show modern dialog for clinic name input
    final String? customName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String inputValue = '';
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10.0, offset: Offset(0.0, 10.0)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تحديد اسم العيادة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'يرجى إدخال اسم العيادة الذي سيظهر للمرضى والمستخدمين على الخريطة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  autofocus: true,
                  controller: TextEditingController(text: existingClinicName), // Pre-fill if exists
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: widget.userName,
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    labelText: 'اسم العيادة',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.local_hospital, color: Colors.green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (val) => inputValue = val,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    existingClinicName != null 
                        ? 'ملاحظة: في حال التخطي، سيتم الاحتفاظ باسم العيادة الحالي: "$existingClinicName"'
                        : 'ملاحظة: في حال التخطي، سيتم اعتماد اسم الطبيب كاسم للعيادة بشكل تلقائي.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null), // Skip
                      child: const Text('تخطي الآن', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(inputValue.trim().isEmpty ? (existingClinicName ?? inputValue.trim()) : inputValue.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('تأكيد وحفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // Logic to determine final name:
    // 1. If user entered a custom name (and it's not empty), use it.
    // 2. If user skipped (customName is null) AND we have an existing name, keep the existing name.
    // 3. Otherwise (skipped with no existing name, or empty input), default to userName.
    
    String finalClinicName;
    if (customName != null && customName.isNotEmpty) {
      finalClinicName = customName;
    } else if (existingClinicName != null) {
      finalClinicName = existingClinicName;
    } else {
      finalClinicName = widget.userName;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final address = await _locationService.getAddressFromCoordinates(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );

      final success = await ref.read(clinicRepositoryProvider).upsertClinic(
            userId: widget.userId,
            clinicName: finalClinicName,
            latitude: _currentCenter.latitude,
            longitude: _currentCenter.longitude,
            address: address,
          );

      if (success && mounted) {
        final String clinicCode = 'CL-${widget.userId.substring(0, 4).toUpperCase()}';
        
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.bottomSlide,
          headerAnimationLoop: false,
          title: 'تم تسجيل الموقع بنجاح! 🎉',
          desc: 'تم توليد كود خاص لعيادتك: ($clinicCode)\n\nيمكنك الآن إعطاء هذا الكود لأي شخص للبحث عنك في الخريطة والوصول إليك فوراً. ستجد الكود دائماً في ملفك الشخصي.',
          btnOkText: 'رائع',
          btnOkColor: Theme.of(context).primaryColor,
          btnOkOnPress: () {
            Navigator.of(context).pop();
          },
        ).show();
      } else {
        throw Exception('Failed to update location');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('clinics_feature.generic_error'.tr())),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

    Future<void> _centerOnUserLocation() async {
      setState(() => _isCentering = true);
      final messenger = ScaffoldMessenger.of(context);

      try {
        // Prominent Disclosure
        final permission = await _locationService.checkPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          if (mounted) {
            final bool? accepted = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Text('clinics_feature.select_location.location_disclosure_title'.tr()),
                content: Text(
                  'clinics_feature.select_location.location_disclosure_content'.tr(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('cancel'.tr()),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('clinics_feature.select_location.accept'.tr()),
                  ),
                ],
              ),
            );

            if (accepted != true) {
              setState(() => _isCentering = false);
              return;
            }
          }
        }

        final position = await _locationService.getHighAccuracyPosition();

        if (position != null) {
          _currentCenter = LatLng(position.latitude, position.longitude);
          _mapController.move(_currentCenter, 18.0);
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text('clinics_feature.select_location.error_center'.tr())),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isCentering = false);
        }
      }
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'clinics_feature.select_location.title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCentering ? null : _centerOnUserLocation,
        child: _isCentering 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.my_location),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPosition,
              initialZoom: 18.0, // Increased zoom level
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _currentCenter = position.center;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.fieldawy.app',
              ),
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.fieldawy.app',
              ),
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.fieldawy.app',
              ),
            ],
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 50), // Adjust to center the pin's tip
              child: Icon(
                Icons.location_pin,
                size: 50,
                color: Colors.red,
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_isLoading ? 'clinics_feature.select_location.saving'.tr() : 'clinics_feature.select_location.save_btn'.tr()),
              onPressed: _isLoading ? null : _onConfirmLocation,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
