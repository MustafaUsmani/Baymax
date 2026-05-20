import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:crisis_link/services/ai_service.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF0D1B2A);
const Color _kSurface = Color(0xFF1A1A2E);
const Color _kAccentAmber = Color(0xFFF5A623);
const Color _kEmergencyRed = Color(0xFFE63946);
const Color _kSuccessTeal = Color(0xFF2EC4B6);
const Color _kCardBg = Color(0xFF16213E);
const Color _kFieldBg = Color(0xFF0F3460);

// ─── AI Service Mock ──────────────────────────────────────────────────────────
class _RouteRiskResult {
  final int riskScore;
  final String riskLabel;
  final String eta;
  final String distance;
  final String aiRecommendation;
  final List<_HazardZone> hazards;
  final List<_RiskFactor> riskFactors;
  final List<_AlternativeRoute> alternativeRoutes;

  _RouteRiskResult({
    required this.riskScore,
    required this.riskLabel,
    required this.eta,
    required this.distance,
    required this.aiRecommendation,
    required this.hazards,
    required this.riskFactors,
    required this.alternativeRoutes,
  });
}

class _HazardZone {
  final String name;
  final String type;
  final String severity;
  final IconData icon;

  _HazardZone({
    required this.name,
    required this.type,
    required this.severity,
    required this.icon,
  });
}

class _RiskFactor {
  final String factor;
  final double weight;

  _RiskFactor({required this.factor, required this.weight});
}

class _AlternativeRoute {
  final String name;
  final String eta;
  final String distance;
  final int riskScore;

  _AlternativeRoute({
    required this.name,
    required this.eta,
    required this.distance,
    required this.riskScore,
  });
}


// ─── Screen ───────────────────────────────────────────────────────────────────
class SafetyMonitorScreen extends ConsumerStatefulWidget {
  const SafetyMonitorScreen({super.key});

  @override
  ConsumerState<SafetyMonitorScreen> createState() =>
      _SafetyMonitorScreenState();
}

class _SafetyMonitorScreenState extends ConsumerState<SafetyMonitorScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  bool _isAnalyzing = false;
  _RouteRiskResult? _result;
  late AnimationController _riskAnimController;
  late Animation<double> _riskAnimation;

  @override
  void initState() {
    super.initState();
    _sourceController.text = 'Downtown City Center';
    _destController.text = 'North District Hospital';
    _riskAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _riskAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _riskAnimController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destController.dispose();
    _riskAnimController.dispose();
    super.dispose();
  }

  void _swapLocations() {
    final temp = _sourceController.text;
    _sourceController.text = _destController.text;
    _destController.text = temp;
    setState(() {});
  }

  Future<void> _analyzeRoute() async {
    if (_sourceController.text.trim().isEmpty ||
        _destController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter both source and destination',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: _kEmergencyRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
    });

    final aiService = ref.read(aiServiceProvider);
    
    // Hash-based coordinates so we have different points depending on input
    double startLat = 37.7749 + (_sourceController.text.hashCode % 100) * 0.0001;
    double startLng = -122.4194 + (_sourceController.text.hashCode % 100) * 0.0001;
    double endLat = 37.7891 + (_destController.text.hashCode % 100) * 0.0001;
    double endLng = -122.4014 + (_destController.text.hashCode % 100) * 0.0001;

    try {
      final partsStart = _sourceController.text.split(',');
      if (partsStart.length == 2) {
        startLat = double.parse(partsStart[0].trim());
        startLng = double.parse(partsStart[1].trim());
      }
    } catch (_) {}
    try {
      final partsEnd = _destController.text.split(',');
      if (partsEnd.length == 2) {
        endLat = double.parse(partsEnd[0].trim());
        endLng = double.parse(partsEnd[1].trim());
      }
    } catch (_) {}

    final rawData = await aiService.generateRouteRisk(
      startLat,
      startLng,
      endLat,
      endLng,
    );

    if (!mounted) return;

    final int riskScore = rawData['riskLevel'] as int? ?? 50;
    final String riskLabel = rawData['riskLabel'] as String? ?? 'MODERATE';
    final String eta = rawData['eta'] as String? ?? '25 min';
    final String distance = rawData['distance'] as String? ?? '10 km';
    final String aiRecommendation = rawData['recommendation'] as String? ?? 'Proceed with standard caution.';
    
    final rawHazards = rawData['hazards'] as List? ?? [];
    final List<_HazardZone> hazards = rawHazards.map((h) {
      final map = h as Map<String, dynamic>;
      final type = map['type'] as String? ?? 'Hazard Alert';
      final severity = map['severity'] as String? ?? 'medium';
      
      IconData icon = Icons.warning_amber_rounded;
      final typeLower = type.toLowerCase();
      if (typeLower.contains('flood') || typeLower.contains('water')) {
        icon = Icons.water_rounded;
      } else if (typeLower.contains('fire')) {
        icon = Icons.local_fire_department_rounded;
      } else if (typeLower.contains('infrastructure') || typeLower.contains('road') || typeLower.contains('construction')) {
        icon = Icons.construction_rounded;
      } else if (typeLower.contains('power') || typeLower.contains('outage')) {
        icon = Icons.power_off_rounded;
      } else if (typeLower.contains('chemical') || typeLower.contains('gas')) {
        icon = Icons.warning_amber_rounded;
      }

      return _HazardZone(
        name: map['description'] as String? ?? 'Reported Hazard',
        type: type,
        severity: severity.isEmpty ? 'Medium' : severity[0].toUpperCase() + severity.substring(1),
        icon: icon,
      );
    }).toList();

    final List<_RiskFactor> riskFactors = [
      _RiskFactor(factor: 'Active local hazards', weight: (riskScore * 0.45) / 100.0),
      _RiskFactor(factor: 'Terrain and vector slope', weight: 0.15 + (riskScore % 5) * 0.03),
      _RiskFactor(factor: 'Cascade probability index', weight: (riskScore * 0.3) / 100.0),
      _RiskFactor(factor: 'Emergency unit traffic load', weight: 0.10),
    ];

    final rawAlt = rawData['alternateRoutes'] as List? ?? [];
    final List<_AlternativeRoute> alternativeRoutes = rawAlt.map((a) {
      final map = a as Map<String, dynamic>;
      return _AlternativeRoute(
        name: map['name'] as String? ?? 'Alternate Bypass Route',
        eta: map['eta'] as String? ?? '+5 min',
        distance: distance,
        riskScore: map['riskLevel'] as int? ?? 15,
      );
    }).toList();

    final result = _RouteRiskResult(
      riskScore: riskScore,
      riskLabel: riskLabel,
      eta: eta,
      distance: distance,
      aiRecommendation: aiRecommendation,
      hazards: hazards,
      riskFactors: riskFactors,
      alternativeRoutes: alternativeRoutes,
    );

    _riskAnimation = Tween<double>(
      begin: 0,
      end: result.riskScore.toDouble(),
    ).animate(
      CurvedAnimation(parent: _riskAnimController, curve: Curves.easeOutCubic),
    );
    _riskAnimController.reset();
    _riskAnimController.forward();

    setState(() {
      _result = result;
      _isAnalyzing = false;
    });
  }

  Color _riskColor(double score) {
    if (score <= 30) return _kSuccessTeal;
    if (score <= 60) return _kAccentAmber;
    return _kEmergencyRed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPrimary,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          'Route Safety Monitor',
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Source & Destination ───────────────────────────────────
            _buildInputSection(),
            const SizedBox(height: 20),

            // ── Analyze Button ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeRoute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccentAmber,
                  foregroundColor: _kPrimary,
                  disabledBackgroundColor: _kAccentAmber.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _kPrimary,
                        ),
                      )
                    : const Icon(Icons.route_rounded),
                label: Text(
                  _isAnalyzing ? 'Analyzing...' : 'Analyze Route',
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            // ── Results ───────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: 28),
              _buildRiskMeter(),
              const SizedBox(height: 24),
              _buildRouteOverviewCard(),
              const SizedBox(height: 16),
              _buildHazardZonesCard(),
              const SizedBox(height: 16),
              _buildAiRecommendationCard(),
              const SizedBox(height: 16),
              _buildAlternativeRoutesCard(),
              const SizedBox(height: 16),
              _buildRouteVisualizationPlaceholder(),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  // ── Input Section ─────────────────────────────────────────────────────────
  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Location dots ───────────────────────────────────────────
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kSuccessTeal,
                  boxShadow: [
                    BoxShadow(
                        color: _kSuccessTeal.withValues(alpha: 0.4),
                        blurRadius: 6),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 40,
                color: Colors.white24,
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kEmergencyRed,
                  boxShadow: [
                    BoxShadow(
                        color: _kEmergencyRed.withValues(alpha: 0.4),
                        blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // ── Text Fields ─────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: _sourceController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Source location',
                    hintStyle: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.my_location_rounded,
                        color: _kSuccessTeal, size: 20),
                    filled: true,
                    fillColor: _kFieldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _destController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Destination',
                    hintStyle: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.flag_rounded,
                        color: _kEmergencyRed, size: 20),
                    filled: true,
                    fillColor: _kFieldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Swap Button ─────────────────────────────────────────────
          IconButton(
            onPressed: _swapLocations,
            icon: const Icon(Icons.swap_vert_rounded,
                color: _kAccentAmber, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: _kAccentAmber.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  // ── Risk Meter ────────────────────────────────────────────────────────────
  Widget _buildRiskMeter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            'Route Risk Assessment',
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _riskAnimController,
            builder: (context, child) {
              final score = _riskAnimation.value;
              return SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: _RiskMeterPainter(
                    score: score,
                    color: _riskColor(score),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          score.toInt().toString(),
                          style: GoogleFonts.urbanist(
                            color: _riskColor(score),
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _result!.riskLabel,
                          style: GoogleFonts.inter(
                            color: _riskColor(score).withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // ── Risk Factors ────────────────────────────────────────────
          ...(_result!.riskFactors.map((factor) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        factor.factor,
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: factor.weight,
                          backgroundColor: Colors.white10,
                          color: _riskColor(factor.weight * 100),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(factor.weight * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ))),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 100.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  // ── Route Overview Card ───────────────────────────────────────────────────
  Widget _buildRouteOverviewCard() {
    final r = _result!;
    return _AnalysisCard(
      title: 'Route Overview',
      icon: Icons.map_rounded,
      iconColor: _kAccentAmber,
      delay: 200,
      child: Row(
        children: [
          _MetricTile(label: 'ETA', value: r.eta, icon: Icons.timer_rounded),
          _MetricTile(
              label: 'Distance',
              value: r.distance,
              icon: Icons.straighten_rounded),
          _MetricTile(
            label: 'Risk',
            value: '${r.riskScore}/100',
            icon: Icons.shield_rounded,
            valueColor: _riskColor(r.riskScore.toDouble()),
          ),
        ],
      ),
    );
  }

  // ── Hazard Zones Card ─────────────────────────────────────────────────────
  Widget _buildHazardZonesCard() {
    return _AnalysisCard(
      title: 'Hazard Zones Found',
      icon: Icons.dangerous_rounded,
      iconColor: _kEmergencyRed,
      delay: 300,
      child: Column(
        children: _result!.hazards
            .map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _severityBgColor(h.severity),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(h.icon,
                            color: _severityFgColor(h.severity), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              h.type,
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _severityBgColor(h.severity),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          h.severity,
                          style: GoogleFonts.inter(
                            color: _severityFgColor(h.severity),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── AI Recommendation Card ────────────────────────────────────────────────
  Widget _buildAiRecommendationCard() {
    return _AnalysisCard(
      title: 'AI Recommendation',
      icon: Icons.auto_awesome_rounded,
      iconColor: _kSuccessTeal,
      delay: 400,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSuccessTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kSuccessTeal.withValues(alpha: 0.2)),
        ),
        child: Text(
          _result!.aiRecommendation,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  // ── Alternative Routes Card ───────────────────────────────────────────────
  Widget _buildAlternativeRoutesCard() {
    return _AnalysisCard(
      title: 'Alternative Routes',
      icon: Icons.alt_route_rounded,
      iconColor: _kAccentAmber,
      delay: 500,
      child: Column(
        children: _result!.alternativeRoutes
            .map((route) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kFieldBg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              _riskColor(route.riskScore.toDouble()).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${route.riskScore}',
                            style: GoogleFonts.urbanist(
                              color: _riskColor(route.riskScore.toDouble()),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${route.distance} · ${route.eta}',
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kSuccessTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          route.riskScore <= 25 ? 'SAFE' : 'OK',
                          style: GoogleFonts.inter(
                            color: _kSuccessTeal,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Route Visualization Placeholder ───────────────────────────────────────
  Widget _buildRouteVisualizationPlaceholder() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: CustomPaint(
        painter: _RouteGraphicPainter(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.route_rounded, color: Colors.white24, size: 40),
              const SizedBox(height: 8),
              Text(
                'Route Visualization',
                style: GoogleFonts.inter(
                  color: Colors.white24,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Interactive map view coming soon',
                style: GoogleFonts.inter(
                  color: Colors.white12,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 600.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Color _severityBgColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return _kEmergencyRed.withValues(alpha: 0.15);
      case 'high':
        return _kAccentAmber.withValues(alpha: 0.15);
      case 'medium':
        return _kAccentAmber.withValues(alpha: 0.1);
      default:
        return _kSuccessTeal.withValues(alpha: 0.1);
    }
  }

  Color _severityFgColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return _kEmergencyRed;
      case 'high':
        return _kAccentAmber;
      case 'medium':
        return _kAccentAmber.withValues(alpha: 0.8);
      default:
        return _kSuccessTeal;
    }
  }
}

// ─── Risk Meter Painter ───────────────────────────────────────────────────────
class _RiskMeterPainter extends CustomPainter {
  final double score;
  final Color color;

  _RiskMeterPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = math.pi * 0.75;
    const totalSweep = math.pi * 1.5;
    final sweepAngle = totalSweep * (score / 100);

    // Background arc
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      bgPaint,
    );

    // Foreground arc
    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          color.withValues(alpha: 0.6),
          color,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      fgPaint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // Tick marks
    for (int i = 0; i <= 10; i++) {
      final tickAngle = startAngle + (totalSweep * i / 10);
      final innerR = radius - 22;
      final outerR = radius - 16;
      final p1 = Offset(
        center.dx + innerR * math.cos(tickAngle),
        center.dy + innerR * math.sin(tickAngle),
      );
      final p2 = Offset(
        center.dx + outerR * math.cos(tickAngle),
        center.dy + outerR * math.sin(tickAngle),
      );
      final tickPaint = Paint()
        ..strokeWidth = i % 5 == 0 ? 2.0 : 1.0
        ..color = Colors.white.withValues(alpha: i % 5 == 0 ? 0.3 : 0.1);
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RiskMeterPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}

// ─── Route Graphic Painter ────────────────────────────────────────────────────
class _RouteGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.7);
    path.cubicTo(
      size.width * 0.3,
      size.height * 0.2,
      size.width * 0.5,
      size.height * 0.9,
      size.width * 0.9,
      size.height * 0.3,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _kAccentAmber.withValues(alpha: 0.15)
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);

    // Draw dashed alternative
    final altPath = Path();
    altPath.moveTo(size.width * 0.1, size.height * 0.7);
    altPath.cubicTo(
      size.width * 0.4,
      size.height * 0.5,
      size.width * 0.6,
      size.height * 0.4,
      size.width * 0.9,
      size.height * 0.3,
    );

    final altPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _kSuccessTeal.withValues(alpha: 0.12)
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(altPath, altPaint);

    // Source dot
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.7),
      6,
      Paint()..color = _kSuccessTeal.withValues(alpha: 0.3),
    );
    // Dest dot
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.3),
      6,
      Paint()..color = _kEmergencyRed.withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Analysis Card ──────────────────────────────────────────────────────────
class _AnalysisCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final int delay;
  final Widget child;

  const _AnalysisCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay))
        .slideY(begin: 0.1, end: 0);
  }
}

// ─── Metric Tile ────────────────────────────────────────────────────────────
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kFieldBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white38, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.urbanist(
                color: valueColor ?? Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
