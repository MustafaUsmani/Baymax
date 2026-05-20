import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart' as f_auth;

import 'package:crisis_link/theme/app_colors.dart';
import 'package:crisis_link/core/constants.dart';
import 'package:crisis_link/services/firestore_service.dart';
import 'package:crisis_link/services/location_service.dart';
import 'package:crisis_link/services/ai_service.dart';
import 'package:crisis_link/widgets/stat_card.dart';
import 'package:crisis_link/widgets/alert_card.dart';
import 'package:crisis_link/widgets/incident_bottom_sheet.dart';
import 'package:crisis_link/models/incident_model.dart';
import 'package:crisis_link/models/alert_model.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  GoogleMapController? _mapController;
  String _aiSuggestion = 'Analyzing regional threat indicators...';
  bool _loadingAi = true;

  @override
  void initState() {
    super.initState();
    _loadAiSuggestion();
  }

  Future<void> _loadAiSuggestion() async {
    setState(() => _loadingAi = true);
    try {
      final suggestion = await ref.read(aiServiceProvider).getSafetySuggestion();
      if (mounted) {
        setState(() {
          _aiSuggestion = suggestion;
          _loadingAi = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiSuggestion = 'Unable to fetch real-time intelligence. Proceed with standard caution.';
          _loadingAi = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(incidentsStreamProvider);
    final alertsAsync = ref.watch(alertsStreamProvider);
    final locationAsync = ref.watch(currentLocationProvider);
    final firebaseUser = f_auth.FirebaseAuth.instance.currentUser;
    final operatorName = (firebaseUser?.isAnonymous ?? false)
        ? 'Guest Responder'
        : (firebaseUser?.displayName ?? 'Operator');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- EOC Neon Command Banner ---
              _buildNeonCommandBanner(),

              // --- Main Scrollable Dashboard ---
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accentAmber,
                  backgroundColor: AppColors.secondarySurface,
                  onRefresh: () async {
                    _loadAiSuggestion();
                    // Refreshes providers if required
                    ref.invalidate(incidentsStreamProvider);
                    ref.invalidate(alertsStreamProvider);
                    ref.invalidate(currentLocationProvider);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Operator Greeting & Status ---
                        _buildOperatorGreeting(operatorName),
                        const SizedBox(height: 16),

                        // --- Dynamic Emergency Telemetry Panel ---
                        _buildTelemetryPanel(incidentsAsync, alertsAsync, locationAsync),
                        const SizedBox(height: 16),

                        // --- AI Tactical Suggestion Card ---
                        _buildAiSuggestionCard(),
                        const SizedBox(height: 20),

                        // --- Operations Action Quick Grid ---
                        _buildOperationsActionGrid(context),
                        const SizedBox(height: 20),

                        // --- Tactical Map Preview ---
                        _buildMapPreviewHeader(),
                        const SizedBox(height: 8),
                        _buildMapPreview(incidentsAsync, locationAsync),
                        const SizedBox(height: 20),

                        // --- Active Incidents & Alerts Stream ---
                        _buildRecentAlertsSection(alertsAsync),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildNeonCommandBanner() {
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emergencyRed.withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
               .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 600.ms),
              const SizedBox(width: 8),
              const Text(
                'SYSTEM OPERATIONS STATUS: ACTIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const Text(
            'SECURE CONNECTED',
            style: TextStyle(
              color: AppColors.successTeal,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorGreeting(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WELCOME BACK,',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.secondarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder, width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield, color: AppColors.accentAmber, size: 16),
              const SizedBox(width: 6),
              Text(
                'CRISIS RESPONSE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryPanel(
    AsyncValue<List<IncidentModel>> incidents,
    AsyncValue<List<AlertModel>> alerts,
    AsyncValue<dynamic> location, // positions
  ) {
    final incidentCount = incidents.valueOrNull?.length ?? 0;
    final alertCount = alerts.valueOrNull?.length ?? 0;
    
    String coordinateText = 'AQUIRING';
    if (location.valueOrNull != null) {
      final pos = location.valueOrNull;
      coordinateText = '${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 24) / 3;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: cardWidth,
              child: StatCard(
                label: 'INCIDENTS',
                value: incidents.isLoading ? '...' : '$incidentCount',
                icon: Icons.warning_rounded,
                color: AppColors.emergencyRed,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatCard(
                label: 'ACTIVE ALERTS',
                value: alerts.isLoading ? '...' : '$alertCount',
                icon: Icons.radar_rounded,
                color: AppColors.accentAmber,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: StatCard(
                label: 'GPS COORDINATES',
                value: coordinateText,
                icon: Icons.gps_fixed_rounded,
                color: AppColors.successTeal,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAiSuggestionCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.successTeal.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.successTeal.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _loadAiSuggestion,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successTeal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_outlined,
                    color: AppColors.successTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AI CO-PILOT ADVISORY',
                            style: TextStyle(
                              color: AppColors.successTeal,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 2,
                            ),
                          ),
                          if (_loadingAi)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.successTeal,
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.refresh,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _aiSuggestion,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperationsActionGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EMERGENCY COGNITIVE SUITE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildOperationActionCard(
                context,
                title: 'ROUTE SAFETY',
                subtitle: 'Hazard Intelligence',
                icon: Icons.navigation_rounded,
                color: AppColors.accentAmber,
                onTap: () => context.push('/safety-monitor'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOperationActionCard(
                context,
                title: 'TACTICAL RESPONSE',
                subtitle: 'Strategy Simulator',
                icon: Icons.analytics_rounded,
                color: AppColors.successTeal,
                onTap: () => context.push('/simulator'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOperationActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapPreviewHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'LIVE INCIDENT MAP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        TextButton.icon(
          onPressed: () {
            // Jump to the Map screen branch in StateShellRoute
            // Map Screen index is 1
            final shell = StatefulNavigationShell.of(context);
            shell.goBranch(1);
          },
          icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.accentAmber),
          label: const Text(
            'EXPAND MAP',
            style: TextStyle(
              color: AppColors.accentAmber,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapPreview(
    AsyncValue<List<IncidentModel>> incidentsAsync,
    AsyncValue<dynamic> locationAsync,
  ) {
    // Default location: San Francisco
    double lat = 37.7749;
    double lng = -122.4194;

    if (locationAsync.valueOrNull != null) {
      final pos = locationAsync.valueOrNull;
      lat = pos.latitude;
      lng = pos.longitude;
    }

    final markers = <Marker>{};

    incidentsAsync.whenData((incidents) {
      for (final incident in incidents) {
        double hue = BitmapDescriptor.hueCyan;
        if (incident.severity.toLowerCase() == 'medium') {
          hue = BitmapDescriptor.hueOrange;
        } else if (incident.severity.toLowerCase() == 'high') {
          hue = BitmapDescriptor.hueRed;
        } else if (incident.severity.toLowerCase() == 'critical') {
          hue = BitmapDescriptor.hueRed; // critical
        }

        markers.add(
          Marker(
            markerId: MarkerId(incident.id),
            position: LatLng(incident.latitude, incident.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(
              title: incident.type.toUpperCase(),
              snippet: incident.description,
            ),
            onTap: () {
              showIncidentBottomSheet(context, incident);
            },
          ),
        );
      }
    });

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(lat, lng),
                zoom: 12,
              ),
              style: kDarkMapStyleJson,
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: markers,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
            // Layer outline overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.accentAmber.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            // Floating recenter control
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: () {
                  if (_mapController != null && locationAsync.valueOrNull != null) {
                    final pos = locationAsync.valueOrNull;
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(pos.latitude, pos.longitude),
                        13,
                      ),
                    );
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Icon(
                    Icons.gps_fixed,
                    color: AppColors.accentAmber,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlertsSection(AsyncValue<List<AlertModel>> alertsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ACTIVE BROADCAST FEED',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            TextButton(
              onPressed: () {
                final shell = StatefulNavigationShell.of(context);
                shell.goBranch(3); // Alerts index is 3
              },
              child: const Text(
                'VIEW ALL',
                style: TextStyle(
                  color: AppColors.accentAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        alertsAsync.when(
          data: (alerts) {
            if (alerts.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No active emergency broadcasts at this time.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            // Show top 3 alerts
            final previewAlerts = alerts.take(3).toList();
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: previewAlerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final alert = previewAlerts[idx];
                return AlertCard(
                  alert: alert,
                  onTap: () {
                    final shell = StatefulNavigationShell.of(context);
                    shell.goBranch(3); // Navigate to AlertsScreen
                  },
                ).animate().fadeIn(duration: 400.ms, delay: (idx * 100).ms).slideX(begin: 0.1, end: 0);
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentAmber),
              ),
            ),
          ),
          error: (err, _) => Center(
            child: Text(
              'Failed to retrieve alerts: $err',
              style: const TextStyle(color: AppColors.emergencyRed, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
