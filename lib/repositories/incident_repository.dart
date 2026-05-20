import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crisis_link/models/incident_model.dart';
import 'package:crisis_link/services/firestore_service.dart';

/// Provider for IncidentRepository
final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return IncidentRepository(firestoreService);
});

/// Repository abstraction layer for incident operations.
/// Wraps FirestoreService to provide a clean API for incident data access.
class IncidentRepository {
  final FirestoreService _firestoreService;

  IncidentRepository(this._firestoreService);

  /// Get a real-time stream of all incidents
  Stream<List<IncidentModel>> getStream() {
    return _firestoreService.getIncidents();
  }

  /// Get a single incident by ID
  Future<IncidentModel?> getById(String id) {
    return _firestoreService.getIncidentById(id);
  }

  /// Create a new incident
  Future<void> create(IncidentModel incident) {
    return _firestoreService.createIncident(incident);
  }

  /// Update an existing incident
  Future<void> update(IncidentModel incident) {
    return _firestoreService.updateIncident(incident);
  }

  /// Delete an incident by ID
  Future<void> delete(String id) {
    return _firestoreService.deleteIncident(id);
  }
}
