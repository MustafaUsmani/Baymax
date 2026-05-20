import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────────────────────
// App Meta
// ──────────────────────────────────────────────────────────────────────────────

const String kAppName = 'CrisisLink';
const String kAppTagline = 'Real-time Crisis Intelligence';
const String kAppVersion = '1.0.0';

// ──────────────────────────────────────────────────────────────────────────────
// Brand Colors (hex)
// ──────────────────────────────────────────────────────────────────────────────

const int kPrimaryBackgroundHex = 0xFF0D1B2A;
const int kSecondarySurfaceHex = 0xFF1A1A2E;
const int kAccentAmberHex = 0xFFF5A623;
const int kEmergencyRedHex = 0xFFE63946;
const int kSuccessTealHex = 0xFF2EC4B6;
const int kCardBackgroundHex = 0xFF16213E;
const int kCardBorderHex = 0xFF2A2A4A;
const int kTextSecondaryHex = 0xFFB0B0B0;

// ──────────────────────────────────────────────────────────────────────────────
// Firestore Collection Names
// ──────────────────────────────────────────────────────────────────────────────

const String kUsersCollection = 'users';
const String kIncidentsCollection = 'incidents';
const String kAlertsCollection = 'alerts';

// ──────────────────────────────────────────────────────────────────────────────
// Incident Type Enum
// ──────────────────────────────────────────────────────────────────────────────

enum IncidentType {
  flood('Flood'),
  fire('Fire'),
  accident('Accident'),
  landslide('Landslide'),
  riot('Riot'),
  medical('Medical'),
  infrastructure('Infrastructure'),
  weather('Weather'),
  other('Other');

  final String label;
  const IncidentType(this.label);

  /// Returns a human-friendly display name.
  String get displayName => label;

  /// Resolve an [IncidentType] from its [name] string, falling back to
  /// [IncidentType.other] when no match is found.
  static IncidentType fromString(String value) {
    return IncidentType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => IncidentType.other,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Severity Enum
// ──────────────────────────────────────────────────────────────────────────────

enum Severity {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  final String label;
  const Severity(this.label);

  String get displayName => label;

  static Severity fromString(String value) {
    return Severity.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => Severity.low,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Incident Status Enum
// ──────────────────────────────────────────────────────────────────────────────

enum IncidentStatus {
  active('Active'),
  resolved('Resolved'),
  investigating('Investigating');

  final String label;
  const IncidentStatus(this.label);

  String get displayName => label;

  static IncidentStatus fromString(String value) {
    return IncidentStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => IncidentStatus.active,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Severity → Color Helper
// ──────────────────────────────────────────────────────────────────────────────

Color getSeverityColor(Severity severity) {
  return switch (severity) {
    Severity.low => const Color(kSuccessTealHex),
    Severity.medium => const Color(kAccentAmberHex),
    Severity.high => const Color(kEmergencyRedHex),
    Severity.critical => const Color(kEmergencyRedHex),
  };
}

/// Lighter, translucent version useful for chip / badge backgrounds.
Color getSeverityBackgroundColor(Severity severity) {
  return getSeverityColor(severity).withValues(alpha: 0.15);
}

// ──────────────────────────────────────────────────────────────────────────────
// Incident Status → Color Helper
// ──────────────────────────────────────────────────────────────────────────────

Color getStatusColor(IncidentStatus status) {
  return switch (status) {
    IncidentStatus.active => const Color(kEmergencyRedHex),
    IncidentStatus.investigating => const Color(kAccentAmberHex),
    IncidentStatus.resolved => const Color(kSuccessTealHex),
  };
}

// ──────────────────────────────────────────────────────────────────────────────
// Incident Type → Icon Helper
// ──────────────────────────────────────────────────────────────────────────────

IconData getIncidentTypeIcon(IncidentType type) {
  return switch (type) {
    IncidentType.flood => Icons.water,
    IncidentType.fire => Icons.local_fire_department,
    IncidentType.accident => Icons.car_crash,
    IncidentType.landslide => Icons.landslide,
    IncidentType.riot => Icons.groups,
    IncidentType.medical => Icons.local_hospital,
    IncidentType.infrastructure => Icons.construction,
    IncidentType.weather => Icons.thunderstorm,
    IncidentType.other => Icons.warning_amber_rounded,
  };
}

/// Returns a colour tint associated with each incident type to help visually
/// distinguish markers / cards.
Color getIncidentTypeColor(IncidentType type) {
  return switch (type) {
    IncidentType.flood => const Color(0xFF42A5F5),
    IncidentType.fire => const Color(0xFFEF5350),
    IncidentType.accident => const Color(0xFFFFA726),
    IncidentType.landslide => const Color(0xFF8D6E63),
    IncidentType.riot => const Color(0xFFAB47BC),
    IncidentType.medical => const Color(0xFFEF5350),
    IncidentType.infrastructure => const Color(0xFF78909C),
    IncidentType.weather => const Color(0xFF26C6DA),
    IncidentType.other => const Color(0xFFBDBDBD),
  };
}

// ──────────────────────────────────────────────────────────────────────────────
// Dark Google Maps Style JSON
// ──────────────────────────────────────────────────────────────────────────────

const String kDarkMapStyleJson = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#0d1b2a" }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#8ec3b9" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#1a1a2e" }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#2a2a4a" }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "administrative.province",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#2a2a4a" }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#16213e" }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      { "color": "#0f2235" }
    ]
  },
  {
    "featureType": "poi",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#6f9ba5" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#0a2e28" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#3C7680" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      { "color": "#16213e" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#1a1a2e" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.icon",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#6f9ba5" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      { "color": "#1e3a5f" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#1a1a2e" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#b0b0b0" }
    ]
  },
  {
    "featureType": "transit",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#6f9ba5" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      { "color": "#080e1a" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#3d5c6e" }
    ]
  }
]
''';
