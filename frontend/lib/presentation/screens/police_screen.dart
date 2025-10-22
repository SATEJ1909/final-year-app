/* import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../services/socket_io_service.dart';

class PoliceScreen extends StatefulWidget {
  final String userId;
  const PoliceScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _PoliceScreenState createState() => _PoliceScreenState();
}

class _PoliceScreenState extends State<PoliceScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late SocketService _socketService;

  // --- State Variables ---
  // Default location set to Amravati, Maharashtra, India.
  static const LatLng _policeStationLocation = LatLng(20.9374, 77.7796); 
  final Map<String, Marker> _ambulanceMarkers = {};
  ProximityAlert? _currentAlert;

  // --- Animation Controllers ---
  late AnimationController _alertAnimationController;
  late Animation<Offset> _alertSlideAnimation;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    _socketService = Provider.of<SocketService>(context, listen: false);

    _alertAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _alertSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _alertAnimationController,
      curve: Curves.elasticOut,
    ));

    _connectAndListen();
  }

  void _connectAndListen() {
    _socketService.connectAndListen(
      userId: widget.userId,
      role: 'police',
      location: _policeStationLocation
    );

    _socketService.positionUpdateStream.listen((position) {
      _updateAmbulanceMarker(position);
    });

    _socketService.alertStream.listen((alert) {
      _triggerAlert(alert);
    });
  }

  void _updateAmbulanceMarker(AmbulancePosition position) {
    final marker = Marker(
      width: 80.0,
      height: 80.0,
      point: LatLng(position.lat, position.lng),
      child: Tooltip(
        message: 'Ambulance ${position.ambulanceId}',
        child: SvgPicture.asset('assets/images/ambulance_marker.svg', width: 40, height: 40),
      ),
    );
    setState(() {
      _ambulanceMarkers[position.ambulanceId] = marker;
    });
  }

  void _triggerAlert(ProximityAlert alert) {
    setState(() {
      _currentAlert = alert;
    });
    _alertAnimationController.forward(from: 0.0);
    
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        _alertAnimationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _alertAnimationController.dispose();
    _alertTimer?.cancel();
    // Do not dispose the socket service here if it's managed by a provider at a higher level
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police Live Monitor'),
        backgroundColor: Colors.blue[800],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _policeStationLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.ats_frontend', // Recommended for OSM
              ),
              MarkerLayer(markers: [
                // Police station marker
                Marker(
                  point: _policeStationLocation,
                  width: 80, height: 80,
                  child: Icon(Icons.local_police, color: Colors.blue[900], size: 40),
                ),
                // Live ambulance markers
                ..._ambulanceMarkers.values.toList()
              ]),
            ],
          ),
          if (_currentAlert != null) _buildAlertBanner(),
          Positioned(
            bottom: 10,
            right: 10,
            child: Lottie.asset('assets/lifeline.json', width: 100, height: 100),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNearbyAmbulances,
        icon: const Icon(Icons.local_hospital),
        label: const Text('Nearby Ambulances'),
        backgroundColor: Colors.blue[800],
      ),
    );
  }

  void _showNearbyAmbulances() {
    final Distance distance = const Distance();
    final List<Map<String, dynamic>> nearby = [];
    _ambulanceMarkers.forEach((id, marker) {
      final d = distance.as(LengthUnit.Kilometer, _policeStationLocation, marker.point);
      if (d <= 1.0) {
        nearby.add({'id': id, 'distance': d});
      }
    });
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ambulances within 1 km'),
          content: nearby.isEmpty
              ? const Text('No ambulances nearby.')
              : SizedBox(
                  width: 300,
                  child: ListView(
                    shrinkWrap: true,
                    children: nearby
                        .map((a) => ListTile(
                              leading: const Icon(Icons.local_hospital, color: Colors.red),
                              title: Text('ID: ${a['id']}'),
                              subtitle: Text('Distance: ${a['distance'].toStringAsFixed(2)} km'),
                            ))
                        .toList(),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  Widget _buildAlertBanner() {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: SlideTransition(
        position: _alertSlideAnimation,
        child: Material(
          elevation: 8.0,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red[700],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.yellow[600]!, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROXIMITY ALERT',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentAlert!.message,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => _alertAnimationController.reverse(),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

 */
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart'; // For GPS location
import '../../services/socket_io_service.dart'; // For models and service

class PoliceScreen extends StatefulWidget {
  final String userId;
  const PoliceScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _PoliceScreenState createState() => _PoliceScreenState();
}

class _PoliceScreenState extends State<PoliceScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late SocketService _socketService;

  // --- State Variables ---
  LatLng _currentBaseLocation = const LatLng(20.9374, 77.7796); // Default
  final TextEditingController _baseLocationController = TextEditingController();
  final Map<String, Marker> _ambulanceMarkers = {};
  ProximityAlert? _currentAlert;

  // --- Alert Zone Radius ---
  static const double _alertRadiusInKm = 2.5;
  static const double _alertRadiusInMeters = _alertRadiusInKm * 1000;

  // --- Animation Controllers ---
  late AnimationController _alertAnimationController;
  late Animation<Offset> _alertSlideAnimation;
  Timer? _alertTimer;

  // --- Hardcoded locations for the dropdown ---
  final List<String> _amravatiPlaces = [
    'Amravati Railway Station', 'Rajkamal Square', 'Kathora Gate', 'Camp Area', 'VMV Road',
    'Walgaon Road', 'Dastur Nagar', 'Maltekdi', 'Shivaji Nagar', 'Nawathe Square', 'Rathi Nagar',
    'Hanuman Vyayam Prasarak Mandal', 'SRPF Camp', 'Irwin Square', 'Badnera Railway Station',
    'Sai Nagar', 'Gopal Nagar', 'Jawahar Road', 'Rajapeth', 'Paranjpe Colony', 'Sharda Nagar',
    'Gadge Nagar', 'Nandgaon Peth', 'MIDC', 'Bharat Nagar', 'Rukhmini Nagar', 'Shivneri Colony',
    'Shivaji Park', 'Siddhivinayak Colony',
  ].toSet().toList();

  final Map<String, LatLng> _amravatiCoordinates = {
    'Amravati Railway Station': const LatLng(20.9320, 77.7523),
    'Rajkamal Square': const LatLng(20.9374, 77.7796),
    'Kathora Gate': const LatLng(20.9968, 77.7565),
    'Camp Area': const LatLng(20.9436, 77.7617),
    'VMV Road': const LatLng(20.9600, 77.7600),
    'Walgaon Road': const LatLng(21.0072, 77.7065),
    'Dastur Nagar': const LatLng(20.9165, 77.7766),
    'Maltekdi': const LatLng(20.9300, 77.7700),
    'Shivaji Nagar': const LatLng(20.9400, 77.7700),
    'Nawathe Square': const LatLng(20.9089, 77.7489),
    'Rathi Nagar': const LatLng(20.9500, 77.7600),
    'Hanuman Vyayam Prasarak Mandal': const LatLng(20.9267, 77.7408),
    'SRPF Camp': const LatLng(20.9300, 77.8000),
    'Irwin Square': const LatLng(20.9275, 77.7580),
    'Badnera Railway Station': const LatLng(20.8600, 77.7300),
    'Sai Nagar': const LatLng(20.9000, 77.7300),
    'Gopal Nagar': const LatLng(20.8900, 77.7500),
    'Jawahar Road': const LatLng(20.9319, 77.7502),
    'Rajapeth': const LatLng(20.9207, 77.7559),
    'Paranjpe Colony': const LatLng(20.9411, 77.7778),
    'Sharda Nagar': const LatLng(20.9200, 77.7500),
    'Gadge Nagar': const LatLng(20.9500, 77.7700),
    'Nandgaon Peth': const LatLng(21.0200, 77.8200),
    'MIDC': const LatLng(20.8881, 77.7609),
    'Bharat Nagar': const LatLng(20.8900, 77.7400),
    'Rukhmini Nagar': const LatLng(20.9300, 77.7700),
    'Shivneri Colony': const LatLng(20.9400, 77.7800),
    'Shivaji Park': const LatLng(20.9400, 77.7700),
    'Siddhivinayak Colony': const LatLng(20.9000, 77.7400),
  };

  @override
  void initState() {
    super.initState();
    _socketService = Provider.of<SocketService>(context, listen: false);

    _alertAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _alertSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _alertAnimationController,
      curve: Curves.elasticOut,
    ));

    _connectAndListen();
    _getCurrentBaseLocation(); // Try to get GPS location on start
  }

  void _connectAndListen() {
    _socketService.connectAndListen(
      userId: widget.userId,
      role: 'police',
      location: _currentBaseLocation // Send our initial location
    );

    _socketService.positionUpdateStream.listen((position) {
      _updateAmbulanceMarker(position);
    });

    _socketService.alertStream.listen((alert) {
      _triggerAlert(alert);
    });
  }

  /// Gets the device's current GPS location
  Future<void> _getCurrentBaseLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied.')));
      return;
    } 

    try {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Getting current location...')));
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      final newPos = LatLng(position.latitude, position.longitude);
      _setNewBaseLocation(newPos, "My Current Location");

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  /// Sets the base from the hardcoded dropdown
  void _performBaseLocationSearch() {
    final query = _baseLocationController.text.trim();
    if (query.isEmpty) return;
    
    final pos = _amravatiCoordinates[query];

    if (pos == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Base location not in database.')));
      return;
    }
    _setNewBaseLocation(pos, query);
  }

  /// Central function to update location state and notify server
  void _setNewBaseLocation(LatLng newLocation, String locationName) {
    if (!mounted) return;

    setState(() {
      _currentBaseLocation = newLocation;
      _baseLocationController.text = locationName;
    });
    
    _mapController.move(newLocation, 14.0);
    
    // ---
    // --- THIS IS THE FIX ---
    // ---
    // Instead of _socketService.emit(), we call the public method
    _socketService.updatePoliceLocation(newLocation);
    // You MUST add a listener for 'updatePoliceLocation' on your server!
  }

  void _updateAmbulanceMarker(AmbulancePosition position) {
    final marker = Marker(
      width: 80.0,
      height: 80.0,
      point: LatLng(position.lat, position.lng),
      child: Tooltip(
        message: 'Ambulance ${position.ambulanceId}',
        child:  SvgPicture.asset('assets/images/ambulance_marker.svg', width: 40, height: 40),
      ),
    );
    if (mounted) {
      setState(() {
        _ambulanceMarkers[position.ambulanceId] = marker;
      });
    }
  }

  void _triggerAlert(ProximityAlert alert) {
    if (mounted) {
      setState(() {
        _currentAlert = alert;
      });
      _alertAnimationController.forward(from: 0.0);
      
      _alertTimer?.cancel();
      _alertTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) {
          _alertAnimationController.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _alertAnimationController.dispose();
    _alertTimer?.cancel();
    _baseLocationController.dispose();
    super.dispose();
  }

  /// The new dynamic App Bar
  PreferredSizeWidget _buildBaseLocationBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80.0),
      child: AppBar(
        title: null,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: Colors.blue, size: 22),
                    const SizedBox(width: 8),
                    const Text('Base:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    // Option 1: Hardcoded Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _baseLocationController.text.isNotEmpty && _amravatiPlaces.contains(_baseLocationController.text) 
                                ? _baseLocationController.text 
                                : null,
                        hint: Text(
                          _baseLocationController.text.isEmpty 
                            ? 'Select base depot' 
                            : _baseLocationController.text,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: _amravatiPlaces.map((place) => DropdownMenuItem(value: place, child: Text(place, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _baseLocationController.text = val;
                            _performBaseLocationSearch();
                          }
                        }, 
                        decoration: const InputDecoration(border: InputBorder.none),
                        isExpanded: true,
                      ),
                    ),
                    // Option 2: "My Location" Button
                    IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.blue),
                      onPressed: _getCurrentBaseLocation,
                      tooltip: 'Get Current Location',
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use the new dynamic app bar
      appBar: _buildBaseLocationBar(),
      // Make sure the app bar doesn't overlap the map
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentBaseLocation, // Use dynamic location
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b','c'],
                userAgentPackageName: 'com.example.ats_frontend', 
              ),
              // The dynamic circle
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _currentBaseLocation, // Use dynamic location
                    radius: _alertRadiusInMeters,
                    useRadiusInMeter: true,
                    color: Colors.blue.withOpacity(0.1),
                    borderColor: Colors.blue[800]!,
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
              MarkerLayer(markers: [
                // The dynamic police marker
                Marker(
                  point: _currentBaseLocation, // Use dynamic location
                  width: 80, height: 80,
                  child: const Icon(Icons.local_police, color: Colors.blue, size: 40),
                ),
                ..._ambulanceMarkers.values.toList()
              ]),
            ],
          ),
          if (_currentAlert != null) _buildAlertBanner(),
          Positioned(
            bottom: 10,
            right: 10,
            child: Lottie.asset('assets/lifeline.json', width: 100, height: 100),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNearbyAmbulances,
        icon: const Icon(Icons.local_hospital),
        label: const Text('Nearby Ambulances'),
        backgroundColor: Colors.blue[800],
      ),
    );
  }

  void _showNearbyAmbulances() {
    final Distance distance = const Distance();
    final List<Map<String, dynamic>> nearby = [];
    
    _ambulanceMarkers.forEach((id, marker) {
      // Check distance from the dynamic base
      final d = distance.as(LengthUnit.Kilometer, _currentBaseLocation, marker.point);
      if (d <= _alertRadiusInKm) { 
        nearby.add({'id': id, 'distance': d});
      }
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Ambulances within $_alertRadiusInKm km'),
          content: nearby.isEmpty
              ? const Text('No ambulances inside your zone.')
              : SizedBox(
                  width: 300,
                  child: ListView(
                    shrinkWrap: true,
                    children: nearby
                        .map((a) => ListTile(
                              leading: const Icon(Icons.local_hospital, color: Colors.red),
                              title: Text('ID: ${a['id']}'),
                              subtitle: Text('Distance: ${a['distance'].toStringAsFixed(2)} km'),
                            ))
                        .toList(),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  Widget _buildAlertBanner() {
    // Get the top padding of the screen (the "notch" area)
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Positioned(
      // Position it below the app bar (80.0) + notch area + a small gap (10.0)
      top: topPadding + 80.0 + 10.0,
      left: 10,
      right: 10,
      child: SlideTransition(
        position: _alertSlideAnimation,
        child: Material(
          elevation: 8.0,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red[700],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.yellow[600]!, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROXIMITY ALERT',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentAlert!.message,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => _alertAnimationController.reverse(),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}