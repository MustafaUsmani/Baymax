import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;
  final String title;
  final String description;
  final String type;
  final String affectedArea;
  final String severity;
  final DateTime createdAt;
  final bool active;

  AlertModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.affectedArea,
    required this.severity,
    required this.createdAt,
    this.active = true,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? '',
      affectedArea: json['affectedArea'] as String? ?? '',
      severity: json['severity'] as String? ?? 'low',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'affectedArea': affectedArea,
      'severity': severity,
      'createdAt': Timestamp.fromDate(createdAt),
      'active': active,
    };
  }

  AlertModel copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? affectedArea,
    String? severity,
    DateTime? createdAt,
    bool? active,
  }) {
    return AlertModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      affectedArea: affectedArea ?? this.affectedArea,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      active: active ?? this.active,
    );
  }

  @override
  String toString() {
    return 'AlertModel(id: $id, title: $title, severity: $severity, active: $active)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AlertModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
