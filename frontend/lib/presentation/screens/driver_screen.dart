/* import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../services/map_api_service.dart';
import '../../services/socket_io_service.dart';

class DriverScreen extends StatefulWidget {
  final String userId;
  const DriverScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _DriverScreenState createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final MapApiService _mapApiService = MapApiService();
  late SocketService _socketService;

  // --- State Variables ---
  static const LatLng _initialPosition = LatLng(20.9374, 77.7796); // Amravati
  LatLng _currentPosition = _initialPosition;
  bool _isTripActive = false;

  Timer? _locationUpdateTimer;
  List<Polyline> _polylines = [];
  List<LatLng> _routePoints = [];
  List<Marker> _markers = [];
  
  // --- NEW: Replaced SearchController with Dropdown Controllers ---
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  LatLng? _destination;

  // --- NEW: List of locations in Amravati ---
  final List<String> _amravatiPlaces = [
    'Amravati Railway Station',
    'Rajkamal Square',
    'Kathora Gate',
    'Camp Area',
    'VMV Road',
    'Walgaon Road',
    'Dastur Nagar',
    'Maltekdi',
    'Shivaji Nagar',
    'Nawathe Square',
    'Rathi Nagar',
    'Hanuman Vyayam Prasarak Mandal',
    'SRPF Camp',
    'Irwin Square',
    'Badnera Railway Station',
    'Sai Nagar',
    'Gopal Nagar',
    'Jawahar Road',
    'Rajapeth',
    'Paranjpe Colony',
    'Sharda Nagar',
    'Gadge Nagar',
    'Nandgaon Peth',
    'MIDC',
    'Bharat Nagar',
    'Rukhmini Nagar',
    'Shivneri Colony',
    'Shivaji Park',
    'Siddhivinayak Colony',
  ].toSet().toList(); // .toSet().toList() removes duplicates

  // --- Animation ---
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _socketService = Provider.of<SocketService>(context, listen: false);
    _socketService.connectAndListen(userId: widget.userId, role: 'driver');

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Use a more generic marker update function
    _updateMarkers();
  }

  

  // --- MODIFIED: This function now handles all marker states ---
  void _updateMarkers() {
    setState(() {
      _markers = [
        // Source / Current Position Marker
        Marker(
          point: _currentPosition,
          width: 80,
          height: 80,
          child: Icon(
            _isTripActive ? Icons.drive_eta_rounded : Icons.trip_origin,
            color: Colors.green[700],
            size: 30,
          ),
        ),
        // Destination Marker (only if one is selected)
        if (_destination != null)
          Marker(
            point: _destination!,
            width: 80,
            height: 80,
            // Using the hospital icon from your _startJourney logic
            child: Icon(Icons.local_hospital, color: Colors.red[700], size: 30),
          ),
      ];
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationUpdateTimer?.cancel();
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  // --- UNCHANGED: Your core logic ---
  void _startJourney() async {
    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a destination')));
      return;
    }
    final routePoints = await _mapApiService.getShortestRoute(_currentPosition, _destination!);
    _routePoints = routePoints;

    final routePolyline = Polyline(
      points: routePoints,
      strokeWidth: 5.0,
      color: Colors.blue.withOpacity(0.8),
    );
      
    setState(() {
      _polylines = [routePolyline];
      _isTripActive = true;
      // Update markers to reflect trip start
      _updateMarkers(); 
    });

    _mapController.fitBounds(LatLngBounds.fromPoints(routePoints), options: FitBoundsOptions(padding: const EdgeInsets.all(50.0)));

    _startSendingLocationUpdates();
  }

  // --- MODIFIED: Added one line to update the marker on the map ---
  void _startSendingLocationUpdates() {
      _locationUpdateTimer?.cancel();
      // This timer simulates the driver moving along a path.
      int idx = 0;
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (idx >= _routePoints.length) {
          _endJourney();
          return;
        }
        _currentPosition = _routePoints[idx];
        idx++;

        // --- CRITICAL FIX: This updates the marker icon on the map ---
        _updateMarkers();
        // --- End of Fix ---

        _socketService.sendLocationUpdate(
          ambulanceId: widget.userId,
          lat: _currentPosition.latitude,
          lng: _currentPosition.longitude
        );
        print("Sent location update: $_currentPosition");
      });
  }

  // --- UNCHANGED: Your core logic ---
  void _endJourney() {
    _locationUpdateTimer?.cancel();
    setState(() {
      _isTripActive = false;
      _polylines = [];
      _destination = null; // Clear destination
      _destinationController.clear();
      _updateMarkers(); // Reset markers
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver On Duty'),
        backgroundColor: Colors.red[800],
        actions: [
          if (_isTripActive)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Row(
                children: [
                    const Text("TRIP ACTIVE", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Icon(Icons.warning_amber_rounded, color: Colors.yellow[300]),
                ],
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.ats_frontend', // Recommended for OSM
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),
            Positioned(
            top: 10,
            left: 10,
            right: 10,
            // --- MODIFIED: Using new Source/Dest Bar ---
            child: _buildSourceDestBar(),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: _buildJourneyButton(),
            ),
          )
        ],
      ),
    );
  }

  // --- NEW: Replaces _buildSearchBar() ---
  Widget _buildSourceDestBar() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 22),
                const SizedBox(width: 8),
                const Text('Source:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sourceController.text.isNotEmpty ? _sourceController.text : null,
                    items: _amravatiPlaces.map((place) => DropdownMenuItem(value: place, child: Text(place, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _sourceController.text = val;
                        _performSourceSearch();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Select source',
                      border: InputBorder.none,
                    ),
                    isExpanded: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.red, size: 22),
                const SizedBox(width: 8),
                const Text('Destination:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _destinationController.text.isNotEmpty ? _destinationController.text : null,
                    items: _amravatiPlaces.map((place) => DropdownMenuItem(value: place, child: Text(place, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _destinationController.text = val;
                        _performDestSearch();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Select destination',
                      border: InputBorder.none,
                    ),
                    isExpanded: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW: Replaces _performSearch() ---
  Future<void> _performSourceSearch() async {
    /* final query = _sourceController.text.trim();
    if (query.isEmpty) return;
    final pos = await _mapApiService.geocodeAddress(query);
    if (pos == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source location not found')));
      return;
    }
    setState(() {
      _currentPosition = pos;
    });
    _updateMarkers();
    _mapController.move(pos, 14.0); */
    final query = _sourceController.text.trim();
    if (query.isEmpty) return;

    // --- FIX: Make the query more specific ---
    final specificQuery = "$query, Amravati, Maharashtra";
    // --- End of Fix ---

    final pos = await _mapApiService.geocodeAddress(specificQuery); // Use specificQuery
    if (pos == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source location not found')));
      return;
    }
    setState(() {
      _currentPosition = pos;
    });
    _updateMarkers();
    _mapController.move(pos, 14.0);
  }

  // --- NEW: Replaces _performSearch() ---
  Future<void> _performDestSearch() async {
    /* final query = _destinationController.text.trim();
    if (query.isEmpty) return;
    final pos = await _mapApiService.geocodeAddress(query);
    if (pos == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destination not found')));
      return;
    }
    setState(() {
      _destination = pos;
    });
    _updateMarkers();
    _mapController.move(pos, 14.0); */
    final query = _destinationController.text.trim();
    if (query.isEmpty) return;
    
    // --- FIX: Make the query more specific ---
    final specificQuery = "$query, Amravati, Maharashtra";
    // --- End of Fix ---

    final pos = await _mapApiService.geocodeAddress(specificQuery); // Use specificQuery
    if (pos == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destination not found')));
      return;
    }
    setState(() {
      _destination = pos; // This will now be set correctly
    });
    _updateMarkers();
    _mapController.move(pos, 14.0);
  }

  // --- UNCHANGED: Your core logic ---
  Widget _buildJourneyButton() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: ElevatedButton.icon(
        icon: Icon(_isTripActive ? Icons.stop_circle_outlined : Icons.play_arrow_rounded, size: 32),
        label: Text(
          _isTripActive ? 'END JOURNEY' : 'START JOURNEY',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        onPressed: _isTripActive ? _endJourney : _startJourney,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isTripActive ? Colors.blueGrey[700] : Colors.red[700],
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          elevation: 8.0,
        ),
      ),
    );
  }
} */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../services/map_api_service.dart';
import '../../services/socket_io_service.dart';
import 'package:geolocator/geolocator.dart'; // Import for GPS

class DriverScreen extends StatefulWidget {
  final String userId;
  const DriverScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _DriverScreenState createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final MapApiService _mapApiService = MapApiService();
  late SocketService _socketService;

  // --- State Variables ---
  static const LatLng _initialPosition = LatLng(20.9374, 77.7796); // Amravati
  LatLng _currentPosition = _initialPosition;
  bool _isTripActive = false;
  
  Timer? _locationUpdateTimer;
  List<Polyline> _polylines = [];
  List<LatLng> _routePoints = [];
  List<Marker> _markers = [];
  
  final TextEditingController _sourceController = TextEditingController();
  LatLng? _destination;
  String? _destinationAddress;

  // --- Hardcoded Locations for Dropdown ---
  final List<String> _amravatiPlaces = [
    'Amravati Railway Station',
    'Rajkamal Square',
    'Kathora Gate',
    'Camp Area',
    'VMV Road',
    'Walgaon Road',
    'Dastur Nagar',
    'Maltekdi',
    'Shivaji Nagar',
    'Nawathe Square',
    'Rathi Nagar',
    'Hanuman Vyayam Prasarak Mandal',
    'SRPF Camp',
    'Irwin Square',
    'Badnera Railway Station',
    'Sai Nagar',
    'Gopal Nagar',
    'Jawahar Road',
    'Rajapeth',
    'Paranjpe Colony',
    'Sharda Nagar',
    'Gadge Nagar',
    'Nandgaon Peth',
    'MIDC',
    'Bharat Nagar',
    'Rukhmini Nagar',
    'Shivneri Colony',
    'Shivaji Park',
    'Siddhivinayak Colony',
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

  // --- Animation ---
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _socketService = Provider.of<SocketService>(context, listen: false);
    _socketService.connectAndListen(userId: widget.userId, role: 'driver');

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateMarkers();
    _getCurrentLocation(); // --- Try to get GPS location on start ---
  }

  /// --- Handles getting the device's current GPS location ---
  Future<void> _getCurrentLocation() async {
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
      
      LatLng newPos = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = newPos;
        _sourceController.text = "My Current Location"; // Update text
      });
      _updateMarkers();
      _mapController.move(newPos, 16.0); // Zoom in closer
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  /// --- Updates all markers on the map ---
  void _updateMarkers() {
    setState(() {
      _markers = [
        // Source / Current Position Marker
        Marker(
          point: _currentPosition,
          width: 80,
          height: 80,
          child: Icon(
            _isTripActive ? Icons.drive_eta_rounded : Icons.trip_origin,
            color: Colors.green[700],
            size: 30,
          ),
        ),
        // Destination Marker
        if (_destination != null)
          Marker(
            point: _destination!,
            width: 80,
            height: 80,
            child: Icon(Icons.local_hospital, color: Colors.red[700], size: 30),
          ),
      ];
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationUpdateTimer?.cancel();
    _sourceController.dispose();
    super.dispose();
  }

  /// --- Handles long-press on map to set destination ---
  void _handleLongPress(TapPosition tap, LatLng latlng) async {
    if (_isTripActive) return; // Don't allow changing destination during a trip

    setState(() {
      _destination = latlng;
      _destinationAddress = "Loading address...";
    });
    _updateMarkers();

    try {
      final address = await _mapApiService.reverseGeocode(latlng);
      if (mounted) setState(() { _destinationAddress = address; });
    } catch (e) {
      if (mounted) setState(() { _destinationAddress = "Tapped Location"; });
    }
  }

  /// --- Starts the trip, called by "Start Journey" button ---
  void _startJourney() async {
    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Long-press on the map to set a destination')));
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calculating shortest route...')));

    try {
      final routePoints = await _mapApiService.getShortestRoute(_currentPosition, _destination!);
      _routePoints = routePoints;

      if (routePoints.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find a route.')));
        return;
      }

      // --- Dark Violet Polyline Highlight ---
      final routePolyline = Polyline(
        points: routePoints,
        strokeWidth: 8.0, 
        color: Colors.deepPurple[700]!.withOpacity(0.9),
        borderColor: Colors.purple[900]!.withOpacity(0.8),
        borderStrokeWidth: 2.0,
      );
        
      setState(() {
        _isTripActive = true;
        _polylines = [routePolyline];
        _updateMarkers(); 
      });

      _mapController.fitBounds(LatLngBounds.fromPoints(routePoints), options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)));

      _startSendingLocationUpdates();

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error finding route: $e')));
    }
  }

  /// --- Simulates driver movement and sends socket updates ---
  void _startSendingLocationUpdates() {
      _locationUpdateTimer?.cancel();
      int idx = 0;
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (idx >= _routePoints.length) {
          _endJourney(); // Trip is over
          return;
        }
        
        _currentPosition = _routePoints[idx];
        idx++;
        
        _updateMarkers(); // Move the driver icon
        
        // Send location to server
        _socketService.sendLocationUpdate(
          ambulanceId: widget.userId,
          lat: _currentPosition.latitude,
          lng: _currentPosition.longitude
        );
        print("Sent location update: $_currentPosition");
      });
  }

  /// --- Ends the trip, called by "End Journey" button or end of route ---
  void _endJourney() {
    _locationUpdateTimer?.cancel();
    setState(() {
      _isTripActive = false;
      _polylines = [];
      _destination = null; 
      _destinationAddress = null;
      _sourceController.text = "My Current Location"; // Reset to default
      _updateMarkers();
    });
    // Attempt to get location again to reset
    _getCurrentLocation();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver On Duty'),
        backgroundColor: Colors.red[800],
        actions: [
          if (_isTripActive)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Row(
                children: [
                    const Text("TRIP ACTIVE", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Icon(Icons.warning_amber_rounded, color: Colors.yellow[300]),
                ],
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 14.0,
              onLongPress: _handleLongPress, // For destination
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.ats_frontend', 
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: _buildSourceDestBar(), // --- This is the new card ---
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: _buildJourneyButton(),
            ),
          )
        ],
      ),
    );
  }

  /// --- This widget now contains BOTH source options ---
  Widget _buildSourceDestBar() {
    bool isEnabled = !_isTripActive;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SOURCE ROW ---
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 22),
                const SizedBox(width: 8),
                const Text('Source:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                // --- OPTION 1: Hardcoded Dropdown ---
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sourceController.text.isNotEmpty && _amravatiPlaces.contains(_sourceController.text) 
                            ? _sourceController.text 
                            : null, // Only show a value if it's from the list
                    hint: Text(
                      _sourceController.text.isEmpty 
                        ? 'Select source depot' 
                        : _sourceController.text, // Shows "My Current Location"
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: _amravatiPlaces.map((place) => DropdownMenuItem(value: place, child: Text(place, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: isEnabled ? (val) {
                      if (val != null) {
                        _sourceController.text = val;
                        _performSourceSearch(); // Use hardcoded location
                      }
                    } : null, 
                    decoration: const InputDecoration(border: InputBorder.none),
                    isExpanded: true,
                  ),
                ),
                // --- OPTION 2: "My Location" Button ---
                IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.blue),
                  onPressed: isEnabled ? _getCurrentLocation : null, // Use GPS
                  tooltip: 'Get Current Location',
                )
              ],
            ),
            const Divider(height: 16),
            // --- DESTINATION ROW ---
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.red, size: 22),
                const SizedBox(width: 8),
                const Text('Destination:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _destinationAddress ?? 'Long-press on map to set...',
                    style: TextStyle(
                      fontSize: 15,
                      color: _destinationAddress == null ? Colors.black54 : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// --- This is for the Hardcoded Dropdown ---
  void _performSourceSearch() {
    final query = _sourceController.text.trim();
    if (query.isEmpty) return;
    
    final pos = _amravatiCoordinates[query];

    if (pos == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source location not in database.')));
      return;
    }
    setState(() {
      _currentPosition = pos;
    });
    _updateMarkers();
    _mapController.move(pos, 14.0);
  }

  /// --- The Start/End Journey Button ---
  Widget _buildJourneyButton() {
    bool isStartDisabled = !_isTripActive && _destination == null;

    return ScaleTransition(
      scale: _pulseAnimation,
      child: ElevatedButton.icon(
        icon: Icon(_isTripActive ? Icons.stop_circle_outlined : Icons.play_arrow_rounded, size: 32),
        label: Text(
          _isTripActive ? 'END JOURNEY' : 'START JOURNEY',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        onPressed: isStartDisabled ? null : (_isTripActive ? _endJourney : _startJourney),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isTripActive 
            ? Colors.blueGrey[700] 
            : (isStartDisabled ? Colors.grey : Colors.red[700]), 
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          elevation: 8.0,
        ),
      ),
    );
  }
}