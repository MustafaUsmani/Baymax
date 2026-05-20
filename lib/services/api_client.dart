import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crisis_link/core/constants.dart';

class ApiClient {
  final String _baseUrl = kApiBaseUrl;

  Future<Map<String, dynamic>> health() async {
    final response = await http.get(Uri.parse('$_baseUrl/')).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Health check failed with status ${response.statusCode}');
  }

  Future<Map<String, dynamic>> readiness() async {
    final response = await http.get(Uri.parse('$_baseUrl/ready')).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Readiness check failed with status ${response.statusCode}');
  }

  Future<List<dynamic>> getIncidents({int limit = 100, String? status, String? type}) async {
    final queryParams = <String, String>{'limit': limit.toString()};
    if (status != null) queryParams['status'] = status;
    if (type != null) queryParams['type'] = type;
    final uri = Uri.parse('$_baseUrl/incidents').replace(queryParameters: queryParams);
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch incidents: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getIncidentById(String id) async {
    final uri = Uri.parse('$_baseUrl/incidents/$id');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch incident $id: ${response.statusCode}');
  }

  Future<List<dynamic>> getNearbyIncidents(double lat, double lng, {int radiusKm = 5}) async {
    final uri = Uri.parse('$_baseUrl/incidents/nearby').replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'radius_km': radiusKm.toString(),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch nearby incidents: ${response.statusCode}');
  }

  Future<List<dynamic>> getCurrentSituations() async {
    final response = await http.get(Uri.parse('$_baseUrl/situations/current')).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch current situations: ${response.statusCode}');
  }
}
