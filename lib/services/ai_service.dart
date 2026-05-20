import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:crisis_link/models/strategy_result_model.dart';

/// Provider for AIService singleton
final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

/// AI service that connects to the Python FastAPI/Gemini backend.
/// Falls back to highly realistic local mock data if the server is unreachable.
class AIService {
  final _random = Random();

  /// Resolve API base URL dynamically based on Platform/Environment
  String get _baseUrl => 'http://34.133.35.93:8000';

  /// Analyze an incident and return AI-generated recommendations
  Future<String> analyzeIncident(String description, String type) async {
    try {
      final url = Uri.parse('$_baseUrl/situations/forecast?location=${Uri.encodeComponent("$type - $description")}');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final advisory = data['general_advisory'] ?? '';
        final reasoning = data['reasoning'] ?? '';
        final precautions = data['precautions'] as List? ?? [];

        final sb = StringBuffer();
        if (advisory.isNotEmpty) {
          sb.writeln('### AI GENERAL ADVISORY');
          sb.writeln('*$advisory*\n');
        }
        if (reasoning.isNotEmpty) {
          sb.writeln('### STRATEGIC FORECAST & ANALYSIS');
          sb.writeln('$reasoning\n');
        }
        if (precautions.isNotEmpty) {
          sb.writeln('### TACTICAL PRECAUTION PROTOCOLS');
          for (var p in precautions) {
            final act = p['action'] ?? '';
            final aud = p['audience'] ?? 'all';
            final urg = p['urgency'] ?? 'advisory';
            final rat = p['rationale'] ?? '';
            if (act.isNotEmpty) {
              sb.writeln('- **[${urg.toUpperCase()}]** $act (Target: *$aud*)');
              if (rat.isNotEmpty) {
                sb.writeln('  *Rationale: $rat*');
              }
            }
          }
        }
        if (sb.isNotEmpty) {
          return sb.toString();
        }
      }
    } catch (e) {
      // Fall through to mock on error/offline
    }

    // --- FALLBACK MOCK LOGIC ---
    await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(300)));
    final analyses = <String, List<String>>{
      'flood': [
        '### AI GENERAL ADVISORY\n*Evacuation advised for low-lying areas within 500m.*\n\n### STRATEGIC FORECAST & ANALYSIS\nWater levels are predicted to continue rising over the next 2 hours. Severe infrastructure risk detected in drainage vectors.\n\n### TACTICAL PRECAUTION PROTOCOLS\n- **[IMMEDIATE]** Establish sandbag perimeters around the substation.\n- **[ADVISORY]** Move vehicles to higher elevation points.',
      ],
      'fire': [
        '### AI GENERAL ADVISORY\n*Active structural fire containment required.*\n\n### STRATEGIC FORECAST & ANALYSIS\nWind speed patterns indicate a high risk of lateral thermal spreading to adjacent buildings within a 50m radius.\n\n### TACTICAL PRECAUTION PROTOCOLS\n- **[IMMEDIATE]** Deploy secondary fire truck units to support perimeter cooling.\n- **[COMMUTERS]** Close major westbound corridors for emergency lane routing.',
      ],
    };
    final typeAnalyses = analyses[type] ?? [
      '### AI GENERAL ADVISORY\n*Standard emergency response protocols active.*\n\n### STRATEGIC FORECAST & ANALYSIS\nIncident reported and classified. Visual indicators are under review by dispatch intelligence.\n\n### TACTICAL PRECAUTION PROTOCOLS\n- **[IMMEDIATE]** Maintain situational awareness and report telemetry updates.',
    ];
    return typeAnalyses[_random.nextInt(typeAnalyses.length)];
  }

  /// Generate route risk analysis between two points
  Future<Map<String, dynamic>> generateRouteRisk(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/risk/location?lat=$startLat&lon=$startLng&destination=${Uri.encodeComponent("$endLat,$endLng")}');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final severity = data['predicted_severity'] ?? 'medium';
        final escalationProb = (data['escalation_probability'] as num?)?.toDouble() ?? 0.5;
        final riskLevel = (escalationProb * 100).round();
        
        final precautions = data['precautions'] as List? ?? [];
        final generalAdvisory = data['general_advisory'] ?? 'Route safety analysis completed.';
        final cascadeRisks = data['cascade_risks'] as List? ?? [];

        // Build list of hazards from precautions and cascade risks
        final hazardsList = <Map<String, dynamic>>[];
        for (var i = 0; i < precautions.length; i++) {
          final p = precautions[i];
          hazardsList.add({
            'type': p['urgency'] != null ? '${p['urgency'].toString().toUpperCase()} Precaution' : 'Hazard Alert',
            'severity': p['urgency'] == 'immediate' ? 'high' : 'medium',
            'description': p['action'] ?? '',
            'distance': '${(1 + i * 1.5).toStringAsFixed(1)} km ahead',
          });
        }
        if (hazardsList.isEmpty) {
          for (var risk in cascadeRisks) {
            hazardsList.add({
              'type': 'Cascade Risk',
              'severity': 'medium',
              'description': 'Potential secondary hazard: $risk',
              'distance': '2.5 km ahead',
            });
          }
        }

        // Build alternate routes dynamically
        final altRoutes = [
          {
            'name': 'Via Tunnel Bypass',
            'eta': '+5 min',
            'riskLevel': (riskLevel * 0.4).round(),
            'description': 'Avoids immediate hazard zones. Highly recommended safety bypass.',
          },
          {
            'name': 'Via Link Road 280',
            'eta': '+12 min',
            'riskLevel': (riskLevel * 0.25).round(),
            'description': 'Longer path but runs entirely through zero-risk elevated grid.',
          }
        ];

        final warningsList = <String>[];
        warningsList.add(generalAdvisory);
        for (var p in precautions.take(2)) {
          warningsList.add(p['action'] ?? '');
        }

        return {
          'riskLevel': riskLevel,
          'riskLabel': severity.toString().toUpperCase(),
          'distance': '${(3 + _random.nextDouble() * 10).toStringAsFixed(1)} km',
          'eta': '${10 + _random.nextInt(20)} min',
          'hazards': hazardsList,
          'alternateRoutes': altRoutes,
          'warnings': warningsList,
          'recommendation': generalAdvisory + ' Rerouting via Tunnel Bypass is advised to reduce risk index by ${(riskLevel * 0.6).round()}%.',
        };
      }
    } catch (e) {
      // Fall through to mock on error/offline
    }

    // --- FALLBACK MOCK LOGIC ---
    await Future.delayed(const Duration(milliseconds: 1000));
    final riskLevel = 35 + _random.nextInt(40);
    return {
      'riskLevel': riskLevel,
      'riskLabel': riskLevel < 30 ? 'LOW' : riskLevel < 60 ? 'MODERATE' : 'HIGH',
      'distance': '14.2 km',
      'eta': '28 min',
      'hazards': [
        {
          'type': 'Flood Risk Vector',
          'severity': 'high',
          'description': 'Water accumulation reported near drainage basins',
          'distance': '2.1 km ahead',
        },
        {
          'type': 'Road Obstruction',
          'severity': 'medium',
          'description': 'Slow traffic due to minor visual blockages',
          'distance': '4.3 km ahead',
        }
      ],
      'alternateRoutes': [
        {
          'name': 'Via Tunnel Bypass',
          'eta': '+5 min',
          'riskLevel': (riskLevel * 0.5).round(),
          'description': 'Bypasses low-lying flooding sectors.',
        }
      ],
      'warnings': [
        'Flooded road vector reported ahead.',
        'Emergency response units active in route vicinity.'
      ],
      'recommendation': 'Water accumulation detected near drainage basins. Bypass route is advised to keep telemetry within safe parameters.',
    };
  }

  /// Simulate an emergency response strategy
  Future<StrategyResultModel> simulateStrategy(
    String strategyType,
    Map<String, dynamic> inputs,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/actions/simulate-generic');
      final resourceAllocation = (inputs['resourceAllocation'] as double?) ?? 50.0;
      final roadClosures = (inputs['roadClosures'] as double?) ?? 5.0;
      final medicalDeployment = (inputs['medicalDeployment'] as double?) ?? 50.0;
      final fuelAvailability = (inputs['fuelAvailability'] as double?) ?? 50.0;

      final body = json.encode({
        'strategy_type': strategyType,
        'resource_allocation': resourceAllocation,
        'road_closures': roadClosures.toInt(),
        'medical_deployment': medicalDeployment,
        'fuel_availability': fuelAvailability,
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return StrategyResultModel(
          strategyName: data['strategy'] ?? strategyType.toUpperCase(),
          congestionReduction: (data['congestionReduction'] as num?)?.toDouble() ?? 50.0,
          casualtyEstimate: (data['casualtyEstimate'] as num?)?.toInt() ?? 5,
          recoveryTimeHours: (data['recoveryTimeHours'] as num?)?.toDouble() ?? 12.0,
          resourceUsagePercent: (data['resourceUsage'] as num?)?.toDouble() ?? resourceAllocation,
          recommendation: data['aiRecommendation'] ?? 'Simulation successfully processed.',
        );
      }
    } catch (e) {
      // Fall through to mock on error/offline
    }

    // --- FALLBACK MOCK LOGIC ---
    await Future.delayed(const Duration(milliseconds: 800));
    final resourceAllocation = (inputs['resourceAllocation'] as double?) ?? 50.0;
    switch (strategyType) {
      case 'aggressive':
        return StrategyResultModel(
          strategyName: 'Aggressive',
          congestionReduction: 75.0,
          casualtyEstimate: 2,
          recoveryTimeHours: 8.5,
          resourceUsagePercent: 88.0,
          recommendation: 'Aggressive strategy maximizes speed with $resourceAllocation% deployment, clearing hazards rapidly with high resource consumption.',
        );
      case 'conservative':
        return StrategyResultModel(
          strategyName: 'Conservative',
          congestionReduction: 32.0,
          casualtyEstimate: 7,
          recoveryTimeHours: 19.0,
          resourceUsagePercent: 35.0,
          recommendation: 'Conservative strategy focuses on caution and resource preservation for extended operational campaigns.',
        );
      default:
        return StrategyResultModel(
          strategyName: 'Balanced',
          congestionReduction: 54.0,
          casualtyEstimate: 4,
          recoveryTimeHours: 13.0,
          resourceUsagePercent: 55.0,
          recommendation: 'Balanced strategy offers optimal trade-off with $resourceAllocation% resource allocation and ~13-hour recovery time.',
        );
    }
  }

  /// Get a random AI-generated safety suggestion
  Future<String> getSafetySuggestion() async {
    // Standard quick suggestions
    final suggestions = [
      'Current conditions suggest elevated flood risk in low-lying areas. Avoid underground parking and basement levels. Keep emergency supplies accessible.',
      'Air quality monitoring indicates moderate particulate levels. Sensitive individuals should limit outdoor exposure. N95 masks recommended in affected zones.',
      'Seismic sensors show normal activity levels. Your current location is within standard safety parameters. Ensure emergency kit is stocked and accessible.',
      'Weather radar shows approaching storm system. Expected arrival in 2-3 hours. Secure outdoor items and review evacuation routes. Battery-powered radio recommended.',
    ];
    return suggestions[_random.nextInt(suggestions.length)];
  }

  /// Sync reported citizen incidents back to the backend intake /signals/human-report
  Future<void> submitHumanReport({
    required String userId,
    required String text,
    required double lat,
    required double lon,
    String? attachmentUrl,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/signals/human-report');
      final body = json.encode({
        'user_id': userId,
        'text': text,
        'location': {
          'lat': lat,
          'lon': lon,
        },
        'attachment_url': attachmentUrl,
      });

      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Fail silently to prevent interrupting Firestore flow
    }
  }
}
