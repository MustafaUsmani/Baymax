class ActionModel {
  final int id;
  final int incidentId;
  final String actionType;
  final String strategyName;
  final Map<String, dynamic> parameters;
  final String status;
  final Map<String, dynamic> expectedEffect;
  final Map<String, dynamic>? actualEffect;
  final String? reasoning;
  final DateTime createdAt;

  ActionModel({
    required this.id,
    required this.incidentId,
    required this.actionType,
    required this.strategyName,
    required this.parameters,
    required this.status,
    required this.expectedEffect,
    this.actualEffect,
    this.reasoning,
    required this.createdAt,
  });

  factory ActionModel.fromJson(Map<String, dynamic> json) {
    return ActionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      incidentId: (json['incident_id'] as num?)?.toInt() ?? 0,
      actionType: json['action_type'] as String? ?? '',
      strategyName: json['strategy_name'] as String? ?? '',
      parameters: json['parameters'] as Map<String, dynamic>? ?? const {},
      status: json['status'] as String? ?? 'pending',
      expectedEffect: json['expected_effect'] as Map<String, dynamic>? ?? const {},
      actualEffect: json['actual_effect'] as Map<String, dynamic>?,
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
      'action_type': actionType,
      'strategy_name': strategyName,
      'parameters': parameters,
      'status': status,
      'expected_effect': expectedEffect,
      'actual_effect': actualEffect,
      'reasoning': reasoning,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
