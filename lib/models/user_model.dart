import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;
  final Map<String, dynamic>? lastKnownLocation;
  final List<String> subscriptions;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.lastKnownLocation,
    this.subscriptions = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
      lastKnownLocation: json['lastKnownLocation'] as Map<String, dynamic>?,
      subscriptions: json['subscriptions'] != null
          ? List<String>.from(json['subscriptions'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastKnownLocation': lastKnownLocation,
      'subscriptions': subscriptions,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    DateTime? createdAt,
    Map<String, dynamic>? lastKnownLocation,
    List<String>? subscriptions,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      subscriptions: subscriptions ?? this.subscriptions,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
