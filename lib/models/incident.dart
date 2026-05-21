class Incident {
  final int id;
  final String crisisType;
  final String title;
  final String severity;
  final String locationText;
  final double latitude;
  final double longitude;
  final double confidence;
  final String status;
  final double affectedRadiusM;
  final int expectedDurationMin;
  final String? forecastSummary;
  final String? precautionSummary;
  final String? reasoning;
  final DateTime firstDetectedAt;
  final DateTime updatedAt;

  Incident({
    required this.id,
    required this.crisisType,
    required this.title,
    required this.severity,
    required this.locationText,
    required this.latitude,
    required this.longitude,
    required this.confidence,
    required this.status,
    required this.affectedRadiusM,
    required this.expectedDurationMin,
    this.forecastSummary,
    this.precautionSummary,
    this.reasoning,
    required this.firstDetectedAt,
    required this.updatedAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    // Parse location sub-object
    double lat = 0.0;
    double lon = 0.0;
    if (json['location'] != null && json['location'] is Map) {
      lat = (json['location']['lat'] as num?)?.toDouble() ?? 0.0;
      lon = (json['location']['lon'] as num?)?.toDouble() ?? 0.0;
    }

    return Incident(
      id: (json['id'] as num?)?.toInt() ?? 0,
      crisisType: json['crisis_type'] as String? ?? json['crisisType'] as String? ?? 'other',
      title: json['title'] as String? ?? 'Incident Alert',
      severity: json['severity'] as String? ?? 'low',
      locationText: json['location_text'] as String? ?? json['locationText'] as String? ?? 'Unknown Location',
      latitude: lat,
      longitude: lon,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      status: json['status'] as String? ?? 'active',
      affectedRadiusM: (json['affected_radius_m'] as num?)?.toDouble() ?? (json['affectedRadiusM'] as num?)?.toDouble() ?? 100.0,
      expectedDurationMin: (json['expected_duration_min'] as num?)?.toInt() ?? (json['expectedDurationMin'] as num?)?.toInt() ?? 60,
      forecastSummary: json['forecast_summary'] as String? ?? json['forecastSummary'] as String?,
      precautionSummary: json['precaution_summary'] as String? ?? json['precautionSummary'] as String?,
      reasoning: json['reasoning'] as String?,
      firstDetectedAt: json['first_detected_at'] != null 
          ? DateTime.parse(json['first_detected_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'crisis_type': crisisType,
      'title': title,
      'severity': severity,
      'location_text': locationText,
      'location': {
        'lat': latitude,
        'lon': longitude,
      },
      'confidence': confidence,
      'status': status,
      'affected_radius_m': affectedRadiusM,
      'expected_duration_min': expectedDurationMin,
      'forecast_summary': forecastSummary,
      'precaution_summary': precautionSummary,
      'reasoning': reasoning,
      'first_detected_at': firstDetectedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
