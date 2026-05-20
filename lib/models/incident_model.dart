import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crisis_link/core/constants.dart';

enum IncidentSeverity {
  low,
  medium,
  high,
  critical;

  String get displayName {
    switch (this) {
      case IncidentSeverity.low:
        return 'Low';
      case IncidentSeverity.medium:
        return 'Medium';
      case IncidentSeverity.high:
        return 'High';
      case IncidentSeverity.critical:
        return 'Critical';
    }
  }

  static IncidentSeverity fromString(String value) {
    return IncidentSeverity.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => IncidentSeverity.low,
    );
  }
}

class IncidentModel {
  final String id;
  final String userId;
  final String type;
  final String description;
  final String severity;
  final double latitude;
  final double longitude;
  final List<String> imagesBase64;
  final DateTime createdAt;
  final String status;

  IncidentModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.severity,
    required this.latitude,
    required this.longitude,
    this.imagesBase64 = const [],
    required this.createdAt,
    this.status = 'active',
  });

  IncidentType get incidentType => IncidentType.fromString(type);
  IncidentSeverity get incidentSeverity => IncidentSeverity.fromString(severity);
  IncidentStatus get incidentStatus => IncidentStatus.fromString(status);

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      type: json['type'] as String? ?? 'other',
      description: json['description'] as String? ?? '',
      severity: json['severity'] as String? ?? 'low',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      imagesBase64: json['imagesBase64'] != null
          ? List<String>.from(json['imagesBase64'] as List)
          : [],
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'description': description,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      'imagesBase64': imagesBase64,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  IncidentModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? description,
    String? severity,
    double? latitude,
    double? longitude,
    List<String>? imagesBase64,
    DateTime? createdAt,
    String? status,
  }) {
    return IncidentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imagesBase64: imagesBase64 ?? this.imagesBase64,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'IncidentModel(id: $id, type: $type, severity: $severity, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IncidentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
