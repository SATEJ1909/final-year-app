import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'auth_service.dart';
import 'package:latlong2/latlong.dart'; // UPDATED: Using latlong2 for LatLng

// --- DATA MODELS FOR SOCKET EVENTS ---
// Using classes makes the data from sockets type-safe and easier to work with.
class AmbulancePosition {
  final String ambulanceId;
  final double lat;
  final double lng;
  AmbulancePosition({required this.ambulanceId, required this.lat, required this.lng});
}

class ProximityAlert {
  final String ambulanceId;
  final String message;
  ProximityAlert({required this.ambulanceId, required this.message});
}


class SocketService with ChangeNotifier {
  late IO.Socket _socket;

  // --- STREAMS FOR REAL-TIME UI UPDATES ---
  // The UI will listen to these streams to react to new data.
  final StreamController<AmbulancePosition> _positionUpdateController = StreamController.broadcast();
  Stream<AmbulancePosition> get positionUpdateStream => _positionUpdateController.stream;

  final StreamController<ProximityAlert> _alertController = StreamController.broadcast();
  Stream<ProximityAlert> get alertStream => _alertController.stream;

  // --- PUBLIC GETTERS ---
  bool get isConnected => _socket.connected;

  // --- INITIALIZATION ---
  SocketService() {
    _initSocket();
  }

  void _initSocket() {
    // IMPORTANT: Replace with your actual Node.js server address.
    // Use http://10.0.2.2:5000 for Android emulator to connect to localhost.
    // Use http://localhost:5000 for iOS simulator.
    _socket = IO.io('http://192.168.22.33:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false, // We will connect manually.
    });

    _socket.onConnect((_) => print('Socket connected: ${_socket.id}'));
    _socket.onDisconnect((_) => print('Socket disconnected'));
    _socket.onError((data) => print('Socket Error: $data'));

    // --- LISTENERS FOR INCOMING EVENTS ---
    _socket.on('ambulancePositionUpdate', (data) {
      final position = AmbulancePosition(
        ambulanceId: data['ambulanceId'],
        lat: data['lat'].toDouble(),
        lng: data['lng'].toDouble(),
      );
      _positionUpdateController.add(position);
    });

    _socket.on('ambulanceProximityAlert', (data) {
      final alert = ProximityAlert(
        ambulanceId: data['ambulanceId'],
        message: data['message'],
      );
      _alertController.add(alert);
    });
  }

  // --- PUBLIC METHODS ---
  void connectAndListen({required String userId, required String role, LatLng? location}) {
    if (_socket.connected) return;
  final options = _socket.io.options as Map<String, dynamic>;
  options['auth'] = {};
    
    // Pass token in the handshake if present.
    AuthService.getToken().then((token) {
      if (token != null) {
  final options = _socket.io.options as Map<String, dynamic>;
  options['auth'] = {'token': token};
      }
      _socket.connect();
    });
    _socket.onConnect((_) {
      // Send the 'join' event once connected.
      _socket.emit('join', {
        'userId': userId,
        'role': role,
        if (location != null) 'location': {'lat': location.latitude, 'lng': location.longitude}
      });
    });
  }

  void sendLocationUpdate({required String ambulanceId, required double lat, required double lng}) {
    if (!_socket.connected) return;
    _socket.emit('updateLocation', {
      'ambulanceId': ambulanceId,
      'lat': lat,
      'lng': lng,
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

