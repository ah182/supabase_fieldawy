import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fieldawy_store/features/clinics/presentation/screens/select_clinic_location_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/clinic_repository.dart';
import '../../domain/clinic_model.dart';
import '../../../../core/services/custom_tile_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../authentication/data/user_repository.dart';
import '../../../home/application/user_data_provider.dart';
import 'package:collection/collection.dart';

class ClinicsMapScreen extends ConsumerStatefulWidget {
  const ClinicsMapScreen({super.key});

  @override
  ConsumerState<ClinicsMapScreen> createState() => _ClinicsMapScreenState();
}

class _ClinicsMapScreenState extends ConsumerState<ClinicsMapScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  
  List<ClinicWithDoctorInfo> _allClinics = [];
  List<ClinicWithDoctorInfo> _filteredClinics = [];
  List<ClinicWithDoctorInfo> _clinicSuggestions = [];
  List<Marker> _clinicMarkers = []; 
  List<Map<String, dynamic>> _placeSuggestions = [];
  bool _isSearchingPlaces = false;
  Position? _currentUserPosition;
  Timer? _debounce;
  
  String _ghostText = '';
  String _fullSuggestion = '';

  LatLng _initialPosition = LatLng(30.0444, 31.2357);
  bool _isLoading = true;
  bool _isUpdatingLocation = false;
  bool _isFabDisabled = true;

  @override
  void initState() {
    super.initState();
    _checkLocationAndInitialize();
    _searchController.addListener(_onSearchChanged);
    Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _isFabDisabled = false);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationAndInitialize() async {
    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('clinics_feature.location_dialog.title'.tr()),
          content: Text('clinics_feature.location_dialog.message'.tr()),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('clinics_feature.location_dialog.cancel'.tr())),
            ElevatedButton(onPressed: () async {
              await _locationService.openLocationSettings();
              Navigator.of(context).pop();
            }, child: Text('clinics_feature.location_dialog.settings'.tr())),
          ],
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    
    if (query.isNotEmpty) {
      final filtered = _allClinics.where((clinic) => clinic.clinicName.toLowerCase().startsWith(query.toLowerCase())).toList();
      setState(() {
        if (filtered.isNotEmpty) {
          _ghostText = filtered.first.clinicName;
          _fullSuggestion = filtered.first.clinicName;
        } else {
          _ghostText = '';
          _fullSuggestion = '';
        }
      });
    } else {
      setState(() {
        _ghostText = '';
        _fullSuggestion = '';
      });
    }
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final queryLower = query.toLowerCase().trim();
      if (queryLower.isEmpty) {
        setState(() {
          _filteredClinics = _allClinics;
          _clinicSuggestions = [];
          _placeSuggestions = [];
        });
        _loadClinicMarkers(_allClinics);
        return;
      }

      setState(() {
        // 1. البحث عن عيادة بالكود (مطابقة تامة أو جزئية)
        final clinicByCode = _allClinics.firstWhereOrNull(
          (c) => c.clinicCode?.toLowerCase().trim() == queryLower
        );

        // 2. فلترة العيادات العادية
        _filteredClinics = _allClinics.where((clinic) {
          return (clinic.clinicName.toLowerCase().contains(queryLower) ||
                  clinic.doctorName.toLowerCase().contains(queryLower) ||
                  (clinic.clinicCode?.toLowerCase().contains(queryLower) ?? false) ||
                  (clinic.address?.toLowerCase() ?? '').contains(queryLower));
        }).toList();
        
        if (queryLower.length >= 2) {
          // بناء قائمة المقترحات: نضع نتيجة الكود أولاً إذا وجدت
          _clinicSuggestions = [];
          if (clinicByCode != null) {
            _clinicSuggestions.add(clinicByCode);
          }
          
          // إضافة باقي العيادات المطابقة (مع تجنب التكرار)
          final remaining = _filteredClinics
              .where((c) => c.clinicId != clinicByCode?.clinicId)
              .take(clinicByCode != null ? 2 : 3);
          _clinicSuggestions.addAll(remaining);

          _searchPlaces(queryLower);
        } else {
          _clinicSuggestions = [];
          _placeSuggestions = [];
        }
        _loadClinicMarkers(_filteredClinics);
      });
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearchingPlaces = true);
    try {
      final isEnglish = RegExp(r'^[a-zA-Z]').hasMatch(query);
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=10&addressdetails=1&namedetails=1&countrycodes=eg');
      final response = await http.get(url, headers: {
        'User-Agent': 'FieldawyStoreApp/1.0',
        'Accept-Language': isEnglish ? 'en,ar' : 'ar,en',
      });
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() => _placeSuggestions = data.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
    } finally {
      setState(() => _isSearchingPlaces = false);
    }
  }

  void _moveToLocation(double lat, double lon, {String? name, ClinicWithDoctorInfo? clinic}) {
    _mapController.move(LatLng(lat, lon), 15);
    setState(() {
      _placeSuggestions = [];
      _clinicSuggestions = [];
      _ghostText = '';
      _fullSuggestion = '';
      if (clinic != null) {
        _filteredClinics = [clinic];
        _loadClinicMarkers(_filteredClinics);
      }
    });
    FocusScope.of(context).unfocus();
    if (clinic != null) _showClinicDetails(clinic);
  }

  void _loadClinicMarkers(List<ClinicWithDoctorInfo> clinics) {
    final markers = <Marker>[];
    for (final clinic in clinics) {
      final isOnline = clinic.updatedAt.isAfter(DateTime.now().subtract(const Duration(minutes: 30)));
      markers.add(Marker(
        point: LatLng(clinic.latitude, clinic.longitude),
        width: 50, height: 50,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => _showClinicDetails(clinic),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 50),
              Positioned(
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: (clinic.doctorPhotoUrl != null && clinic.doctorPhotoUrl!.isNotEmpty) ? CachedNetworkImageProvider(clinic.doctorPhotoUrl!) : null,
                    child: (clinic.doctorPhotoUrl == null || clinic.doctorPhotoUrl!.isEmpty) ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  bottom: 12, right: 12,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
            ],
          ),
        ),
      ));
    }
    if (mounted) setState(() => _clinicMarkers = markers);
  }
  
  void _showClinicDetails(ClinicWithDoctorInfo clinic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _ClinicDetailsSheet(clinic: clinic),
    );
  }

  Future<void> _updateMyLocation() async {
    if (_isUpdatingLocation) return;
    setState(() => _isUpdatingLocation = true);
    try {
      final position = await _locationService.getHighAccuracyPosition();
      if (position == null) return;
      setState(() => _currentUserPosition = position);
      final currentUser = ref.read(userDataProvider).asData?.value;
      if (currentUser != null) {
        await ref.read(userRepositoryProvider).updateUserLocation(userId: currentUser.id, latitude: position.latitude, longitude: position.longitude);
        ref.invalidate(userDataProvider);
        _mapController.move(LatLng(position.latitude, position.longitude), 14);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  void _handleMapLongPress(LatLng point) {
    final user = ref.read(userDataProvider).asData?.value;
    if (user?.role != 'doctor') return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.add_location_alt_rounded, color: Theme.of(context).primaryColor), const SizedBox(width: 10), Text('clinics_feature.add_request_title'.tr())]),
        content: const Text('هل تريد تسجيل عيادتك في هذا الموقع؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => SelectClinicLocationScreen(initialPosition: point, userId: user!.id, userName: user.displayName ?? '')));
            },
            child: Text('clinics_feature.select_location.accept'.tr()),
          ),
        ],
      ),
    );
  }

  void _showNearbyClinicsDialog(ColorScheme colorScheme, TextTheme textTheme) {
    final sortedClinics = List<ClinicWithDoctorInfo>.from(_allClinics);
    if (_currentUserPosition != null) {
      sortedClinics.sort((a, b) {
        final distA = Geolocator.distanceBetween(_currentUserPosition!.latitude, _currentUserPosition!.longitude, a.latitude, a.longitude);
        final distB = Geolocator.distanceBetween(_currentUserPosition!.latitude, _currentUserPosition!.longitude, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [Icon(Icons.near_me_rounded, color: colorScheme.primary), const SizedBox(width: 12), const Text('العيادات الأقرب إليك')]),
        content: SizedBox(
          width: double.maxFinite, height: 400,
          child: ListView.builder(
            itemCount: sortedClinics.length,
            itemBuilder: (context, index) {
              final clinic = sortedClinics[index];
              double? distance;
              if (_currentUserPosition != null) {
                distance = Geolocator.distanceBetween(_currentUserPosition!.latitude, _currentUserPosition!.longitude, clinic.latitude, clinic.longitude) / 1000;
              }
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (clinic.doctorPhotoUrl != null && clinic.doctorPhotoUrl!.isNotEmpty) ? CachedNetworkImageProvider(clinic.doctorPhotoUrl!) : null,
                  child: (clinic.doctorPhotoUrl == null || clinic.doctorPhotoUrl!.isEmpty) ? const Icon(Icons.person) : null,
                ),
                title: Text(clinic.clinicName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(clinic.doctorName, style: const TextStyle(fontSize: 12)),
                trailing: distance != null ? Text('${distance.toStringAsFixed(1)} كم', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)) : null,
                onTap: () { Navigator.pop(context); _moveToLocation(clinic.latitude, clinic.longitude, clinic: clinic); },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  List<Widget> _getTileLayers() {
    return [
      TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', userAgentPackageName: 'com.fieldawy.store', maxZoom: 20, tileProvider: RetryTileProvider()),
      TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}', userAgentPackageName: 'com.fieldawy.store', maxZoom: 20, tileProvider: RetryTileProvider()),
      TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}', userAgentPackageName: 'com.fieldawy.store', maxZoom: 20, tileProvider: RetryTileProvider()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final clinicsAsync = ref.watch(allClinicsWithDoctorInfoProvider);
    final userData = ref.watch(userDataProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_currentUserPosition == null && userData.hasValue) {
      final user = userData.value;
      if (user?.lastLatitude != null && user?.lastLongitude != null) {
        _currentUserPosition = Position(latitude: user!.lastLatitude!, longitude: user.lastLongitude!, timestamp: DateTime.now(), accuracy: 50, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('clinics_feature.title'.tr())),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(heroTag: 'nearby_fab', onPressed: _allClinics.isEmpty ? null : () => _showNearbyClinicsDialog(colorScheme, textTheme), backgroundColor: theme.primaryColor, child: const Icon(Icons.list_alt_rounded, color: Colors.white)),
          const SizedBox(height: 12),
          FloatingActionButton(heroTag: 'loc_fab', onPressed: _isFabDisabled || _isUpdatingLocation ? null : _updateMyLocation, backgroundColor: _isFabDisabled || _isUpdatingLocation ? Colors.grey : theme.primaryColor, child: _isUpdatingLocation ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.my_location, color: Colors.white)),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { FocusScope.of(context).unfocus(); if (_searchController.text.isEmpty) setState(() { _ghostText = ''; _fullSuggestion = ''; }); },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(children: [
                Stack(children: [
                  TextField(controller: _searchController, decoration: InputDecoration(hintText: 'clinics_feature.search_hint'.tr(), prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: theme.scaffoldBackgroundColor, contentPadding: EdgeInsets.zero, suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() { _ghostText = ''; _fullSuggestion = ''; _placeSuggestions = []; }); }) : null)),
                  if (_ghostText.isNotEmpty) Positioned(top: 11, right: 55, child: GestureDetector(onTap: () { if (_fullSuggestion.isNotEmpty) { _searchController.text = _fullSuggestion; setState(() { _ghostText = ''; _fullSuggestion = ''; }); } }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.brightness == Brightness.dark ? colorScheme.secondary.withOpacity(0.1) : colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(_ghostText, style: TextStyle(color: theme.brightness == Brightness.dark ? colorScheme.primary : colorScheme.secondary, fontWeight: FontWeight.bold))))),
                ]),
                if (_clinicSuggestions.isNotEmpty || _placeSuggestions.isNotEmpty || _isSearchingPlaces)
                  Card(
                    elevation: 8, margin: const EdgeInsets.only(top: 4), clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (_isSearchingPlaces) const LinearProgressIndicator(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
                          ..._clinicSuggestions.map((clinic) {
                            final isCodeMatch = _searchController.text.toLowerCase().trim() == clinic.clinicCode?.toLowerCase().trim();
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isCodeMatch ? Colors.amber.shade50 : Colors.red.shade50,
                                radius: 16,
                                backgroundImage: (clinic.doctorPhotoUrl != null && clinic.doctorPhotoUrl!.isNotEmpty)
                                    ? CachedNetworkImageProvider(clinic.doctorPhotoUrl!)
                                    : null,
                                child: (clinic.doctorPhotoUrl == null || clinic.doctorPhotoUrl!.isEmpty)
                                    ? Icon(
                                        isCodeMatch ? Icons.vpn_key_rounded : Icons.local_hospital, 
                                        color: isCodeMatch ? Colors.amber.shade800 : Colors.red, 
                                        size: 18
                                      )
                                    : null,
                              ),
                              title: Text(clinic.clinicName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(isCodeMatch ? 'مطابق للكود : ${clinic.clinicCode}' : clinic.doctorName, style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.arrow_outward_rounded, size: 14),
                              onTap: () => _moveToLocation(clinic.latitude, clinic.longitude, clinic: clinic),
                            );
                          }),
                          if (_clinicSuggestions.isNotEmpty && _placeSuggestions.isNotEmpty) const Divider(height: 1),
                          ..._placeSuggestions.take(5 - _clinicSuggestions.length).map((suggestion) {
                            final name = suggestion['display_name'];
                            return ListTile(leading: const Icon(Icons.location_on_outlined, color: Colors.blue, size: 20), title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)), onTap: () => _moveToLocation(double.parse(suggestion['lat']), double.parse(suggestion['lon']), name: name));
                          }),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
            Expanded(
              child: clinicsAsync.when(
                data: (clinics) {
                  if (_allClinics.length != clinics.length || _allClinics.firstOrNull?.clinicCode == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _allClinics = clinics;
                          if (_searchController.text.isEmpty) {
                            _filteredClinics = clinics;
                            _loadClinicMarkers(clinics);
                          }
                        });
                      }
                    });
                  }
                  if (_allClinics.isEmpty && !_isLoading) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.location_off, size: 64, color: Colors.grey), const SizedBox(height: 16), Text('clinics_feature.no_clinics'.tr(), style: const TextStyle(fontSize: 18, color: Colors.grey))]));
                  return FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: _initialPosition, initialZoom: 12, minZoom: 3, maxZoom: 20, onTap: (_, __) => FocusScope.of(context).unfocus(), onLongPress: (tapPos, point) => _handleMapLongPress(point)),
                    children: [
                      ..._getTileLayers(),
                      if (_currentUserPosition != null) CircleLayer(circles: [CircleMarker(point: LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude), radius: _currentUserPosition!.accuracy, useRadiusInMeter: true, color: Colors.blue.withOpacity(0.1), borderColor: Colors.blue.withOpacity(0.3), borderStrokeWidth: 2)]),
                      MarkerLayer(markers: [..._clinicMarkers, if (_currentUserPosition != null) Marker(point: LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude), width: 50, height: 50, child: Container(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.blue.withAlpha(128), blurRadius: 8, spreadRadius: 2)]), child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 28)))]),
                      RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')])
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 64, color: Colors.red), const SizedBox(height: 16), Text('clinics_feature.error_load'.tr()), const SizedBox(height: 16), ElevatedButton(onPressed: () => ref.refresh(allClinicsWithDoctorInfoProvider), child: Text('clinics_feature.retry'.tr()))])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicDetailsSheet extends ConsumerWidget {
  final ClinicWithDoctorInfo clinic;
  const _ClinicDetailsSheet({required this.clinic});

  Widget _buildInfoRow(BuildContext context, IconData icon, String title, String? value, {bool showIfEmpty = false}) {
    if ((value == null || value.isEmpty) && !showIfEmpty) return const SizedBox.shrink();
    final displayValue = (value == null || value.isEmpty) ? 'clinics_feature.details.unavailable'.tr() : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).primaryColor, size: 22), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 2), Text(displayValue, style: TextStyle(fontSize: 16, color: (value == null || value.isEmpty) ? Colors.grey : null, fontStyle: (value == null || value.isEmpty) ? FontStyle.italic : null))]))]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? rawAddress = clinic.address;
    String? cleanedAddress = rawAddress;
    if (rawAddress != null) {
      final commaIndex = rawAddress.indexOf(',');
      if (commaIndex != -1) cleanedAddress = rawAddress.substring(commaIndex + 1).trim();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(clinic.clinicName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            if (clinic.clinicCode != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.black54),
                    const SizedBox(width: 6),
                    SelectableText(
                      clinic.clinicCode!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8), const Divider(),
        _buildInfoRow(context, Icons.person_outline, 'clinics_feature.details.doctor'.tr(), clinic.doctorName),
        _buildInfoRow(context, Icons.location_on_outlined, 'clinics_feature.details.address'.tr(), cleanedAddress),
        _buildInfoRow(context, Icons.phone_outlined, 'clinics_feature.details.phone'.tr(), clinic.clinicPhoneNumber ?? clinic.doctorWhatsappNumber, showIfEmpty: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(children: [Icon(FontAwesomeIcons.whatsapp, color: Theme.of(context).primaryColor, size: 22), const SizedBox(width: 16), const Expanded(child: Text('WhatsApp', style: TextStyle(fontSize: 16))), IconButton(icon: const Icon(Icons.send, color: Colors.green), onPressed: () async { final phone = clinic.doctorWhatsappNumber?.replaceAll(RegExp(r'[^0-9]'), ''); if (phone != null) await launchUrl(Uri.parse('https://wa.me/${phone.startsWith('20') ? phone : '20$phone'}'), mode: LaunchMode.externalApplication); })]),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions), 
                label: Text('clinics_feature.details.directions'.tr()), 
                onPressed: () async => await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${clinic.latitude},${clinic.longitude}'), mode: LaunchMode.externalApplication), 
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.share_location_rounded, color: Colors.blue),
                onPressed: () {
                  final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${clinic.latitude},${clinic.longitude}';
                  final String message = 'موقع عيادة: ${clinic.clinicName}\nالطبيب: ${clinic.doctorName}\nالرابط: $googleMapsUrl';
                  Share.share(message);
                },
                tooltip: 'مشاركة الموقع',
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}