import 'package:json_annotation/json_annotation.dart';

part 'incident.g.dart';

@JsonSerializable()
class Incident {
  final int id;
  final String crisisType;
  final String severity;
  final String locationText;
  final String? forecastSummary;
  final String? precautionSummary;
  final double? affectedRadiusM;
  final int? expectedDurationMin;

  Incident({
    required this.id,
    required this.crisisType,
    required this.severity,
    required this.locationText,
    this.forecastSummary,
    this.precautionSummary,
    this.affectedRadiusM,
    this.expectedDurationMin,
  });

  factory Incident.fromJson(Map<String, dynamic> json) => _$IncidentFromJson(json);
  Map<String, dynamic> toJson() => _$IncidentToJson(this);
}
