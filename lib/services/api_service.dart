import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../models/incident.dart';
import '../models/action.dart';
import '../models/forecast.dart';
import '../models/simulation.dart';
import '../models/health.dart';
import '../core/constants.dart';

class ApiService {
  static const String _baseUrl = kApiBaseUrl;

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

  ApiResponse<Map<String, dynamic>> _processResponse(http.Response response) {
    final status = response.statusCode;
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (status >= 200 && status < 300) {
      return ApiResponse.success(data: jsonBody);
    } else {
      return ApiResponse.error(message: jsonBody['detail'] ?? 'Unknown error', code: status);
    }
  }

  // ── Health & System ────────────────────────────────────────────────

  Future<ApiResponse<Health>> fetchHealth() async {
    final resp = await _get('/health/');
    if (resp.isSuccess) {
      return ApiResponse.success(data: Health.fromJson(resp.data!));
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> fetchReadiness() async {
    final resp = await _get('/health/ready');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> fetchSystemStatus() async {
    final resp = await _get('/system/status');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> fetchVersion() async {
    final resp = await _get('/version');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // ── Incidents ──────────────────────────────────────────────────────

  Future<ApiResponse<List<Incident>>> fetchIncidents() async {
    final resp = await _get('/incidents');
    if (resp.isSuccess) {
      // Backend returns a list directly (not wrapped in 'incidents' key)
      // Handle both possible formats
      List<dynamic> items;
      if (resp.data!.containsKey('incidents')) {
        items = resp.data!['incidents'] as List;
      } else {
        // If the response is a list at the top level, it would have been
        // decoded differently. For safety, treat it as a map with a list.
        items = [];
      }
      final list = items
          .map((e) => Incident.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse.success(data: list);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchIncidentsRaw({
    String? status,
    String? crisisType,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (crisisType != null) queryParams['crisis_type'] = crisisType;
      final uri = Uri.parse('$_baseUrl/incidents').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          final list = data.map((e) => e as Map<String, dynamic>).toList();
          return ApiResponse.success(data: list);
        }
      }
      return ApiResponse.error(message: 'Unexpected response format', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }

  Future<ApiResponse<Incident>> fetchIncidentDetail(int id) async {
    final resp = await _get('/incidents/$id');
    if (resp.isSuccess) {
      return ApiResponse.success(data: Incident.fromJson(resp.data!));
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> fetchCurrentSituations() async {
    final resp = await _get('/situations/current');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // ── Forecasts & Precautions ────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> fetchForecastForIncident(int incidentId) async {
    final resp = await _get('/forecast/$incidentId');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> fetchPrecautions(int incidentId) async {
    final resp = await _get('/precautions/$incidentId');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> fetchLocationRisk(double lat, double lon, {String? destination}) async {
    final params = <String, String>{
      'lat': lat.toString(),
      'lon': lon.toString(),
    };
    if (destination != null) params['destination'] = destination;
    final resp = await _get('/risk/location', params);
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // ── Signals & Data Ingestion ───────────────────────────────────────

  /// Trigger a full ingestion cycle across ALL real data sources
  Future<ApiResponse<Map<String, dynamic>>> triggerFetchAll() async {
    final resp = await _post('/signals/fetch/all', {});
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> triggerFetchSocial() async {
    final resp = await _post('/signals/fetch/social', {});
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> triggerFetchWeather() async {
    final resp = await _post('/signals/fetch/weather', {});
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> triggerFetchTraffic() async {
    final resp = await _post('/signals/fetch/traffic', {});
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> triggerFetchEconomic() async {
    final resp = await _post('/signals/fetch/economic', {});
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> triggerFetchGeopolitical() async {
    final resp = await _post('/signals/fetch/geopolitical', {});
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> triggerFetchIoT() async {
    final resp = await _post('/signals/fetch/iot', {});
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // ── Resources ──────────────────────────────────────────────────────

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchResources({String? status, String? resourceType}) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      if (resourceType != null) params['resource_type'] = resourceType;
      final uri = Uri.parse('$_baseUrl/resources/').replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return ApiResponse.success(data: data.map((e) => e as Map<String, dynamic>).toList());
        }
      }
      return ApiResponse.error(message: 'Unexpected response', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }

  // ── Logs & Traces ──────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> fetchIncidentTrace(int incidentId) async {
    final resp = await _get('/logs/trace/$incidentId');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchIncidentLogs(int incidentId) async {
    try {
      final uri = Uri.parse('$_baseUrl/logs/incidents/$incidentId');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return ApiResponse.success(data: data.map((e) => e as Map<String, dynamic>).toList());
        }
      }
      return ApiResponse.error(message: 'Unexpected response', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }

  // ── Knowledge Base ─────────────────────────────────────────────────

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchPlaybooks({String? crisisType}) async {
    try {
      final params = <String, String>{};
      if (crisisType != null) params['crisis_type'] = crisisType;
      final uri = Uri.parse('$_baseUrl/kb/playbooks').replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return ApiResponse.success(data: data.map((e) => e as Map<String, dynamic>).toList());
        }
      }
      return ApiResponse.error(message: 'Unexpected response', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> searchKnowledgeBase(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/kb/search').replace(queryParameters: {'q': query});
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return ApiResponse.success(data: data.map((e) => e as Map<String, dynamic>).toList());
        }
      }
      return ApiResponse.error(message: 'Unexpected response', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }

  // ── Verification ───────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> requestVerification(int reportId) async {
    try {
      final uri = Uri.parse('$_baseUrl/verification/request').replace(queryParameters: {'report_id': reportId.toString()});
      final response = await http.post(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return ApiResponse.success(data: jsonDecode(response.body) as Map<String, dynamic>);
      }
      return ApiResponse.error(message: 'Verification failed', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }

  // ── Tracking ───────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> registerFamilyMember({
    required String userId,
    required String name,
    String? phoneNumber,
  }) async {
    final resp = await _post('/tracking/register', {
      'user_id': userId,
      'name': name,
      'phone_number': phoneNumber,
    });
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> updateFamilyMemberLocation(int memberId, double lat, double lon) async {
    final resp = await _post('/tracking/location/$memberId', {
      'location': {'lat': lat, 'lon': lon},
    });
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> checkFamilySafety(int memberId) async {
    final resp = await _get('/tracking/status/$memberId');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> listFamilyMembers(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/tracking/list/$userId');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return ApiResponse.success(data: data.map((e) => e as Map<String, dynamic>).toList());
        }
      }
      return ApiResponse.error(message: 'Unexpected response', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────

  Future<ApiResponse<Forecast>> fetchForecast(int incidentId) async {
    final resp = await _get('/forecast/$incidentId');
    if (resp.isSuccess) {
      return ApiResponse.success(data: Forecast.fromJson(resp.data!));
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<SimulationResult>> simulateGeneric(Map<String, dynamic> payload) async {
    final resp = await _post('/actions/simulate-generic', payload);
    if (resp.isSuccess) {
      return ApiResponse.success(data: SimulationResult.fromJson(resp.data!));
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // ── Actions (Extended) ──────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> planAction(int incidentId, String actionType, String strategyName, Map<String, dynamic> parameters) async {
    final resp = await _post('/actions/plan', {
      'incident_id': incidentId,
      'action_type': actionType,
      'strategy_name': strategyName,
      'parameters': parameters,
    });
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> simulateAction(int incidentId, int actionId) async {
    final resp = await _post('/actions/simulate', {
      'incident_id': incidentId,
      'action_id': actionId,
    });
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> executeAction(int actionId) async {
    final resp = await _post('/actions/execute?action_id=$actionId', {});
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> simulateStrategies(int incidentId) async {
    final resp = await _post('/actions/simulate/strategies', {
      'incident_id': incidentId,
    });
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // ── Signals (Extended) ──────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> submitSocialSignal(Map<String, dynamic> payload) async {
    final resp = await _post('/signals/social', payload);
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> submitWeatherSignal(Map<String, dynamic> payload) async {
    final resp = await _post('/signals/weather', payload);
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> submitTrafficSignal(Map<String, dynamic> payload) async {
    final resp = await _post('/signals/traffic', payload);
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> submitEconomicSignal(Map<String, dynamic> payload) async {
    final resp = await _post('/signals/economic', payload);
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> submitGeopoliticalSignal(Map<String, dynamic> payload) async {
    final resp = await _post('/signals/geopolitical', payload);
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> submitSensorSignal(Map<String, dynamic> payload) async {
    final resp = await _post('/signals/sensor', payload);
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> triggerFetchEmergencyMock() async {
    final resp = await _post('/signals/fetch/emergency-mock', {});
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // ── Resources (Extended) ────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> allocateResource(int incidentId, String resourceType, int quantity) async {
    final resp = await _post('/resources/allocate', {
      'incident_id': incidentId,
      'resource_type': resourceType,
      'quantity': quantity,
    });
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> updateResourceStatus(int resourceId, String status) async {
    final resp = await _post('/resources/update-status', {
      'resource_id': resourceId,
      'status': status,
    });
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // ── Verification (Extended) ─────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> confirmVerification(int reportId, String notes, bool isCredible) async {
    final resp = await _post('/verification/confirm', {
      'report_id': reportId,
      'notes': notes,
      'is_credible': isCredible,
    });
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> fetchReportDetail(int reportId) async {
    final resp = await _get('/verification/reports/$reportId');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> fetchReportStatus(int reportId) async {
    final resp = await _get('/verification/reports/$reportId/status');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // ── Logs (Extended) ─────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> fetchActionLogs(int actionId) async {
    final resp = await _get('/logs/actions/$actionId');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  Future<ApiResponse<Map<String, dynamic>>> fetchAgentLogs(String agentName) async {
    final resp = await _get('/logs/agents/$agentName');
    if (resp.isSuccess) {
      return ApiResponse.success(data: resp.data!);
    }
    return ApiResponse.error(message: resp.message, code: resp.code);
  }

  // ── Knowledge Base (Extended) ───────────────────────────────────────

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchKbTriggers() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/kb/triggers')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return ApiResponse.success(data: data.map((e) => e as Map<String, dynamic>).toList());
        }
      }
      return ApiResponse.error(message: 'Unexpected response', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchKbSourcePolicies() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/kb/source-policies')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return ApiResponse.success(data: data.map((e) => e as Map<String, dynamic>).toList());
        }
      }
      return ApiResponse.error(message: 'Unexpected response', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchKbSchemas() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/kb/schemas')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return ApiResponse.success(data: data.map((e) => e as Map<String, dynamic>).toList());
        }
      }
      return ApiResponse.error(message: 'Unexpected response', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchKbAppInteractions() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/kb/app-interactions')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return ApiResponse.success(data: data.map((e) => e as Map<String, dynamic>).toList());
        }
      }
      return ApiResponse.error(message: 'Unexpected response', code: response.statusCode);
    } catch (e) {
      return ApiResponse.error(message: e.toString(), code: 0);
    }
  }
}
