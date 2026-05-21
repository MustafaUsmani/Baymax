class Health {
  final String status;
  final Map<String, dynamic> services;

  Health({
    required this.status,
    this.services = const {},
  });

  factory Health.fromJson(Map<String, dynamic> json) {
    return Health(
      status: json['status'] as String? ?? 'healthy',
      services: json['services'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'services': services,
    };
  }
}
