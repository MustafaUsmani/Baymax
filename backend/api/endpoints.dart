// lib/app/api/endpoints.dart
import 'package:crisis_link/core/constants.dart';

/// Centralized definition of backend API endpoints.
/// Uses the base URL defined in [kApiBaseUrl] from constants.
class ApiEndpoints {
  static const String base = kApiBaseUrl;

  // Health & readiness
  static String health() => '$base/';
  static String readiness() => '$base/ready';

  // Incidents
  static String incidents({int limit = 100, String? status, String? type}) {
    final params = <String, String>{'limit': limit.toString()};
    if (status != null) params['status'] = status;
    if (type != null) params['type'] = type;
    final query = Uri(queryParameters: params).query;
    return '$base/incidents${query.isNotEmpty ? '?$query' : ''}';
  }

  static String incidentDetail(String id) => '$base/incidents/$id';

  static String nearbyIncidents(double lat, double lng, {int radiusKm = 5}) {
    final params = {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'radius_km': radiusKm.toString(),
    };
    final query = Uri(queryParameters: params).query;
    return '$base/incidents/nearby?$query';
  }

  // Situations
  static String currentSituations() => '$base/situations/current';

  // Alerts (if backend provides an alerts endpoint)
  static String alerts() => '$base/alerts';

  // Human report signal
  static String humanReport() => '$base/signals/human-report';
}
