import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import 'package:crisis_link/theme/app_colors.dart';
import 'package:crisis_link/core/constants.dart';
import 'package:crisis_link/services/firestore_service.dart';
import 'package:crisis_link/services/ai_service.dart';
import 'package:crisis_link/models/incident_model.dart';
import 'package:crisis_link/widgets/severity_chip.dart';
import 'package:crisis_link/widgets/shimmer_loading.dart';

class IncidentDetailScreen extends ConsumerStatefulWidget {
  final String incidentId;

  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  ConsumerState<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends ConsumerState<IncidentDetailScreen> {
  String _aiAdvice = 'Consulting strategic cognitive intelligence database...';
  bool _loadingAi = true;

  @override
  void initState() {
    super.initState();
    _fetchAiAdvice();
  }

  Future<void> _fetchAiAdvice() async {
    setState(() => _loadingAi = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final incident = await firestoreService.getIncidentById(widget.incidentId);
      if (incident != null && mounted) {
        final advice = await ref.read(aiServiceProvider).analyzeIncident(
              incident.description,
              incident.type,
            );
        setState(() {
          _aiAdvice = advice;
          _loadingAi = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiAdvice = 'Decision intelligence failed to initialize. Rely on field manuals.';
          _loadingAi = false;
        });
      }
    }
  }

  Future<void> _updateStatus(IncidentModel incident, IncidentStatus status) async {
    try {
      final updated = incident.copyWith(status: status.name);
      await ref.read(firestoreServiceProvider).updateIncident(updated);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'INCIDENT TRANSMISSION UPDATED: STATUS IS NOW ${status.displayName.toUpperCase()}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.successTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.emergencyRed,
          ),
        );
      }
    }
  }

  void _shareIncident(IncidentModel incident) {
    // Simulate share dialog to avoid third party package compile errors
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondarySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.share, color: AppColors.accentAmber),
            const SizedBox(width: 10),
            const Text(
              'SHARE CRISIS DOSSIER',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Incident broadcast data package formulated:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                'CRISISLINK BROADCAST FEED\n'
                'Type: ${incident.type.toUpperCase()}\n'
                'Severity: ${incident.severity.toUpperCase()}\n'
                'Location: ${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}\n'
                'Brief: ${incident.description}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('COPY TELEMETRY', style: TextStyle(color: AppColors.accentAmber)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stream incident directly from firestore to make details reactive
    final incidentsStream = ref.watch(incidentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CRISIS INTELLIGENCE DOSSIER',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: incidentsStream.when(
          data: (incidents) {
            // Find current incident
            final incident = incidents.firstWhere(
              (e) => e.id == widget.incidentId,
              orElse: () => IncidentModel(
                id: widget.incidentId,
                userId: 'unknown',
                type: 'other',
                description: 'Record not found in the operations grid database.',
                severity: 'low',
                latitude: 37.7749,
                longitude: -122.4194,
                imagesBase64: [],
                createdAt: DateTime.now(),
                status: 'resolved',
              ),
            );

            if (incident.userId == 'unknown') {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: AppColors.emergencyRed),
                      const SizedBox(height: 16),
                      Text(
                        'DOSSIER OFFLINE',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The requested incident record was not found or has been purged.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Base64 Photographic Evidence Grid ---
                  _buildEvidenceCarousel(incident),
                  const SizedBox(height: 16),

                  // --- Header Meta & Badges ---
                  _buildDossierHeader(incident),
                  const SizedBox(height: 16),

                  // --- Operational Map Locking ---
                  _buildMiniMapLock(incident),
                  const SizedBox(height: 16),

                  // --- Description field ---
                  _buildDescriptionCard(incident),
                  const SizedBox(height: 16),

                  // --- AI Response / Recommendation ---
                  _buildAiCognitiveAnalysisCard(),
                  const SizedBox(height: 16),

                  // --- Tactical Command Status Controller ---
                  _buildResponderCommandConsole(incident),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: ShimmerCard(height: 400),
          ),
          error: (err, _) => Center(
            child: Text(
              'Tactical connection lost: $err',
              style: const TextStyle(color: AppColors.emergencyRed),
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildEvidenceCarousel(IncidentModel incident) {
    if (incident.imagesBase64.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.secondarySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 48),
            SizedBox(height: 10),
            Text(
              'NO PHOTO EVIDENCE ATTACHED',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: PageView.builder(
          itemCount: incident.imagesBase64.length,
          itemBuilder: (context, idx) {
            try {
              final bytes = base64Decode(incident.imagesBase64[idx]);
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _errorPlaceholder(),
              );
            } catch (_) {
              return _errorPlaceholder();
            }
          },
        ),
      ),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: AppColors.secondarySurface,
      child: const Icon(Icons.error, color: AppColors.emergencyRed, size: 48),
    );
  }

  Widget _buildDossierHeader(IncidentModel incident) {
    final statusColor = getStatusColor(IncidentStatus.fromString(incident.status));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  incident.status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
              const Spacer(),
              SeverityChip(severity: incident.severity),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${incident.type.toUpperCase()} DISPATCH',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_pin, color: AppColors.accentAmber, size: 14),
              const SizedBox(width: 6),
              Text(
                'REPORTER: ${incident.userId.substring(0, incident.userId.length > 10 ? 10 : incident.userId.length).toUpperCase()}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const Icon(Icons.access_time_filled, color: AppColors.textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(
                DateFormat('MM/dd HH:mm').format(incident.createdAt),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMapLock(IncidentModel incident) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(incident.latitude, incident.longitude),
                zoom: 14.5,
              ),
              style: kDarkMapStyleJson,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              markers: {
                Marker(
                  markerId: MarkerId(incident.id),
                  position: LatLng(incident.latitude, incident.longitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    incident.severity == 'critical' || incident.severity == 'high'
                        ? BitmapDescriptor.hueRed
                        : BitmapDescriptor.hueOrange,
                  ),
                ),
              },
              circles: {
                Circle(
                  circleId: CircleId('danger_${incident.id}'),
                  center: LatLng(incident.latitude, incident.longitude),
                  radius: 350,
                  fillColor: AppColors.emergencyRed.withValues(alpha: 0.1),
                  strokeColor: AppColors.emergencyRed.withValues(alpha: 0.3),
                  strokeWidth: 2,
                ),
              },
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${incident.latitude.toStringAsFixed(4)}°, ${incident.longitude.toStringAsFixed(4)}°',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(IncidentModel incident) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SITUATIONAL DESCRIPTION BRIEF',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5),
              ),
              GestureDetector(
                onTap: () => _shareIncident(incident),
                child: const Icon(Icons.share, color: AppColors.accentAmber, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            incident.description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCognitiveAnalysisCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.successTeal.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: AppColors.successTeal, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'AI STRATEGIC RECONNAISSANCE',
                  style: TextStyle(
                    color: AppColors.successTeal,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                if (_loadingAi)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.successTeal),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _aiAdvice,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponderCommandConsole(IncidentModel incident) {
    return Card(
      color: AppColors.secondarySurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'TACTICAL FIELD RESPONDER CONSOLE',
              style: TextStyle(
                color: AppColors.accentAmber,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Authorized operations team status synchronization panel.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 14),
            Row(
              children: IncidentStatus.values.map((status) {
                final isCurrent = incident.status.toLowerCase() == status.name;
                final col = getStatusColor(status);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _updateStatus(incident, status),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isCurrent ? col.withValues(alpha: 0.15) : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrent ? col : AppColors.cardBorder,
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        status.displayName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isCurrent ? col : AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
