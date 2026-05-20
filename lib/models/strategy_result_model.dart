class StrategyResultModel {
  final String strategyName;
  final double congestionReduction;
  final int casualtyEstimate;
  final double recoveryTimeHours;
  final double resourceUsagePercent;
  final String recommendation;

  StrategyResultModel({
    required this.strategyName,
    required this.congestionReduction,
    required this.casualtyEstimate,
    required this.recoveryTimeHours,
    required this.resourceUsagePercent,
    required this.recommendation,
  });

  factory StrategyResultModel.fromJson(Map<String, dynamic> json) {
    return StrategyResultModel(
      strategyName: json['strategyName'] as String? ?? '',
      congestionReduction:
          (json['congestionReduction'] as num?)?.toDouble() ?? 0.0,
      casualtyEstimate: json['casualtyEstimate'] as int? ?? 0,
      recoveryTimeHours:
          (json['recoveryTimeHours'] as num?)?.toDouble() ?? 0.0,
      resourceUsagePercent:
          (json['resourceUsagePercent'] as num?)?.toDouble() ?? 0.0,
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strategyName': strategyName,
      'congestionReduction': congestionReduction,
      'casualtyEstimate': casualtyEstimate,
      'recoveryTimeHours': recoveryTimeHours,
      'resourceUsagePercent': resourceUsagePercent,
      'recommendation': recommendation,
    };
  }

  @override
  String toString() {
    return 'StrategyResultModel(strategyName: $strategyName, congestionReduction: $congestionReduction%, '
        'casualtyEstimate: $casualtyEstimate, recoveryTimeHours: $recoveryTimeHours, '
        'resourceUsagePercent: $resourceUsagePercent%, recommendation: $recommendation)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StrategyResultModel &&
        other.strategyName == strategyName &&
        other.congestionReduction == congestionReduction &&
        other.casualtyEstimate == casualtyEstimate &&
        other.recoveryTimeHours == recoveryTimeHours &&
        other.resourceUsagePercent == resourceUsagePercent;
  }

  @override
  int get hashCode => Object.hash(
        strategyName,
        congestionReduction,
        casualtyEstimate,
        recoveryTimeHours,
        resourceUsagePercent,
      );
}
