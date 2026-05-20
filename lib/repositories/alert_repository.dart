import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crisis_link/models/alert_model.dart';
import 'package:crisis_link/services/firestore_service.dart';

/// Provider for AlertRepository
final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return AlertRepository(firestoreService);
});

/// Repository abstraction layer for alert operations.
/// Wraps FirestoreService to provide a clean API for alert data access.
class AlertRepository {
  final FirestoreService _firestoreService;

  AlertRepository(this._firestoreService);

  /// Get a real-time stream of all alerts
  Stream<List<AlertModel>> getStream() {
    return _firestoreService.getAlerts();
  }

  /// Create a new alert
  Future<void> create(AlertModel alert) {
    return _firestoreService.createAlert(alert);
  }

  /// Get only active alerts as a stream
  Stream<List<AlertModel>> getActiveAlerts() {
    return _firestoreService.getAlerts().map(
      (alerts) => alerts.where((a) => a.active).toList(),
    );
  }
}
