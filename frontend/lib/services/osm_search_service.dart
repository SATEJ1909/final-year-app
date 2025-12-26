import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class OSMSearchService {
  final Dio _dio = Dio();

  /// Get place suggestions
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    final url =
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5";

    final response = await _dio.get(url);

    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Get LatLng from name
  Future<LatLng?> searchToLatLng(String query) async {
    final results = await searchPlaces(query);
    if (results.isEmpty) return null;

    final place = results.first;
    return LatLng(
      double.parse(place['lat']),
      double.parse(place['lon']),
    );
  }
}
