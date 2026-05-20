import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../models/incident.dart';
import '../models/action.dart';
import '../models/forecast.dart';
import '../models/simulation.dart';
import '../models/health.dart';

class ApiService {
  static const String _baseUrl = 'http://34.133.35.93:8000';

  Future<ApiResponse<Map<String, dynamic>>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body));
    return _processResponse(response);
  }

  Future<ApiResponse<Map<String, dynamic>>> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final response = await http.get(uri);
    return _processResponse(response);
  }

  ApiResponse<T> _fromJson<T>(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    return ApiResponse.success(data: fromJson(json));
  }

  ApiResponse<Map<String, dynamic>> _processResponse(http.Response response) {
    final status = response.statusCode;
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (status >= 200 && status < 300) {
      return ApiResponse.success(data: jsonBody);
    } else {
      return ApiResponse.error(message: jsonBody['detail'] ?? 'Unknown error', code: status);
    }
  }

  // Health
  Future<ApiResponse<Health>> fetchHealth() async {
    final resp = await _get('/health');
    if (resp.isSuccess) {
      return ApiResponse.success(data: Health.fromJson(resp.data!));
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // Incidents
  Future<ApiResponse<List<Incident>>> fetchIncidents() async {
    final resp = await _get('/incidents/incidents');
    if (resp.isSuccess) {
      final list = (resp.data!['incidents'] as List)
          .map((e) => Incident.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse.success(data: list);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Incident>> fetchIncidentDetail(int id) async {
    final resp = await _get('/incidents/incidents/$id');
    if (resp.isSuccess) {
      return ApiResponse.success(data: Incident.fromJson(resp.data!));
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // Forecast
  Future<ApiResponse<Forecast>> fetchForecast(int incidentId) async {
    final resp = await _get('/forecast/$incidentId');
    if (resp.isSuccess) {
      return ApiResponse.success(data: Forecast.fromJson(resp.data!));
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // Generic simulation
  Future<ApiResponse<SimulationResult>> simulateGeneric(Map<String, dynamic> payload) async {
    final resp = await _post('/actions/simulate-generic', payload);
    if (resp.isSuccess) {
      return ApiResponse.success(data: SimulationResult.fromJson(resp.data!));
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // Add other endpoints (plan, simulate, execute) as needed.
}
