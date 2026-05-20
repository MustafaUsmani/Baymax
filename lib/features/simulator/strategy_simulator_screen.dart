import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:crisis_link/services/ai_service.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF0D1B2A);
const Color _kSurface = Color(0xFF1A1A2E);
const Color _kAccentAmber = Color(0xFFF5A623);
const Color _kEmergencyRed = Color(0xFFE63946);
const Color _kSuccessTeal = Color(0xFF2EC4B6);
const Color _kCardBg = Color(0xFF16213E);
const Color _kFieldBg = Color(0xFF0F3460);

// ─── Strategy Types ───────────────────────────────────────────────────────────
enum StrategyType {
  aggressive,
  balanced,
  conservative,
}

extension StrategyTypeExt on StrategyType {
  String get label {
    switch (this) {
      case StrategyType.aggressive:
        return 'Aggressive';
      case StrategyType.balanced:
        return 'Balanced';
      case StrategyType.conservative:
        return 'Conservative';
    }
  }

  IconData get icon {
    switch (this) {
      case StrategyType.aggressive:
        return Icons.flash_on_rounded;
      case StrategyType.balanced:
        return Icons.balance_rounded;
      case StrategyType.conservative:
        return Icons.shield_rounded;
    }
  }

  Color get color {
    switch (this) {
      case StrategyType.aggressive:
        return _kEmergencyRed;
      case StrategyType.balanced:
        return _kAccentAmber;
      case StrategyType.conservative:
        return _kSuccessTeal;
    }
  }

  String get description {
    switch (this) {
      case StrategyType.aggressive:
        return 'Maximum resource deployment with rapid response. Higher short-term costs.';
      case StrategyType.balanced:
        return 'Optimized resource allocation balancing speed and sustainability.';
      case StrategyType.conservative:
        return 'Minimal disruption approach. Slower but preserves resources for extended operations.';
    }
  }
}

// ─── Simulation Result ────────────────────────────────────────────────────────
class SimulationResult {
  final StrategyType strategy;
  final double congestionReduction;
  final int casualtyEstimate;
  final double recoveryTimeHours;
  final double resourceUsage;
  final String aiRecommendation;

  SimulationResult({
    required this.strategy,
    required this.congestionReduction,
    required this.casualtyEstimate,
    required this.recoveryTimeHours,
    required this.resourceUsage,
    required this.aiRecommendation,
  });
}

// ─── AI Simulation Service ────────────────────────────────────────────────────

// ─── Providers ────────────────────────────────────────────────────────────────
final resourceAllocationProvider = StateProvider<double>((ref) => 60.0);
final roadClosuresProvider = StateProvider<int>((ref) => 5);
final medicalDeploymentProvider = StateProvider<double>((ref) => 50.0);
final fuelAvailabilityProvider = StateProvider<double>((ref) => 70.0);
final selectedStrategyProvider =
    StateProvider<StrategyType>((ref) => StrategyType.balanced);
final simulationResultsProvider =
    StateProvider<List<SimulationResult>?>((ref) => null);
final isSimulatingProvider = StateProvider<bool>((ref) => false);

// ─── Screen ───────────────────────────────────────────────────────────────────
class StrategySimulatorScreen extends ConsumerStatefulWidget {
  const StrategySimulatorScreen({super.key});

  @override
  ConsumerState<StrategySimulatorScreen> createState() =>
      _StrategySimulatorScreenState();
}

class _StrategySimulatorScreenState
    extends ConsumerState<StrategySimulatorScreen> {
  Future<void> _runSimulation() async {
    ref.read(isSimulatingProvider.notifier).state = true;
    ref.read(simulationResultsProvider.notifier).state = null;

    final resourceAllocation = ref.read(resourceAllocationProvider);
    final roadClosures = ref.read(roadClosuresProvider);
    final medicalDeployment = ref.read(medicalDeploymentProvider);
    final fuelAvailability = ref.read(fuelAvailabilityProvider);

    final aiService = ref.read(aiServiceProvider);

    final futures = StrategyType.values.map((st) async {
      final inputs = {
        'resourceAllocation': resourceAllocation,
        'roadClosures': roadClosures.toDouble(),
        'medicalDeployment': medicalDeployment,
        'fuelAvailability': fuelAvailability,
      };
      
      final model = await aiService.simulateStrategy(st.name, inputs);
      
      return SimulationResult(
        strategy: st,
        congestionReduction: model.congestionReduction,
        casualtyEstimate: model.casualtyEstimate,
        recoveryTimeHours: model.recoveryTimeHours,
        resourceUsage: model.resourceUsagePercent,
        aiRecommendation: model.recommendation,
      );
    });

    final results = await Future.wait(futures);

    if (!mounted) return;
    ref.read(simulationResultsProvider.notifier).state = results;
    ref.read(isSimulatingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final resourceAllocation = ref.watch(resourceAllocationProvider);
    final roadClosures = ref.watch(roadClosuresProvider);
    final medicalDeployment = ref.watch(medicalDeploymentProvider);
    final fuelAvailability = ref.watch(fuelAvailabilityProvider);
    final selectedStrategy = ref.watch(selectedStrategyProvider);
    final results = ref.watch(simulationResultsProvider);
    final isSimulating = ref.watch(isSimulatingProvider);

    return Scaffold(
      backgroundColor: _kPrimary,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          'Strategy Simulator',
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
            // ── Input Controls ────────────────────────────────────────
            _buildSectionTitle('Resource Parameters'),
            const SizedBox(height: 12),
            _buildSliderCard(
              label: 'Resource Allocation',
              value: resourceAllocation,
              suffix: '%',
              min: 0,
              max: 100,
              icon: Icons.inventory_2_rounded,
              onChanged: (v) =>
                  ref.read(resourceAllocationProvider.notifier).state = v,
            ),
            _buildSliderCard(
              label: 'Road Closures',
              value: roadClosures.toDouble(),
              suffix: '',
              min: 0,
              max: 20,
              divisions: 20,
              icon: Icons.block_rounded,
              onChanged: (v) =>
                  ref.read(roadClosuresProvider.notifier).state = v.toInt(),
            ),
            _buildSliderCard(
              label: 'Medical Deployment',
              value: medicalDeployment,
              suffix: '%',
              min: 0,
              max: 100,
              icon: Icons.local_hospital_rounded,
              onChanged: (v) =>
                  ref.read(medicalDeploymentProvider.notifier).state = v,
            ),
            _buildSliderCard(
              label: 'Fuel Availability',
              value: fuelAvailability,
              suffix: '%',
              min: 0,
              max: 100,
              icon: Icons.local_gas_station_rounded,
              onChanged: (v) =>
                  ref.read(fuelAvailabilityProvider.notifier).state = v,
            ),

            const SizedBox(height: 24),

            // ── Strategy Selection ────────────────────────────────────
            _buildSectionTitle('Strategy Selection'),
            const SizedBox(height: 12),
            Row(
              children: StrategyType.values
                  .map((st) => Expanded(
                        child: _StrategyCard(
                          strategy: st,
                          isSelected: selectedStrategy == st,
                          onTap: () => ref
                              .read(selectedStrategyProvider.notifier)
                              .state = st,
                        ),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 24),

            // ── Run Simulation Button ─────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isSimulating ? null : _runSimulation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccentAmber,
                  foregroundColor: _kPrimary,
                  disabledBackgroundColor: _kAccentAmber.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                ),
                icon: isSimulating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _kPrimary,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 26),
                label: Text(
                  isSimulating ? 'Simulating...' : 'Run Simulation',
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ),

            // ── Results ───────────────────────────────────────────────
            if (results != null) ...[
              const SizedBox(height: 32),
              _buildSectionTitle('Simulation Results'),
              const SizedBox(height: 16),
              _buildResultsComparison(results),
              const SizedBox(height: 24),
              _buildSectionTitle('Performance Comparison'),
              const SizedBox(height: 16),
              _buildBarChart(results),
              const SizedBox(height: 24),
              _buildAiPredictionSummary(results),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section Title ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.urbanist(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ── Slider Card ───────────────────────────────────────────────────────────
  Widget _buildSliderCard({
    required String label,
    required double value,
    required String suffix,
    required double min,
    required double max,
    required IconData icon,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: _kAccentAmber, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  suffix.isNotEmpty
                      ? '${value.toInt()}$suffix'
                      : '${value.toInt()}',
                  style: GoogleFonts.urbanist(
                    color: _kAccentAmber,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _kAccentAmber,
              inactiveTrackColor: Colors.white10,
              thumbColor: _kAccentAmber,
              overlayColor: _kAccentAmber.withValues(alpha: 0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions ?? 100,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ── Results Comparison ────────────────────────────────────────────────────
  Widget _buildResultsComparison(List<SimulationResult> results) {
    return Column(
      children: results.asMap().entries.map((entry) {
        final idx = entry.key;
        final result = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: result.strategy.color.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: result.strategy.color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: result.strategy.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(result.strategy.icon,
                          color: result.strategy.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.strategy.label,
                          style: GoogleFonts.urbanist(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Strategy',
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Metrics Grid ──────────────────────────────────────
                Row(
                  children: [
                    _ResultMetric(
                      label: 'Congestion\nReduction',
                      value: '${result.congestionReduction.toStringAsFixed(1)}%',
                      color: _kSuccessTeal,
                    ),
                    _ResultMetric(
                      label: 'Casualty\nEstimate',
                      value: '${result.casualtyEstimate}',
                      color: _kEmergencyRed,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ResultMetric(
                      label: 'Recovery\nTime',
                      value: '${result.recoveryTimeHours.toStringAsFixed(1)}h',
                      color: _kAccentAmber,
                    ),
                    _ResultMetric(
                      label: 'Resource\nUsage',
                      value: '${result.resourceUsage.toStringAsFixed(1)}%',
                      color: Colors.white70,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── AI Recommendation ─────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: result.strategy.color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: result.strategy.color.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: result.strategy.color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.aiRecommendation,
                          style: GoogleFonts.inter(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Congestion Bar ────────────────────────────────────
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Congestion Reduction',
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      '${result.congestionReduction.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        color: result.strategy.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.congestionReduction / 100,
                    backgroundColor: Colors.white10,
                    color: result.strategy.color,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms, delay: Duration(milliseconds: idx * 150))
            .slideX(begin: 0.1, end: 0);
      }).toList(),
    );
  }

  // ── Bar Chart ─────────────────────────────────────────────────────────────
  Widget _buildBarChart(List<SimulationResult> results) {
    return Container(
      height: 300,
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
              const Icon(Icons.bar_chart_rounded,
                  color: _kAccentAmber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Metrics Comparison',
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: StrategyType.values
                .map((st) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: st.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            st.label,
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipColor: (_) => _kSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final labels = [
                        'Congestion Red.',
                        'Recovery (scaled)',
                        'Resource Usage',
                      ];
                      final strategies = StrategyType.values;
                      return BarTooltipItem(
                        '${strategies[rodIndex].label}\n${labels[groupIndex]}: ${rod.toY.toStringAsFixed(1)}%',
                        GoogleFonts.inter(
                          color: strategies[rodIndex].color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final labels = ['Congestion', 'Recovery', 'Resources'];
                        if (value.toInt() >= 0 &&
                            value.toInt() < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[value.toInt()],
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: GoogleFonts.inter(
                            color: Colors.white24,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  // Congestion Reduction
                  BarChartGroupData(
                    x: 0,
                    barRods: results
                        .map((r) => BarChartRodData(
                              toY: r.congestionReduction,
                              color: r.strategy.color,
                              width: 14,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ))
                        .toList(),
                    barsSpace: 4,
                  ),
                  // Recovery Time (scaled to percentage of 30 hours max)
                  BarChartGroupData(
                    x: 1,
                    barRods: results
                        .map((r) => BarChartRodData(
                              toY: (r.recoveryTimeHours / 30 * 100)
                                  .clamp(0, 100),
                              color: r.strategy.color,
                              width: 14,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ))
                        .toList(),
                    barsSpace: 4,
                  ),
                  // Resource Usage
                  BarChartGroupData(
                    x: 2,
                    barRods: results
                        .map((r) => BarChartRodData(
                              toY: r.resourceUsage,
                              color: r.strategy.color,
                              width: 14,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ))
                        .toList(),
                    barsSpace: 4,
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 500.ms)
        .slideY(begin: 0.15, end: 0);
  }

  // ── AI Prediction Summary ─────────────────────────────────────────────────
  Widget _buildAiPredictionSummary(List<SimulationResult> results) {
    final balanced =
        results.firstWhere((r) => r.strategy == StrategyType.balanced);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kSuccessTeal.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _kSuccessTeal.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kSuccessTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: _kSuccessTeal, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Prediction Summary',
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSuccessTeal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kSuccessTeal.withValues(alpha: 0.15)),
            ),
            child: Text(
              'Based on current resource allocation of ${ref.read(resourceAllocationProvider).toInt()}%, '
              'the Balanced strategy provides optimal results with '
              '${balanced.congestionReduction.toStringAsFixed(1)}% congestion reduction '
              'and estimated ${balanced.recoveryTimeHours.toStringAsFixed(1)}-hour recovery time. '
              'With ${ref.read(roadClosuresProvider)} road closures and '
              '${ref.read(medicalDeploymentProvider).toInt()}% medical deployment, '
              'this configuration maintains a sustainable operation tempo while minimizing '
              'estimated casualties to ${balanced.casualtyEstimate} persons. '
              'Fuel availability at ${ref.read(fuelAvailabilityProvider).toInt()}% '
              'supports continued operations for the projected recovery window.',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.recommend_rounded,
                  color: _kSuccessTeal, size: 16),
              const SizedBox(width: 6),
              Text(
                'Recommended: Balanced Strategy',
                style: GoogleFonts.inter(
                  color: _kSuccessTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 700.ms)
        .slideY(begin: 0.1, end: 0);
  }
}

// ─── Strategy Card ──────────────────────────────────────────────────────────
class _StrategyCard extends StatelessWidget {
  final StrategyType strategy;
  final bool isSelected;
  final VoidCallback onTap;

  const _StrategyCard({
    required this.strategy,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _kAccentAmber.withValues(alpha: 0.1)
              : _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? _kAccentAmber
                : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _kAccentAmber.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              strategy.icon,
              color: isSelected ? _kAccentAmber : Colors.white38,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              strategy.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: isSelected ? _kAccentAmber : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Result Metric ──────────────────────────────────────────────────────────
class _ResultMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kFieldBg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.urbanist(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
