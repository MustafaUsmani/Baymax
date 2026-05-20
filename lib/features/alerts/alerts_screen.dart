import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF0D1B2A);
const Color _kSurface = Color(0xFF1A1A2E);
const Color _kAccentAmber = Color(0xFFF5A623);
const Color _kEmergencyRed = Color(0xFFE63946);
const Color _kSuccessTeal = Color(0xFF2EC4B6);
const Color _kDarkRed = Color(0xFF9B1B30);
const Color _kCardBg = Color(0xFF16213E);
const Color _kFieldBg = Color(0xFF0F3460);

// ─── Alert Model ──────────────────────────────────────────────────────────────
class AlertModel {
  final String id;
  final String title;
  final String description;
  final String affectedArea;
  final String category;
  final String severity; // low, medium, high, critical
  final DateTime timestamp;
  final String aiAdvice;
  final bool isSubscribed;

  AlertModel({
    required this.id,
    required this.title,
    required this.description,
    required this.affectedArea,
    required this.category,
    required this.severity,
    required this.timestamp,
    required this.aiAdvice,
    this.isSubscribed = false,
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AlertModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled Alert',
      description: data['description'] as String? ?? '',
      affectedArea: data['affectedArea'] as String? ?? 'Unknown Area',
      category: data['category'] as String? ?? 'Other',
      severity: data['severity'] as String? ?? 'medium',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aiAdvice: data['aiAdvice'] as String? ?? 'Stay alert and follow local authorities\' guidance.',
      isSubscribed: data['isSubscribed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'affectedArea': affectedArea,
        'category': category,
        'severity': severity,
        'timestamp': Timestamp.fromDate(timestamp),
        'aiAdvice': aiAdvice,
        'isSubscribed': isSubscribed,
      };

  AlertModel copyWith({bool? isSubscribed}) => AlertModel(
        id: id,
        title: title,
        description: description,
        affectedArea: affectedArea,
        category: category,
        severity: severity,
        timestamp: timestamp,
        aiAdvice: aiAdvice,
        isSubscribed: isSubscribed ?? this.isSubscribed,
      );
}

// ─── Providers ────────────────────────────────────────────────────────────────
final alertsStreamProvider = StreamProvider<List<AlertModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('alerts')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(AlertModel.fromFirestore).toList());
});

final alertSearchQueryProvider = StateProvider<String>((ref) => '');
final alertCategoryFilterProvider = StateProvider<String>((ref) => 'All');
final subscribedAlertIdsProvider = StateProvider<Set<String>>((ref) => {});

// ─── Screen ───────────────────────────────────────────────────────────────────
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'All',
    'Weather',
    'Flood',
    'Fire',
    'Medical',
    'Infrastructure',
    'Other',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(alertsStreamProvider);
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _createTestAlert() {
    final uuid = const Uuid();
    final testAlerts = [
      {
        'title': 'Flash Flood Warning',
        'description':
            'Heavy rainfall expected to cause flash flooding in low-lying areas. Water levels rising rapidly in rivers and streams.',
        'affectedArea': 'Downtown River District',
        'category': 'Flood',
        'severity': 'critical',
        'aiAdvice':
            'Evacuate to higher ground immediately. Avoid walking or driving through floodwaters. Move to upper floors if trapped.',
      },
      {
        'title': 'Severe Thunderstorm Alert',
        'description':
            'Strong thunderstorms approaching with damaging winds up to 70mph and large hail possible across the metro area.',
        'affectedArea': 'Metro Region North',
        'category': 'Weather',
        'severity': 'high',
        'aiAdvice':
            'Seek shelter indoors away from windows. Unplug sensitive electronics. Avoid open areas and tall objects.',
      },
      {
        'title': 'Wildfire Smoke Advisory',
        'description':
            'Air quality index reaching unhealthy levels due to nearby wildfire. Sensitive groups should remain indoors.',
        'affectedArea': 'Western Suburbs',
        'category': 'Fire',
        'severity': 'medium',
        'aiAdvice':
            'Keep windows closed. Use air purifiers if available. Limit outdoor activity especially for children and elderly.',
      },
      {
        'title': 'Medical Supply Distribution',
        'description':
            'Emergency medical supply distribution center open at community center. Free first aid kits and medications available.',
        'affectedArea': 'Central Community Hub',
        'category': 'Medical',
        'severity': 'low',
        'aiAdvice':
            'Visit the distribution center between 8AM-6PM. Bring ID for prescription medications. Volunteers needed.',
      },
      {
        'title': 'Bridge Structural Damage',
        'description':
            'Highway 101 bridge showing structural cracks after recent seismic activity. Bridge closed until further inspection.',
        'affectedArea': 'Highway 101 Corridor',
        'category': 'Infrastructure',
        'severity': 'high',
        'aiAdvice':
            'Use alternate routes via Route 280 or local streets. Expected repair timeline: 48-72 hours. Monitor updates.',
      },
    ];

    final randomAlert = testAlerts[DateTime.now().millisecond % testAlerts.length];
    FirebaseFirestore.instance.collection('alerts').doc(uuid.v4()).set({
      ...randomAlert,
      'timestamp': Timestamp.now(),
      'isSubscribed': false,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Test alert created: ${randomAlert['title']}',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: _kSuccessTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  List<AlertModel> _filterAlerts(List<AlertModel> alerts) {
    final query = ref.read(alertSearchQueryProvider).toLowerCase();
    final category = ref.read(alertCategoryFilterProvider);

    return alerts.where((alert) {
      final matchesSearch = query.isEmpty ||
          alert.title.toLowerCase().contains(query) ||
          alert.description.toLowerCase().contains(query);
      final matchesCategory =
          category == 'All' || alert.category.toLowerCase() == category.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsStreamProvider);
    final searchQuery = ref.watch(alertSearchQueryProvider);
    final selectedCategory = ref.watch(alertCategoryFilterProvider);
    final subscribedIds = ref.watch(subscribedAlertIdsProvider);

    return Scaffold(
      backgroundColor: _kPrimary,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          'Alert Center',
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white70),
            onPressed: () {
              // Focus the search field
              FocusScope.of(context).requestFocus(FocusNode());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(alertSearchQueryProvider.notifier).state = value,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search alerts by title or description...',
                hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(alertSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: _kFieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // ── Category Tabs ───────────────────────────────────────────────
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ChoiceChip(
                    label: Text(
                      cat,
                      style: GoogleFonts.inter(
                        color: isSelected ? _kPrimary : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: _kAccentAmber,
                    backgroundColor: _kCardBg,
                    side: BorderSide(
                      color: isSelected ? _kAccentAmber : Colors.white12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (_) =>
                        ref.read(alertCategoryFilterProvider.notifier).state =
                            cat,
                  ),
                );
              },
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // ── Alert List ──────────────────────────────────────────────────
          Expanded(
            child: alertsAsync.when(
              loading: () => _buildShimmerList(),
              error: (err, stack) => _buildErrorState(err.toString()),
              data: (alerts) {
                final filtered = _filterAlerts(alerts);
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: _kAccentAmber,
                  backgroundColor: _kSurface,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final alert = filtered[index];
                      final isSubscribed = subscribedIds.contains(alert.id);
                      return _AlertCard(
                        alert: alert,
                        index: index,
                        isSubscribed: isSubscribed,
                        onToggleSubscribe: () {
                          final ids =
                              Set<String>.from(ref.read(subscribedAlertIdsProvider));
                          if (ids.contains(alert.id)) {
                            ids.remove(alert.id);
                          } else {
                            ids.add(alert.id);
                          }
                          ref.read(subscribedAlertIdsProvider.notifier).state = ids;
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTestAlert,
        backgroundColor: _kAccentAmber,
        icon: const Icon(Icons.add_alert_rounded, color: _kPrimary),
        label: Text(
          'Test Alert',
          style: GoogleFonts.inter(
            color: _kPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Shimmer Loading ───────────────────────────────────────────────────────
  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: _kCardBg,
      highlightColor: _kSurface.withValues(alpha: 0.5),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kCardBg,
              border: Border.all(color: Colors.white10, width: 2),
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Alerts Found',
            style: GoogleFonts.urbanist(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No alerts match your current filters.\nTry adjusting your search or category.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────────
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: _kEmergencyRed),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Alerts',
              style: GoogleFonts.urbanist(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(alertsStreamProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentAmber,
                foregroundColor: _kPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Retry', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Alert Card Widget ────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final int index;
  final bool isSubscribed;
  final VoidCallback onToggleSubscribe;

  const _AlertCard({
    required this.alert,
    required this.index,
    required this.isSubscribed,
    required this.onToggleSubscribe,
  });

  Color _severityColor() {
    switch (alert.severity.toLowerCase()) {
      case 'low':
        return _kSuccessTeal;
      case 'medium':
        return _kAccentAmber;
      case 'high':
        return _kEmergencyRed;
      case 'critical':
        return _kDarkRed;
      default:
        return _kAccentAmber;
    }
  }

  String _severityLabel() {
    switch (alert.severity.toLowerCase()) {
      case 'low':
        return 'LOW';
      case 'medium':
        return 'MEDIUM';
      case 'high':
        return 'HIGH';
      case 'critical':
        return 'CRITICAL';
      default:
        return 'UNKNOWN';
    }
  }

  IconData _categoryIcon() {
    switch (alert.category.toLowerCase()) {
      case 'weather':
        return Icons.thunderstorm_rounded;
      case 'flood':
        return Icons.water_rounded;
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      case 'infrastructure':
        return Icons.construction_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sevColor = _severityColor();
    final timeAgo = _formatTimeAgo(alert.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: sevColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: sevColor.withValues(alpha: 0.15),
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
            // ── Header Row ────────────────────────────────────────────
            Row(
              children: [
                Icon(_categoryIcon(), color: sevColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.title,
                    style: GoogleFonts.urbanist(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sevColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _severityLabel(),
                    style: GoogleFonts.inter(
                      color: sevColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Affected Area ─────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  alert.affectedArea,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.access_time_rounded,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  timeAgo,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Description ───────────────────────────────────────────
            Text(
              alert.description,
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            // ── AI Advice ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kSuccessTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _kSuccessTeal.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: _kSuccessTeal, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.aiAdvice,
                      style: GoogleFonts.inter(
                        color: _kSuccessTeal.withValues(alpha: 0.9),
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Subscribe Button ──────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onToggleSubscribe,
                style: TextButton.styleFrom(
                  backgroundColor: isSubscribed
                      ? _kAccentAmber.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSubscribed
                          ? _kAccentAmber.withValues(alpha: 0.5)
                          : Colors.white12,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: Icon(
                  isSubscribed
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: 18,
                  color: isSubscribed ? _kAccentAmber : Colors.white54,
                ),
                label: Text(
                  isSubscribed ? 'Subscribed' : 'Subscribe',
                  style: GoogleFonts.inter(
                    color: isSubscribed ? _kAccentAmber : Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (index * 80).ms,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          duration: 400.ms,
          delay: (index * 80).ms,
          curve: Curves.easeOutCubic,
        );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dateTime);
  }
}
