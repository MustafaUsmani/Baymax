import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/api_response.dart';
import '../models/health.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final healthProvider = FutureProvider<ApiResponse<Health>>((ref) async {
  final service = ref.read(apiServiceProvider);
  return await service.fetchHealth();
});
