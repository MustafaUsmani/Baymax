class Forecast {
  final int id;
  final int incidentId;
  final String forecastType;
  final String predictedSeverity;
  final double predictedSpread;
  final int predictedDuration;
  final String uncertaintyBand;
  final List<String> precautionRecommendations;
  final String? reasoning;
  final DateTime createdAt;

  Forecast({
    required this.id,
    required this.incidentId,
    required this.forecastType,
    required this.predictedSeverity,
    required this.predictedSpread,
    required this.predictedDuration,
    required this.uncertaintyBand,
    required this.precautionRecommendations,
    this.reasoning,
    required this.createdAt,
  });

  factory Forecast.fromJson(Map<String, dynamic> json) {
    return Forecast(
      id: (json['id'] as num?)?.toInt() ?? 0,
      incidentId: (json['incident_id'] as num?)?.toInt() ?? 0,
      forecastType: json['forecast_type'] as String? ?? '',
      predictedSeverity: json['predicted_severity'] as String? ?? 'low',
      predictedSpread: (json['predicted_spread'] as num?)?.toDouble() ?? 0.0,
      predictedDuration: (json['predicted_duration'] as num?)?.toInt() ?? 0,
      uncertaintyBand: json['uncertainty_band'] as String? ?? 'medium',
      precautionRecommendations: json['precaution_recommendations'] != null 
          ? List<String>.from(json['precaution_recommendations'] as List)
          : const [],
      reasoning: json['reasoning'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_id': incidentId,
      'forecast_type': forecastType,
      'predicted_severity': predictedSeverity,
      'predicted_spread': predictedSpread,
      'predicted_duration': predictedDuration,
      'uncertainty_band': uncertaintyBand,
      'precaution_recommendations': precautionRecommendations,
      'reasoning': reasoning,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
