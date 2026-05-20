import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:crisis_link/theme/app_colors.dart';
import 'package:crisis_link/core/constants.dart';
import 'package:crisis_link/services/firestore_service.dart';
import 'package:crisis_link/services/location_service.dart';
import 'package:crisis_link/models/incident_model.dart';
import 'package:crisis_link/core/utils.dart';

class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  GoogleMapController? _mapController;
  
  // Filters
  IncidentType? _selectedType;
  Severity? _selectedSeverity;
  double _selectedDistance = 25.0; // km, maximum distance
  
  // Tactical Options
  bool _showHeatmap = false;
  bool _showHazardZones = true;
  bool _showTacticalRoute = true;

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(incidentsStreamProvider);
    final locationAsync = ref.watch(currentLocationProvider);

    // Acquire current user location coordinates, default to SF if unavailable
    double userLat = 37.7749;
    double userLng = -122.4194;
    if (locationAsync.valueOrNull != null) {
      final pos = locationAsync.valueOrNull!;
      userLat = pos.latitude;
      userLng = pos.longitude;
    }

    return Scaffold(
      body: Stack(
        children: [
          // --- Full Screen Google Map ---
          incidentsAsync.when(
            data: (incidents) {
              // Apply filters
              final filteredIncidents = incidents.where((incident) {
                // Type filter
                if (_selectedType != null &&
                    incident.type.toLowerCase() != _selectedType!.name) {
                  return false;
                }
                
                // Severity filter
                if (_selectedSeverity != null &&
                    incident.severity.toLowerCase() != _selectedSeverity!.name) {
                  return false;
                }

                // Distance filter
                final dist = calculateDistanceKm(
                  userLat,
                  userLng,
                  incident.latitude,
                  incident.longitude,
                );
                if (dist > _selectedDistance) {
                  return false;
                }

                return true;
              }).toList();

              // Generate markers
              final markers = _buildMarkers(filteredIncidents);
              
              // Generate circles (Hazard zones & Heatmap simulation)
              final circles = _buildCircles(filteredIncidents, userLat, userLng);

              // Generate tactical polyline route overlay
              final polylines = _buildPolylines(filteredIncidents, userLat, userLng);

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(userLat, userLng),
                  zoom: 12.5,
                ),
                style: kDarkMapStyleJson,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                markers: markers,
                circles: circles,
                polylines: polylines,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentAmber),
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Map initialization failed: $err',
                style: const TextStyle(color: AppColors.emergencyRed),
              ),
            ),
          ),

          // --- Top Floating Operations Bar & Filters ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: _buildFiltersPanel(),
          ),

          // --- Floating Operations Controllers (Right column) ---
          Positioned(
            right: 16,
            bottom: 30,
            child: _buildMapControls(userLat, userLng),
          ),

          // --- Distance Slider Floating Panel ---
          Positioned(
            left: 16,
            bottom: 30,
            child: _buildDistanceIndicator(),
          ),
        ],
      ),
    );
  }

  // --- Markers Creator ---
  Set<Marker> _buildMarkers(List<IncidentModel> incidents) {
    final markers = <Marker>{};

    for (final incident in incidents) {
      double hue = BitmapDescriptor.hueCyan; // default low
      if (incident.severity.toLowerCase() == 'medium') {
        hue = BitmapDescriptor.hueOrange;
      } else if (incident.severity.toLowerCase() == 'high') {
        hue = BitmapDescriptor.hueRed;
      } else if (incident.severity.toLowerCase() == 'critical') {
        hue = BitmapDescriptor.hueRed;
      }

      markers.add(
        Marker(
          markerId: MarkerId(incident.id),
          position: LatLng(incident.latitude, incident.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: '${incident.type.toUpperCase()} [${incident.severity.toUpperCase()}]',
            snippet: '${incident.description.substring(0, incident.description.length > 50 ? 50 : incident.description.length)}...',
          ),
          onTap: () {
            // Push full screen Incident Detail dossier view
            context.push('/incident/${incident.id}');
          },
        ),
      );
    }
    return markers;
  }

  // --- Circles Creator (Hazard & Heatmaps) ---
  Set<Circle> _buildCircles(List<IncidentModel> incidents, double userLat, double userLng) {
    final circles = <Circle>{};

    // User safety boundary circle (Cyan, subtle)
    circles.add(
      Circle(
        circleId: const CircleId('user_perimeter'),
        center: LatLng(userLat, userLng),
        radius: 1200, // 1.2km safety zone
        fillColor: AppColors.successTeal.withValues(alpha: 0.05),
        strokeColor: AppColors.successTeal.withValues(alpha: 0.2),
        strokeWidth: 1,
      ),
    );

    for (final incident in incidents) {
      if (_showHazardZones) {
        // Red critical threat circle around high/critical severity incidents
        if (incident.severity.toLowerCase() == 'critical' || incident.severity.toLowerCase() == 'high') {
          circles.add(
            Circle(
              circleId: CircleId('hazard_${incident.id}'),
              center: LatLng(incident.latitude, incident.longitude),
              radius: 500, // 500m danger circle
              fillColor: AppColors.emergencyRed.withValues(alpha: 0.12),
              strokeColor: AppColors.emergencyRed.withValues(alpha: 0.4),
              strokeWidth: 2,
            ),
          );
        }
      }

      if (_showHeatmap) {
        // Simulated heatmap circle overlays (Amber/Red glowing spheres)
        double radius = 800;
        Color heatColor = AppColors.accentAmber.withValues(alpha: 0.25);
        if (incident.severity.toLowerCase() == 'critical') {
          radius = 1200;
          heatColor = AppColors.emergencyRed.withValues(alpha: 0.35);
        }
        
        circles.add(
          Circle(
            circleId: CircleId('heat_${incident.id}'),
            center: LatLng(incident.latitude, incident.longitude),
            radius: radius,
            fillColor: heatColor,
            strokeColor: Colors.transparent,
            strokeWidth: 0,
          ),
        );
      }
    }

    return circles;
  }

  // --- Polyline Route Creator ---
  Set<Polyline> _buildPolylines(List<IncidentModel> incidents, double userLat, double userLng) {
    final polylines = <Polyline>{};

    if (_showTacticalRoute && incidents.isNotEmpty) {
      // Connect user location to the closest critical incident to simulate emergency dispatch path
      IncidentModel? closest;
      double minDist = 9999999.0;
      
      for (final inc in incidents) {
        final dist = calculateDistanceKm(userLat, userLng, inc.latitude, inc.longitude);
        if (dist < minDist) {
          minDist = dist;
          closest = inc;
        }
      }

      if (closest != null) {
        // Add a tactical polyline route from user to that closest incident
        final points = <LatLng>[
          LatLng(userLat, userLng),
          LatLng((userLat + closest.latitude) / 2 + 0.003, (userLng + closest.longitude) / 2 - 0.003), // curved waypoint
          LatLng(closest.latitude, closest.longitude),
        ];

        polylines.add(
          Polyline(
            polylineId: const PolylineId('tactical_evac_route'),
            points: points,
            color: AppColors.accentAmber,
            width: 4,
            geodesic: true,
            patterns: [PatternItem.dash(12), PatternItem.gap(8)],
          ),
        );
      }
    }

    return polylines;
  }

  // --- Filters Panel Widget ---
  Widget _buildFiltersPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.accentAmber, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'TACTICAL DISPATCH FILTERS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (_selectedType != null || _selectedSeverity != null || _selectedDistance != 25.0)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = null;
                      _selectedSeverity = null;
                      _selectedDistance = 25.0;
                    });
                  },
                  child: const Text(
                    'RESET',
                    style: TextStyle(
                      color: AppColors.emergencyRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Row of Filters dropdown/chips
          Row(
            children: [
              // Incident Type selector
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<IncidentType>(
                      value: _selectedType,
                      hint: const Text(
                        'Type: All',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      dropdownColor: AppColors.secondarySurface,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.accentAmber, size: 18),
                      items: IncidentType.values.map((IncidentType t) {
                        return DropdownMenuItem<IncidentType>(
                          value: t,
                          child: Text(
                            t.displayName,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (IncidentType? val) {
                        setState(() => _selectedType = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Severity selector
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Severity>(
                      value: _selectedSeverity,
                      hint: const Text(
                        'Severity: All',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      dropdownColor: AppColors.secondarySurface,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.accentAmber, size: 18),
                      items: Severity.values.map((Severity s) {
                        return DropdownMenuItem<Severity>(
                          value: s,
                          child: Text(
                            s.displayName,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (Severity? val) {
                        setState(() => _selectedSeverity = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Distance Slider Floating Indicator ---
  Widget _buildDistanceIndicator() {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RADIUS RANGE',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_selectedDistance.toStringAsFixed(0)} KM',
                style: const TextStyle(color: AppColors.accentAmber, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: AppColors.accentAmber,
              inactiveTrackColor: AppColors.cardBorder,
              thumbColor: AppColors.accentAmber,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              min: 5,
              max: 100,
              value: _selectedDistance,
              onChanged: (val) {
                setState(() => _selectedDistance = val);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Map controls (Right Column buttons) ---
  Widget _buildMapControls(double lat, double lng) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Heatmap Toggle button
        _buildFloatingMapButton(
          icon: _showHeatmap ? Icons.wb_sunny : Icons.wb_sunny_outlined,
          color: _showHeatmap ? AppColors.accentAmber : Colors.white,
          onTap: () {
            setState(() => _showHeatmap = !_showHeatmap);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _showHeatmap ? 'Tactical Heatmap Overlay Enabled' : 'Tactical Heatmap Overlay Disabled',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: AppColors.secondarySurface,
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        // Hazard Zones Toggle button
        _buildFloatingMapButton(
          icon: _showHazardZones ? Icons.dangerous : Icons.dangerous_outlined,
          color: _showHazardZones ? AppColors.emergencyRed : Colors.white,
          onTap: () {
            setState(() => _showHazardZones = !_showHazardZones);
          },
        ),
        const SizedBox(height: 10),

        // Route polyline Toggle button
        _buildFloatingMapButton(
          icon: _showTacticalRoute ? Icons.route : Icons.route_outlined,
          color: _showTacticalRoute ? AppColors.successTeal : Colors.white,
          onTap: () {
            setState(() => _showTacticalRoute = !_showTacticalRoute);
          },
        ),
        const SizedBox(height: 10),

        // Recenter button
        _buildFloatingMapButton(
          icon: Icons.my_location,
          color: AppColors.accentAmber,
          onTap: () {
            if (_mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(lat, lng),
                  13.5,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildFloatingMapButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.secondarySurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
    );
  }
}
