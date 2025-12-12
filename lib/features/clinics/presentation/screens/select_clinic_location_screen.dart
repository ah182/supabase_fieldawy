import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fieldawy_store/features/clinics/data/clinic_repository.dart';
import 'package:fieldawy_store/core/services/location_service.dart';

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
    final messenger = ScaffoldMessenger.of(context);

    try {
      final address = await _locationService.getAddressFromCoordinates(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );

      final success = await ref.read(clinicRepositoryProvider).upsertClinic(
            userId: widget.userId,
            clinicName: widget.userName,
            latitude: _currentCenter.latitude,
            longitude: _currentCenter.longitude,
            address: address,
          );

      if (success && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('clinics_feature.select_location.success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to update location');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('clinics_feature.messages.generic_error'.tr(namedArgs: {'error': e.toString()}))),
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
        title: Text('clinics_feature.select_location.title'.tr()),
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
                userAgentPackageName: 'com.fieldawy.store',
              ),
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.fieldawy.store',
              ),
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.fieldawy.store',
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
