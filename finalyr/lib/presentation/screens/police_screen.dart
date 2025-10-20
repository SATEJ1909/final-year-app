import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart' hide Marker;
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
        child: Image.asset('assets/ambulance_marker.png'),
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

