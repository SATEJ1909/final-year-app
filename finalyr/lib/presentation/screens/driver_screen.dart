import 'dart:async';
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
  // Default location set to Amravati, Maharashtra, India.
  static const LatLng _initialPosition = LatLng(20.9374, 77.7796);
  LatLng _currentPosition = _initialPosition;
  bool _isTripActive = false;

  Timer? _locationUpdateTimer;
  List<Polyline> _polylines = [];
  List<LatLng> _routePoints = [];
  List<Marker> _markers = [];
  final TextEditingController _searchController = TextEditingController();

  LatLng? _destination;

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

    _updateDriverMarker(_currentPosition);
  }

  void _updateDriverMarker(LatLng position) {
    setState(() {
      _markers = [
        Marker(
          point: position,
          width: 80,
          height: 80,
          child: Icon(Icons.location_on, color: Colors.blue[600], size: 45),
        ),
      ];
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _startJourney() async {
    if (_destination == null) return;
  final routePoints = await _mapApiService.getShortestRoute(_currentPosition, _destination!);
  _routePoints = routePoints;

    final routePolyline = Polyline(
      points: routePoints,
      strokeWidth: 5.0,
      color: Colors.blue.withOpacity(0.8),
    );
    
    setState(() {
      _polylines = [routePolyline];
      _markers = [
        Marker(
          point: _currentPosition,
          width: 80, height: 80,
          child: Icon(Icons.trip_origin, color: Colors.green[700], size: 30),
        ),
        Marker(
          point: _destination!,
          width: 80, height: 80,
          child: Icon(Icons.local_hospital, color: Colors.red[700], size: 30),
        ),
      ];
      _isTripActive = true;
    });

  _mapController.fitBounds(LatLngBounds.fromPoints(routePoints), options: FitBoundsOptions(padding: const EdgeInsets.all(50.0)));

    _startSendingLocationUpdates();
  }

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

        _socketService.sendLocationUpdate(
          ambulanceId: widget.userId,
          lat: _currentPosition.latitude,
          lng: _currentPosition.longitude
        );
        print("Sent location update: $_currentPosition");
     });
  }

  void _endJourney() {
    _locationUpdateTimer?.cancel();
    setState(() {
      _isTripActive = false;
      _polylines = [];
      _updateDriverMarker(_currentPosition);
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
            child: _buildSearchBar(),
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

  Widget _buildSearchBar() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search destination (address or place)',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _performSearch(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _performSearch,
            )
          ],
        ),
      ),
    );
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final pos = await _mapApiService.geocodeAddress(query);
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found')));
      return;
    }
    setState(() {
      _destination = pos;
      _markers = [
        Marker(
          point: _currentPosition,
          width: 80, height: 80,
          child: Icon(Icons.trip_origin, color: Colors.green[700], size: 30),
        ),
        Marker(
          point: pos,
          width: 80, height: 80,
          child: Icon(Icons.location_on, color: Colors.red[700], size: 40),
        ),
      ];
    });
    _mapController.move(pos, 14.0);
  }

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
}

