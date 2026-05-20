import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert_model.dart';
import '../models/incident_model.dart';
import '../models/user_model.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(firestore: FirebaseFirestore.instance);
});

final incidentsStreamProvider = StreamProvider<List<IncidentModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getIncidents();
});

final alertsStreamProvider = StreamProvider<List<AlertModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getAlerts();
});

class FirestoreService {
  final FirebaseFirestore _firestore;

  static const String _incidentsCollection = 'incidents';
  static const String _alertsCollection = 'alerts';
  static const String _usersCollection = 'users';

  FirestoreService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  // ---------------------------------------------------------------------------
  // Incidents
  // ---------------------------------------------------------------------------

  Future<void> createIncident(IncidentModel incident) async {
    try {
      final docRef =
          _firestore.collection(_incidentsCollection).doc(incident.id);
      await docRef.set(incident.toJson());
    } catch (e) {
      throw FirestoreServiceException(
        code: 'create-incident-failed',
        message: 'Failed to create incident: $e',
      );
    }
  }

  Stream<List<IncidentModel>> getIncidents() {
    return _firestore
        .collection(_incidentsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return IncidentModel.fromJson(data);
      }).toList();
    });
  }

  Future<IncidentModel?> getIncidentById(String id) async {
    try {
      final doc =
          await _firestore.collection(_incidentsCollection).doc(id).get();
      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      data['id'] = doc.id;
      return IncidentModel.fromJson(data);
    } catch (e) {
      throw FirestoreServiceException(
        code: 'get-incident-failed',
        message: 'Failed to get incident: $e',
      );
    }
  }

  Future<void> updateIncident(IncidentModel incident) async {
    try {
      await _firestore
          .collection(_incidentsCollection)
          .doc(incident.id)
          .update(incident.toJson());
    } catch (e) {
      throw FirestoreServiceException(
        code: 'update-incident-failed',
        message: 'Failed to update incident: $e',
      );
    }
  }

  Future<void> deleteIncident(String id) async {
    try {
      await _firestore.collection(_incidentsCollection).doc(id).delete();
    } catch (e) {
      throw FirestoreServiceException(
        code: 'delete-incident-failed',
        message: 'Failed to delete incident: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Alerts
  // ---------------------------------------------------------------------------

  Stream<List<AlertModel>> getAlerts() {
    return _firestore
        .collection(_alertsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return AlertModel.fromJson(data);
          })
          .where((alert) => alert.active)
          .toList();
    });
  }

  Future<void> createAlert(AlertModel alert) async {
    try {
      final docRef = _firestore.collection(_alertsCollection).doc(alert.id);
      await docRef.set(alert.toJson());
    } catch (e) {
      throw FirestoreServiceException(
        code: 'create-alert-failed',
        message: 'Failed to create alert: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      data['id'] = doc.id;
      return UserModel.fromJson(data);
    } catch (e) {
      throw FirestoreServiceException(
        code: 'get-user-failed',
        message: 'Failed to get user profile: $e',
      );
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.id)
          .update(user.toJson());
    } catch (e) {
      throw FirestoreServiceException(
        code: 'update-user-failed',
        message: 'Failed to update user profile: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Seed Demo Data
  // ---------------------------------------------------------------------------

  Future<void> seedDemoData() async {
    try {
      // Check if incidents collection already has data
      final incidentsSnapshot = await _firestore
          .collection(_incidentsCollection)
          .limit(1)
          .get();

      if (incidentsSnapshot.docs.isEmpty) {
        await _seedDemoIncidents();
      }

      // Check if alerts collection already has data
      final alertsSnapshot = await _firestore
          .collection(_alertsCollection)
          .limit(1)
          .get();

      if (alertsSnapshot.docs.isEmpty) {
        await _seedDemoAlerts();
      }
    } catch (e) {
      throw FirestoreServiceException(
        code: 'seed-failed',
        message: 'Failed to seed demo data: $e',
      );
    }
  }

  Future<void> _seedDemoIncidents() async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final demoIncidents = [
      IncidentModel(
        id: 'demo_incident_001',
        userId: 'system',
        type: 'flood',
        description:
            'Severe flash flooding reported along the Embarcadero waterfront. '
            'Multiple streets submerged with water levels reaching 2 feet. '
            'Storm drains overwhelmed due to heavy rainfall. '
            'Several vehicles stranded and pedestrian pathways impassable.',
        severity: 'critical',
        latitude: 37.7935,
        longitude: -122.3930,
        imagesBase64: [],
        createdAt: now.subtract(const Duration(hours: 2)),
        status: 'active',
      ),
      IncidentModel(
        id: 'demo_incident_002',
        userId: 'system',
        type: 'fire',
        description:
            'Structure fire reported at a three-story residential building '
            'in the Mission District. Fire department dispatched with 4 units. '
            'Evacuation of adjacent buildings in progress. '
            'Cause suspected to be electrical fault on the second floor.',
        severity: 'high',
        latitude: 37.7599,
        longitude: -122.4148,
        imagesBase64: [],
        createdAt: now.subtract(const Duration(hours: 5)),
        status: 'investigating',
      ),
      IncidentModel(
        id: 'demo_incident_003',
        userId: 'system',
        type: 'accident',
        description:
            'Multi-vehicle collision on the Bay Bridge westbound lanes. '
            'At least 6 vehicles involved including a commercial truck. '
            'Two lanes blocked, causing significant traffic backup. '
            'Emergency medical services on scene treating minor injuries.',
        severity: 'medium',
        latitude: 37.7983,
        longitude: -122.3778,
        imagesBase64: [],
        createdAt: now.subtract(const Duration(hours: 8)),
        status: 'active',
      ),
      IncidentModel(
        id: 'demo_incident_004',
        userId: 'system',
        type: 'infrastructure',
        description:
            'Major water main break at the intersection of Market and 5th Street. '
            'Water pressure loss reported in surrounding blocks. '
            'Road surface compromised with visible sinkholes forming. '
            'Public works crews deployed for emergency repairs.',
        severity: 'high',
        latitude: 37.7840,
        longitude: -122.4075,
        imagesBase64: [],
        createdAt: now.subtract(const Duration(hours: 12)),
        status: 'investigating',
      ),
      IncidentModel(
        id: 'demo_incident_005',
        userId: 'system',
        type: 'medical',
        description:
            'Mass casualty incident reported at Fisherman\'s Wharf area. '
            'Suspected food contamination at a popular seafood restaurant. '
            'Approximately 15 individuals showing symptoms of food poisoning. '
            'Health department notified and investigation underway.',
        severity: 'medium',
        latitude: 37.8080,
        longitude: -122.4177,
        imagesBase64: [],
        createdAt: now.subtract(const Duration(hours: 1)),
        status: 'active',
      ),
    ];

    for (final incident in demoIncidents) {
      final docRef =
          _firestore.collection(_incidentsCollection).doc(incident.id);
      batch.set(docRef, incident.toJson());
    }

    await batch.commit();
  }

  Future<void> _seedDemoAlerts() async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final demoAlerts = [
      AlertModel(
        id: 'demo_alert_001',
        title: 'Flash Flood Warning',
        description:
            'The National Weather Service has issued a Flash Flood Warning '
            'for San Francisco and the surrounding Bay Area. '
            'Heavy rainfall expected to continue for the next 6 hours. '
            'Residents in low-lying areas should prepare for potential evacuation.',
        type: 'weather',
        affectedArea: 'San Francisco Bay Area — Downtown, Embarcadero, SoMa',
        severity: 'critical',
        createdAt: now.subtract(const Duration(hours: 1)),
        active: true,
      ),
      AlertModel(
        id: 'demo_alert_002',
        title: 'Earthquake Advisory',
        description:
            'A 3.8 magnitude earthquake was recorded 12 miles southeast of San Francisco. '
            'No tsunami warning issued. Aftershocks are possible over the next 48 hours. '
            'Inspect buildings for structural damage and report any findings to 311.',
        type: 'earthquake',
        affectedArea: 'Greater San Francisco Metropolitan Area',
        severity: 'high',
        createdAt: now.subtract(const Duration(hours: 4)),
        active: true,
      ),
      AlertModel(
        id: 'demo_alert_003',
        title: 'Air Quality Alert',
        description:
            'Air quality index has reached unhealthy levels due to wildfire smoke '
            'drifting from the North Bay region. AQI currently at 185. '
            'Residents with respiratory conditions should remain indoors. '
            'N95 masks recommended for essential outdoor activities.',
        type: 'environmental',
        affectedArea: 'San Francisco, Marin County, Contra Costa County',
        severity: 'medium',
        createdAt: now.subtract(const Duration(hours: 6)),
        active: true,
      ),
      AlertModel(
        id: 'demo_alert_004',
        title: 'Traffic Disruption — Bay Bridge',
        description:
            'Westbound lanes of the Bay Bridge are partially closed due to a '
            'multi-vehicle accident. Expect delays of 45-60 minutes. '
            'Consider alternate routes via the Golden Gate Bridge or BART. '
            'Estimated clearance time is 4:00 PM.',
        type: 'traffic',
        affectedArea: 'Bay Bridge, I-80 Westbound corridor',
        severity: 'low',
        createdAt: now.subtract(const Duration(hours: 8)),
        active: true,
      ),
      AlertModel(
        id: 'demo_alert_005',
        title: 'Public Safety — Power Outage',
        description:
            'PG&E reports a widespread power outage affecting approximately '
            '12,000 customers in the Sunset and Richmond districts. '
            'Crews are working to restore power. Estimated restoration time '
            'is 10:00 PM tonight. Avoid downed power lines and report them to 911.',
        type: 'infrastructure',
        affectedArea: 'Sunset District, Richmond District, Golden Gate Park area',
        severity: 'medium',
        createdAt: now.subtract(const Duration(hours: 3)),
        active: true,
      ),
    ];

    for (final alert in demoAlerts) {
      final docRef = _firestore.collection(_alertsCollection).doc(alert.id);
      batch.set(docRef, alert.toJson());
    }

    await batch.commit();
  }
}

class FirestoreServiceException implements Exception {
  final String code;
  final String message;

  FirestoreServiceException({
    required this.code,
    required this.message,
  });

  @override
  String toString() =>
      'FirestoreServiceException(code: $code, message: $message)';
}
