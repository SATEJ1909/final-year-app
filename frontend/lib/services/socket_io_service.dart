import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'auth_service.dart';
import 'package:latlong2/latlong.dart';

// --- DATA MODELS ---
class AmbulancePosition {
  final String ambulanceId;
  final double lat;
  final double lng;
  final double? heading; // NEW: Added heading for rotation

  AmbulancePosition({
    required this.ambulanceId, 
    required this.lat, 
    required this.lng,
    this.heading, // NEW: Optional heading
  });

  factory AmbulancePosition.fromJson(Map<String, dynamic> json) {
    return AmbulancePosition(
      ambulanceId: json['ambulanceId'] ?? json['driverId'] ?? 'unknown',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble(), // NEW: Parse heading
    );
  }
}

class ProximityAlert {
  final String ambulanceId;
  final String message;

  ProximityAlert({
    required this.ambulanceId, 
    required this.message
  });

  factory ProximityAlert.fromJson(Map<String, dynamic> json) {
    return ProximityAlert(
      ambulanceId: json['ambulanceId'] ?? 'unknown',
      message: json['message'] ?? 'Ambulance is approaching!',
    );
  }
}

class SocketService with ChangeNotifier {
  late IO.Socket _socket;

  // --- STREAMS ---
  final StreamController<AmbulancePosition> _positionUpdateController = StreamController.broadcast();
  Stream<AmbulancePosition> get positionUpdateStream => _positionUpdateController.stream;

  final StreamController<ProximityAlert> _alertController = StreamController.broadcast();
  Stream<ProximityAlert> get alertStream => _alertController.stream;

  bool get isConnected => _socket.connected;

  SocketService() {
    _initSocket();
  }

  void _initSocket() {
    // Change this URL to your ngrok URL when testing with a friend
    _socket = IO.io('http://192.168.22.33:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket.onConnect((_) => print('Socket connected: ${_socket.id}'));
    _socket.onDisconnect((_) => print('Socket disconnected'));
    _socket.onError((data) => print('Socket Error: $data'));

    // --- LISTENERS FOR INCOMING EVENTS ---
    _socket.on('positionUpdate', (data) {
      try {
        _positionUpdateController.add(AmbulancePosition.fromJson(data));
      } catch (e) {
        print('Error parsing positionUpdate: $e');
      }
    });

    _socket.on('proximityAlert', (data) {
      try {
        _alertController.add(ProximityAlert.fromJson(data));
      } catch (e) {
        print('Error parsing proximityAlert: $e');
      }
    });
  }

  // --- PUBLIC METHODS ---
  void connectAndListen({required String userId, required String role, LatLng? location}) {
    if (_socket.connected) return;

    AuthService.getToken().then((token) {
      if (token != null) {
        final options = _socket.io.options as Map<String, dynamic>;
        options['auth'] = {'token': token};
      }
      _socket.connect();
    });
    
    _socket.onConnect((_) {
      _socket.emit('join', {
        'userId': userId,
        'role': role,
        if (location != null) 'location': {'lat': location.latitude, 'lng': location.longitude}
      });
    });
  }

  /// Updated for Driver Screen to send rotation
  void sendLocationUpdate({
    required String ambulanceId, 
    required double lat, 
    required double lng,
    double? heading, // NEW: Added heading parameter
  }) {
    if (!_socket.connected) return;
    _socket.emit('updateLocation', {
      'ambulanceId': ambulanceId,
      'lat': lat,
      'lng': lng,
      'heading': heading, // NEW: Emit heading
    });
  }

  void updatePoliceLocation(LatLng location) {
    if (!_socket.connected) return;
    _socket.emit('updatePoliceLocation', {
      'lat': location.latitude,
      'lng': location.longitude,
    });
  }

  void disconnect() {
    _socket.dispose();
  }

  @override
  void dispose() {
    _positionUpdateController.close();
    _alertController.close();
    _socket.dispose();
    super.dispose();
  }
}