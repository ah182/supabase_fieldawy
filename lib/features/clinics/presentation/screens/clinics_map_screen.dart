import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../data/clinic_repository.dart';
import '../../domain/clinic_model.dart';
import '../../../../core/services/custom_tile_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../authentication/data/user_repository.dart';

import '../../../home/application/user_data_provider.dart';

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
  List<ClinicWithDoctorInfo> _clinicSuggestions = []; // جديد: اقتراحات العيادات
  List<Marker> _clinicMarkers = []; 
  List<Map<String, dynamic>> _placeSuggestions = [];
  bool _isSearchingPlaces = false;
  Position? _currentUserPosition;
  Timer? _debounce;
  
  // Ghost text variables
  String _ghostText = '';
  String _fullSuggestion = '';

  LatLng _initialPosition = LatLng(30.0444, 31.2357);
  bool _isLoading = true;
  bool _isUpdatingLocation = false;
  bool _isFabDisabled = true;

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _placeSuggestions = [];
        _isSearchingPlaces = false;
      });
      return;
    }

    setState(() => _isSearchingPlaces = true);

    try {
      // كشف لغة الكتابة (إذا كانت تبدأ بحروف إنجليزية)
      final isEnglish = RegExp(r'^[a-zA-Z]').hasMatch(query);
      
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=10&addressdetails=1&namedetails=1&countrycodes=eg');
      
      final response = await http.get(url, headers: {
        'User-Agent': 'FieldawyStoreApp/1.0',
        'Accept-Language': isEnglish ? 'en,ar' : 'ar,en', // تغيير الأولوية حسب لغة الكتابة
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _placeSuggestions = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
    } finally {
      setState(() => _isSearchingPlaces = false);
    }
  }

  void _moveToLocation(double lat, double lon, {String? name, ClinicWithDoctorInfo? clinic}) {
    _mapController.move(LatLng(lat, lon), 15); // زووم أقرب للعيادات
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
    
    // إذا كانت عيادة، اظهر التفاصيل فوراً
    if (clinic != null) {
      _showClinicDetails(clinic);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkLocationAndInitialize();
    _searchController.addListener(_onSearchChanged);
    Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isFabDisabled = false;
        });
      }
    });
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
    await _initializeMap();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    
    // Update ghost text immediately
    if (query.isNotEmpty) {
      final filtered = _allClinics.where((clinic) {
        return clinic.clinicName.toLowerCase().startsWith(query.toLowerCase());
      }).toList();
      
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
    
    // Debounced search
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final queryLower = query.toLowerCase();
      setState(() {
        if (query.isEmpty) {
          _filteredClinics = _allClinics;
          _clinicSuggestions = [];
          _placeSuggestions = [];
        } else {
          // فلترة العيادات للخريطة
          _filteredClinics = _allClinics.where((clinic) {
            return (clinic.clinicName.toLowerCase().contains(queryLower) ||
                    clinic.doctorName.toLowerCase().contains(queryLower) ||
                    (clinic.address?.toLowerCase() ?? '').contains(queryLower));
          }).toList();
          
          // مقترحات العيادات للقائمة المنبثقة
          if (query.length >= 2) {
            _clinicSuggestions = _filteredClinics.take(3).toList(); // أول 3 عيادات مطابقة
            _searchPlaces(query);
          } else {
            _clinicSuggestions = [];
            _placeSuggestions = [];
          }
        }
        _loadClinicMarkers(_filteredClinics);
      });
    });
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isLoading = false;
    });
  }

  void _loadClinicMarkers(List<ClinicWithDoctorInfo> clinics) {
    final markers = <Marker>[];
    for (final clinic in clinics) {
      markers.add(Marker(
        point: LatLng(clinic.latitude, clinic.longitude),
        width: 40, height: 40,
        child: GestureDetector(
          onTap: () => _showClinicDetails(clinic),
          child: Icon(Icons.local_hospital, color: Colors.red, size: 40),
        ),
      ));
    }

    if (mounted) {
      setState(() {
        _clinicMarkers = markers;
      });
    }
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
    final messenger = ScaffoldMessenger.of(context);

    try {
      final position = await _locationService.getHighAccuracyPosition();
      if (position == null) {
        if (mounted) messenger.showSnackBar(SnackBar(content: Text('clinics_feature.location_error'.tr()), backgroundColor: Colors.orange));
        return;
      }

      setState(() {
        _currentUserPosition = position;
      });

      final currentUser = ref.read(userDataProvider).asData?.value;
      if (currentUser != null) {
        await ref.read(userRepositoryProvider).updateUserLocation(userId: currentUser.id, latitude: position.latitude, longitude: position.longitude);
        ref.invalidate(userDataProvider);
        _mapController.move(LatLng(position.latitude, position.longitude), 14);
        messenger.showSnackBar(SnackBar(content: Text('clinics_feature.location_success'.tr()), backgroundColor: Colors.green));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  List<Widget> _getTileLayers() {
    return [
      TileLayer(
        urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.fieldawy.store', maxZoom: 20, tileProvider: RetryTileProvider(),
      ),
      TileLayer(
        urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.fieldawy.store', maxZoom: 20, tileProvider: RetryTileProvider(),
      ),
      TileLayer(
        urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.fieldawy.store', maxZoom: 20, tileProvider: RetryTileProvider(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final clinicsAsync = ref.watch(allClinicsWithDoctorInfoProvider);
    final userData = ref.watch(userDataProvider);

    // Initialize user position from provider if available
    if (_currentUserPosition == null && userData.hasValue) {
      final user = userData.value;
      if (user?.lastLatitude != null && user?.lastLongitude != null) {
        _currentUserPosition = Position(
          latitude: user!.lastLatitude!,
          longitude: user.lastLongitude!,
          timestamp: DateTime.now(),
          accuracy: 50, // Default accuracy, will be updated on manual refresh
          altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('clinics_feature.title'.tr()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isFabDisabled || _isUpdatingLocation ? null : _updateMyLocation,
        backgroundColor: _isFabDisabled || _isUpdatingLocation ? Colors.grey : Theme.of(context).primaryColor,
        tooltip: 'clinics_feature.my_location'.tr(),
        child: _isUpdatingLocation 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.my_location, color: Colors.white),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // إخفاء الكيبورد عند النقر على الخريطة
          FocusScope.of(context).unfocus();
          if (_searchController.text.isEmpty) {
            setState(() {
              _ghostText = '';
              _fullSuggestion = '';
            });
          }
        },
        child: Column(
          children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Stack(
                  children: [
                    TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'clinics_feature.search_hint'.tr(), 
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear), 
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _ghostText = '';
                                  _fullSuggestion = '';
                                  _placeSuggestions = [];
                                });
                              }
                            )
                          : null,
                    ),
                  ),
                  if (_ghostText.isNotEmpty)
                    Positioned(
                      top: 11,
                      right: 55,
                      child: GestureDetector(
                        onTap: () {
                          if (_fullSuggestion.isNotEmpty) {
                            _searchController.text = _fullSuggestion;
                            setState(() {
                              _ghostText = '';
                              _fullSuggestion = '';
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                                : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _ghostText,
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // القائمة المنبثقة لمقترحات العيادات والأماكن
              if (_clinicSuggestions.isNotEmpty || _placeSuggestions.isNotEmpty || _isSearchingPlaces)
                Card(
                  elevation: 8,
                  margin: const EdgeInsets.only(top: 4),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSearchingPlaces)
                        const LinearProgressIndicator(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 140), // ارتفاع يكفي لاقتراحين تقريباً
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            // عرض مقترحات العيادات
                            ..._clinicSuggestions.map((clinic) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.shade50,
                                radius: 16,
                                child: const Icon(Icons.local_hospital, color: Colors.red, size: 18),
                              ),
                              title: Text(clinic.clinicName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(clinic.doctorName, style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.arrow_outward_rounded, size: 14),
                              onTap: () => _moveToLocation(clinic.latitude, clinic.longitude, clinic: clinic),
                            )),
                            if (_clinicSuggestions.isNotEmpty && _placeSuggestions.isNotEmpty)
                              const Divider(height: 1),
                            // عرض مقترحات الأماكن (محدودة بما يكمل 5 إجمالي)
                            ..._placeSuggestions.take(5 - _clinicSuggestions.length).map((suggestion) {
                              final displayName = suggestion['display_name'];
                              final lat = double.parse(suggestion['lat']);
                              final lon = double.parse(suggestion['lon']);
                              
                              return ListTile(
                                leading: const Icon(Icons.location_on_outlined, color: Colors.blue, size: 20),
                                title: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () => _moveToLocation(lat, lon, name: displayName),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
          Expanded(
            child: clinicsAsync.when(
              data: (clinics) {
                if (_allClinics.isEmpty) {
                  _allClinics = clinics;
                  _filteredClinics = clinics;
                  _loadClinicMarkers(_filteredClinics);
                }
                
                if (_allClinics.isEmpty && !_isLoading) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.location_off, size: 64, color: Colors.grey), SizedBox(height: 16), Text('clinics_feature.no_clinics'.tr(), style: TextStyle(fontSize: 18, color: Colors.grey))]));
                }
                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        keepAlive: true,
                        initialCenter: _initialPosition,
                        initialZoom: 12, minZoom: 3, maxZoom: 20,
                        onTap: (_, __) => {},
                      ),
                      children: [ 
                        ..._getTileLayers(), 
                        if (_currentUserPosition != null)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude),
                                radius: _currentUserPosition!.accuracy,
                                useRadiusInMeter: true,
                                color: Colors.blue.withOpacity(0.1),
                                borderColor: Colors.blue.withOpacity(0.3),
                                borderStrokeWidth: 2,
                              )
                            ]
                          ),
                        MarkerLayer(markers: [
                          ..._clinicMarkers,
                          if (_currentUserPosition != null)
                            Marker(
                              point: LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude),
                              width: 50, height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue, shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [BoxShadow(color: Colors.blue.withAlpha(128), blurRadius: 8, spreadRadius: 2)],
                                ),
                                child: Icon(Icons.person_pin_circle, color: Colors.white, size: 28),
                              ),
                            ),
                        ]), 
                        RichAttributionWidget(attributions: [TextSourceAttribution('© Esri, HERE, Garmin, FAO, NOAA, USGS', onTap: () {})])
                      ],
                    ),
                    if (_isLoading)
                      Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 64, color: Colors.red), const SizedBox(height: 16), Text('clinics_feature.error_load'.tr()), const SizedBox(height: 16), ElevatedButton(onPressed: () => ref.refresh(allClinicsProvider), child: Text('clinics_feature.retry'.tr()))]))
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
    // إذا كانت القيمة فارغة وshowIfEmpty = false، لا تعرض الصف
    if ((value == null || value.isEmpty) && !showIfEmpty) {
      return const SizedBox.shrink();
    }
    
    // إذا كانت القيمة فارغة وshowIfEmpty = true، اعرض "غير متوفر"
    final displayValue = (value == null || value.isEmpty) ? 'clinics_feature.details.unavailable'.tr() : value;
    final isUnavailable = (value == null || value.isEmpty);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 16,
                    color: isUnavailable ? Colors.grey : null,
                    fontStyle: isUnavailable ? FontStyle.italic : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchDirections(BuildContext context) async {
    final lat = clinic.latitude;
    final long = clinic.longitude;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$long');
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); } else { throw 'Could not launch $url'; }
    } catch (e) { messenger.showSnackBar(SnackBar(content: Text('clinics_feature.map_launch_error'.tr()))); }
  }

  Widget _buildWhatsAppRow(BuildContext context, String? whatsappNumber) {
    if (whatsappNumber == null || whatsappNumber.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Icon(FontAwesomeIcons.whatsapp, color: Theme.of(context).primaryColor, size: 22), const SizedBox(width: 16), const Expanded(child: Text('WhatsApp', style: TextStyle(fontSize: 16))), IconButton(icon: const Icon(Icons.send, color: Colors.green), tooltip: 'Open in WhatsApp', onPressed: () async { final messenger = ScaffoldMessenger.of(context); final cleanedNumber = whatsappNumber.replaceAll(RegExp(r'[^0-9]'), ''); final fullNumber = cleanedNumber.startsWith('20') ? cleanedNumber : '20$cleanedNumber'; final url = Uri.parse('https://wa.me/$fullNumber'); try { if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); } else { throw 'Could not launch $url'; } } catch (e) { messenger.showSnackBar(SnackBar(content: Text('clinics_feature.whatsapp_launch_error'.tr()))); }})]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? rawAddress = clinic.address;
    String? cleanedAddress = rawAddress;

    if (rawAddress != null) {
      final commaIndex = rawAddress.indexOf(',');
      if (commaIndex != -1) {
        cleanedAddress = rawAddress.substring(commaIndex + 1).trim();
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(clinic.clinicName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), const Divider(),
        _buildInfoRow(context, Icons.person_outline, 'clinics_feature.details.doctor'.tr(), clinic.doctorName),
        _buildInfoRow(context, Icons.location_on_outlined, 'clinics_feature.details.address'.tr(), cleanedAddress),
        _buildInfoRow(context, Icons.phone_outlined, 'clinics_feature.details.phone'.tr(), clinic.clinicPhoneNumber, showIfEmpty: true),
        _buildWhatsAppRow(context, clinic.doctorWhatsappNumber),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.directions), label: Text('clinics_feature.details.directions'.tr()), onPressed: () => _launchDirections(context), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      ]),
    );
  }
}