class SimulationResult {
  final int id;
  final int incidentId;
  final int actionId;
  final Map<String, dynamic> beforeState;
  final Map<String, dynamic> afterState;
  final Map<String, dynamic> sideEffects;
  final double benefitScore;
  final double riskScore;
  final String? reasoning;
  final DateTime createdAt;

  SimulationResult({
    required this.id,
    required this.incidentId,
    required this.actionId,
    required this.beforeState,
    required this.afterState,
    required this.sideEffects,
    required this.benefitScore,
    required this.riskScore,
    this.reasoning,
    required this.createdAt,
  });

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      id: (json['id'] as num?)?.toInt() ?? 0,
      incidentId: (json['incident_id'] as num?)?.toInt() ?? 0,
      actionId: (json['action_id'] as num?)?.toInt() ?? 0,
      beforeState: json['before_state'] as Map<String, dynamic>? ?? const {},
      afterState: json['after_state'] as Map<String, dynamic>? ?? const {},
      sideEffects: json['side_effects'] as Map<String, dynamic>? ?? const {},
      benefitScore: (json['benefit_score'] as num?)?.toDouble() ?? 0.0,
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
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
      'action_id': actionId,
      'before_state': beforeState,
      'after_state': afterState,
      'side_effects': sideEffects,
      'benefit_score': benefitScore,
      'risk_score': riskScore,
      'reasoning': reasoning,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
