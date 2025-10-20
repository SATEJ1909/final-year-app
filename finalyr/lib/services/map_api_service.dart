import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapApiService {
  /// --- PLACEHOLDER ---
  /// In a real app, this method would make an HTTP request to a routing service
  /// like OSRM (Open Source Routing Machine) or another provider.
  ///
  /// It would take a start and end LatLng and return a list of points to draw the polyline.
  Future<List<LatLng>> getShortestRoute(LatLng start, LatLng destination) async {
    // Use OSRM's public API to get the driving route between two points.
    final startCoord = '${start.longitude},${start.latitude}';
    final destCoord = '${destination.longitude},${destination.latitude}';
    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$startCoord;$destCoord?overview=full&geometries=geojson');

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch route: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['routes'] == null || (body['routes'] as List).isEmpty) {
      throw Exception('No route found');
    }

    final coords = body['routes'][0]['geometry']['coordinates'] as List;
    final points = coords
        .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    return points;
  }

  /// Use Nominatim to geocode a user-provided address into coordinates.
  Future<LatLng?> geocodeAddress(String address) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1');

    final response = await http.get(url, headers: {
      'User-Agent': 'ATS-Frontend/1.0 (dev@local)',
    });

    if (response.statusCode != 200) {
      throw Exception('Geocoding failed: ${response.statusCode}');
    }

    final results = jsonDecode(response.body) as List;
    if (results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    final lat = double.tryParse(first['lat'].toString());
    final lon = double.tryParse(first['lon'].toString());
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }
}

