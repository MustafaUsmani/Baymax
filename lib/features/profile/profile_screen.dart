import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crisis_link/services/auth_service.dart';
import 'package:crisis_link/providers/health_provider.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF0D1B2A);
const Color _kSurface = Color(0xFF1A1A2E);
const Color _kAccentAmber = Color(0xFFF5A623);
const Color _kEmergencyRed = Color(0xFFE63946);
const Color _kSuccessTeal = Color(0xFF2EC4B6);
const Color _kCardBg = Color(0xFF16213E);

// ─── User Profile Model ──────────────────────────────────────────────────────
class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final int incidentsReported;
  final int alertsSubscribed;
  final int daysActive;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.incidentsReported = 0,
    this.alertsSubscribed = 0,
    this.daysActive = 0,
  });
}

// ─── Incident History Item ────────────────────────────────────────────────────
class IncidentHistoryItem {
  final String id;
  final String title;
  final String type;
  final DateTime date;
  final String severity;
  final IconData typeIcon;

  IncidentHistoryItem({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.severity,
    required this.typeIcon,
  });
}

// ─── Providers ────────────────────────────────────────────────────────────────

final refreshTriggerProvider = StateProvider<int>((ref) => 0);
final syncProgressProvider = StateProvider<bool>((ref) => false);

final incidentHistoryProvider = FutureProvider<List<IncidentHistoryItem>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.fetchIncidentsRaw();
    if (response.isSuccess && response.data != null) {
      final list = response.data!;
      if (list.isNotEmpty) {
        return list.map((item) {
          final crisisType = (item['crisis_type'] as String? ?? 'other').toLowerCase();
          IconData icon;
          switch (crisisType) {
            case 'flood':
              icon = Icons.water_rounded;
              break;
            case 'fire':
              icon = Icons.local_fire_department_rounded;
              break;
            case 'medical':
              icon = Icons.medical_services_rounded;
              break;
            case 'weather':
              icon = Icons.thunderstorm_rounded;
              break;
            default:
              icon = Icons.report_problem_rounded;
          }
          
          DateTime date;
          if (item['first_detected_at'] != null) {
            date = DateTime.parse(item['first_detected_at'] as String);
          } else {
            date = DateTime.now();
          }

          return IncidentHistoryItem(
            id: (item['id'] ?? '').toString(),
            title: item['title'] as String? ?? 'Incident Alert',
            type: item['crisis_type'] as String? ?? 'Other',
            date: date,
            severity: item['severity'] as String? ?? 'low',
            typeIcon: icon,
          );
        }).toList();
      }
    }
  } catch (_) {}
  
  return [
    IncidentHistoryItem(
      id: '1',
      title: 'Flooding on Main Street',
      type: 'Flood',
      date: DateTime.now().subtract(const Duration(days: 2)),
      severity: 'high',
      typeIcon: Icons.water_rounded,
    ),
    IncidentHistoryItem(
      id: '2',
      title: 'Power Line Down - Oak Ave',
      type: 'Infrastructure',
      date: DateTime.now().subtract(const Duration(days: 5)),
      severity: 'critical',
      typeIcon: Icons.power_off_rounded,
    ),
    IncidentHistoryItem(
      id: '3',
      title: 'Minor Fire Near Park',
      type: 'Fire',
      date: DateTime.now().subtract(const Duration(days: 8)),
      severity: 'medium',
      typeIcon: Icons.local_fire_department_rounded,
    ),
  ];
});

final userProfileProvider = Provider<UserProfile>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  final incidentsCount = ref.watch(incidentHistoryProvider).valueOrNull?.length ?? 12;
  
  if (user != null) {
    final creationTime = user.metadata.creationTime ?? DateTime.now();
    final daysActive = DateTime.now().difference(creationTime).inDays;
    return UserProfile(
      uid: user.uid,
      displayName: user.displayName ?? 'BayMax User',
      email: user.email ?? 'user@BayMax.app',
      photoUrl: user.photoURL,
      incidentsReported: incidentsCount,
      alertsSubscribed: 8,
      daysActive: daysActive > 0 ? daysActive : 1,
    );
  }
  return UserProfile(
    uid: 'demo',
    displayName: 'BayMax User',
    email: 'user@BayMax.app',
    incidentsReported: incidentsCount,
    alertsSubscribed: 8,
    daysActive: 47,
  );
});

// Emergency subscription toggles
final weatherSubProvider = StateProvider<bool>((ref) => true);
final floodSubProvider = StateProvider<bool>((ref) => true);
final fireSubProvider = StateProvider<bool>((ref) => false);
final medicalSubProvider = StateProvider<bool>((ref) => true);
final infraSubProvider = StateProvider<bool>((ref) => false);

// Notification settings
final pushNotifProvider = StateProvider<bool>((ref) => true);
final emailAlertProvider = StateProvider<bool>((ref) => false);
final smsAlertProvider = StateProvider<bool>((ref) => false);
final alertRadiusProvider = StateProvider<double>((ref) => 25.0);

// ─── Screen ───────────────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final incidentsAsync = ref.watch(incidentHistoryProvider);

    return Scaffold(
      backgroundColor: _kPrimary,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ─────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: _kSurface,
            expandedHeight: 0,
            pinned: true,
            title: Text(
              'Profile',
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            centerTitle: false,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Profile Header ──────────────────────────────────
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: 24),

                  // ── Stats Row ───────────────────────────────────────
                  _StatsRow(profile: profile),
                  const SizedBox(height: 28),

                  // ── Emergency Subscriptions ─────────────────────────
                  _buildSectionTitle('Emergency Subscriptions'),
                  const SizedBox(height: 12),
                  _EmergencySubscriptionsCard(),
                  const SizedBox(height: 24),

                  // ── Notification Settings ───────────────────────────
                  _buildSectionTitle('Notification Settings'),
                  const SizedBox(height: 12),
                  _NotificationSettingsCard(),
                  const SizedBox(height: 24),

                  // ── Incident History ────────────────────────────────
                  _buildSectionTitle('Incident History'),
                  const SizedBox(height: 12),
                  _IncidentHistoryCard(incidentsAsync: incidentsAsync),
                  const SizedBox(height: 24),

                  // ── App Info ────────────────────────────────────────
                  _buildSectionTitle('App Info'),
                  const SizedBox(height: 12),
                  _AppInfoCard(),
                  const SizedBox(height: 24),

                  // ── Logout Button ───────────────────────────────────
                  _LogoutButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}

// ─── Profile Header ─────────────────────────────────────────────────────────
class _ProfileHeader extends ConsumerWidget {
  final UserProfile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial =
        profile.displayName.isNotEmpty
            ? profile.displayName[0].toUpperCase()
            : 'U';
    final isSyncing = ref.watch(syncProgressProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: _kAccentAmber.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kAccentAmber, _kAccentAmber.withValues(alpha: 0.7)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _kAccentAmber.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.urbanist(
                  color: _kPrimary,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            profile.displayName,
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),

          // Email
          Text(
            profile.email,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Action Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Edit Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Profile editing coming soon',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: _kSurface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kAccentAmber,
                    side: BorderSide(color: _kAccentAmber.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(
                    'Edit Profile',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Update Data Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isSyncing
                      ? null
                      : () async {
                          ref.read(syncProgressProvider.notifier).state = true;
                          try {
                            final apiService = ref.read(apiServiceProvider);
                            final response = await apiService.triggerFetchAll();
                            
                            if (context.mounted) {
                              if (response.isSuccess) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: _kSuccessTeal),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'System database updated with latest AI & IoT sources!',
                                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: _kCardBg,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: Colors.white10),
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: _kAccentAmber),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Offline simulation updated successfully!',
                                            style: GoogleFonts.inter(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: _kCardBg,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: Colors.white10),
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Offline simulation updated successfully!'),
                                  backgroundColor: _kCardBg,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          } finally {
                            // Always increment the trigger to refresh the list, even on mock/offline fallback
                            ref.read(refreshTriggerProvider.notifier).update((state) => state + 1);
                            ref.read(syncProgressProvider.notifier).state = false;
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccentAmber,
                    foregroundColor: _kPrimary,
                    disabledBackgroundColor: _kAccentAmber.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 4,
                    shadowColor: _kAccentAmber.withValues(alpha: 0.3),
                  ),
                  icon: isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(_kPrimary),
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(
                    isSyncing ? 'Updating...' : 'Update Data',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ──────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final UserProfile profile;

  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
          children: [
            _StatItem(
              value: '${profile.incidentsReported}',
              label: 'Incidents\nReported',
              icon: Icons.report_rounded,
              color: _kEmergencyRed,
            ),
            const SizedBox(width: 12),
            _StatItem(
              value: '${profile.alertsSubscribed}',
              label: 'Alerts\nSubscribed',
              icon: Icons.notifications_active_rounded,
              color: _kAccentAmber,
            ),
            const SizedBox(width: 12),
            _StatItem(
              value: '${profile.daysActive}',
              label: 'Days\nActive',
              icon: Icons.calendar_today_rounded,
              color: _kSuccessTeal,
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 150.ms)
        .slideY(begin: 0.1, end: 0);
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.urbanist(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
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

// ─── Emergency Subscriptions ────────────────────────────────────────────────
class _EmergencySubscriptionsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _SubscriptionTile(
                title: 'Weather Alerts',
                subtitle: 'Storms, extreme temperatures, wind advisories',
                icon: Icons.thunderstorm_rounded,
                iconColor: Colors.blueAccent,
                provider: weatherSubProvider,
              ),
              const Divider(color: Colors.white10, height: 1, indent: 60),
              _SubscriptionTile(
                title: 'Flood Warnings',
                subtitle: 'Flash floods, river overflow, coastal surge',
                icon: Icons.water_rounded,
                iconColor: Colors.lightBlue,
                provider: floodSubProvider,
              ),
              const Divider(color: Colors.white10, height: 1, indent: 60),
              _SubscriptionTile(
                title: 'Fire Alerts',
                subtitle: 'Wildfires, building fires, smoke advisories',
                icon: Icons.local_fire_department_rounded,
                iconColor: Colors.orangeAccent,
                provider: fireSubProvider,
              ),
              const Divider(color: Colors.white10, height: 1, indent: 60),
              _SubscriptionTile(
                title: 'Medical Emergencies',
                subtitle: 'Public health alerts, medical supply notices',
                icon: Icons.medical_services_rounded,
                iconColor: _kEmergencyRed,
                provider: medicalSubProvider,
              ),
              const Divider(color: Colors.white10, height: 1, indent: 60),
              _SubscriptionTile(
                title: 'Infrastructure',
                subtitle: 'Road closures, bridge damage, power outages',
                icon: Icons.construction_rounded,
                iconColor: _kAccentAmber,
                provider: infraSubProvider,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 250.ms)
        .slideY(begin: 0.1, end: 0);
  }
}

class _SubscriptionTile extends ConsumerWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final StateProvider<bool> provider;

  const _SubscriptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(provider);
    return SwitchListTile(
      value: isEnabled,
      onChanged: (val) => ref.read(provider.notifier).state = val,
      activeThumbColor: _kAccentAmber,
      inactiveTrackColor: Colors.white10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
      ),
    );
  }
}

// ─── Notification Settings ──────────────────────────────────────────────────
class _NotificationSettingsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pushEnabled = ref.watch(pushNotifProvider);
    final emailEnabled = ref.watch(emailAlertProvider);
    final smsEnabled = ref.watch(smsAlertProvider);
    final alertRadius = ref.watch(alertRadiusProvider);

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: pushEnabled,
            onChanged:
                (val) => ref.read(pushNotifProvider.notifier).state = val,
            activeThumbColor: _kAccentAmber,
            inactiveTrackColor: Colors.white10,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kAccentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.notifications_rounded,
                color: _kAccentAmber,
                size: 20,
              ),
            ),
            title: Text(
              'Push Notifications',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Receive real-time push notifications',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
            ),
          ),
          const Divider(color: Colors.white10, height: 1, indent: 60),
          SwitchListTile(
            value: emailEnabled,
            onChanged:
                (val) => ref.read(emailAlertProvider.notifier).state = val,
            activeThumbColor: _kAccentAmber,
            inactiveTrackColor: Colors.white10,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.email_rounded,
                color: Colors.blueAccent,
                size: 20,
              ),
            ),
            title: Text(
              'Email Alerts',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Receive alert summaries via email',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
            ),
          ),
          const Divider(color: Colors.white10, height: 1, indent: 60),
          SwitchListTile(
            value: smsEnabled,
            onChanged: (val) => ref.read(smsAlertProvider.notifier).state = val,
            activeThumbColor: _kAccentAmber,
            inactiveTrackColor: Colors.white10,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kSuccessTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sms_rounded,
                color: _kSuccessTeal,
                size: 20,
              ),
            ),
            title: Text(
              'SMS Alerts',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Receive critical alerts via SMS',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
            ),
          ),
          const Divider(color: Colors.white10, height: 1, indent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: Colors.purpleAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alert Radius',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Receive alerts within ${alertRadius.toInt()} km radius',
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
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kAccentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${alertRadius.toInt()} km',
                    style: GoogleFonts.inter(
                      color: _kAccentAmber,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _kAccentAmber,
                inactiveTrackColor: Colors.white10,
                thumbColor: _kAccentAmber,
                overlayColor: _kAccentAmber.withValues(alpha: 0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: alertRadius,
                min: 5,
                max: 100,
                divisions: 19,
                onChanged:
                    (val) => ref.read(alertRadiusProvider.notifier).state = val,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 350.ms).slideY(begin: 0.1, end: 0);
  }
}

// ─── Incident History ───────────────────────────────────────────────────────
class _IncidentHistoryCard extends StatelessWidget {
  final AsyncValue<List<IncidentHistoryItem>> incidentsAsync;

  const _IncidentHistoryCard({required this.incidentsAsync});

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return _kSuccessTeal;
      case 'medium':
        return _kAccentAmber;
      case 'high':
        return _kEmergencyRed;
      case 'critical':
        return const Color(0xFF9B1B30);
      default:
        return _kAccentAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return incidentsAsync.when(
      data: (incidents) {
        if (incidents.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text(
                'No incidents logged yet.',
                style: GoogleFonts.inter(color: Colors.white38),
              ),
            ),
          )
          .animate()
          .fadeIn(duration: 500.ms, delay: 450.ms)
          .slideY(begin: 0.1, end: 0);
        }

        return Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: incidents.asMap().entries.map((entry) {
              final idx = entry.key;
              final incident = entry.value;
              final sevColor = _severityColor(incident.severity);
              final isLast = idx == incidents.length - 1;

              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: _kSurface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (ctx) => _IncidentDetailSheet(incident: incident),
                      );
                    },
                    borderRadius: BorderRadius.vertical(
                      top: idx == 0 ? const Radius.circular(16) : Radius.zero,
                      bottom: isLast ? const Radius.circular(16) : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: sevColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              incident.typeIcon,
                              color: sevColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  incident.title,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('MMM d, yyyy').format(incident.date),
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
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: sevColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              incident.severity.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: sevColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white24,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      color: Colors.white10,
                      height: 1,
                      indent: 60,
                    ),
                ],
              );
            }).toList(),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 450.ms)
        .slideY(begin: 0.1, end: 0);
      },
      loading: () => Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: _kAccentAmber),
        ),
      )
      .animate()
      .fadeIn(duration: 500.ms),
      error: (err, stack) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Text(
            'Failed to load incident history',
            style: GoogleFonts.inter(color: _kEmergencyRed, fontWeight: FontWeight.bold),
          ),
        ),
      )
      .animate()
      .fadeIn(duration: 500.ms),
    );
  }
}

// ─── Incident Detail Sheet ──────────────────────────────────────────────────
class _IncidentDetailSheet extends StatelessWidget {
  final IncidentHistoryItem incident;

  const _IncidentDetailSheet({required this.incident});

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return _kSuccessTeal;
      case 'medium':
        return _kAccentAmber;
      case 'high':
        return _kEmergencyRed;
      case 'critical':
        return const Color(0xFF9B1B30);
      default:
        return _kAccentAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sevColor = _severityColor(incident.severity);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: sevColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(incident.typeIcon, color: sevColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${incident.type} · ${DateFormat('MMMM d, yyyy').format(incident.date)}',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Severity: ',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: sevColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        incident.severity.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: sevColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'This incident was reported and logged in the BayMax system. '
                  'Emergency response teams were notified and appropriate actions '
                  'were taken based on the severity assessment.',
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── App Info Card ──────────────────────────────────────────────────────────
class _AppInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.info_outline_rounded,
            iconColor: _kAccentAmber,
            title: 'Version',
            trailing: Text(
              '1.0.0',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
            ),
          ),
          const Divider(color: Colors.white10, height: 1, indent: 60),
          _InfoTile(
            icon: Icons.description_outlined,
            iconColor: Colors.blueAccent,
            title: 'Terms of Service',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Terms of Service',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  backgroundColor: _kSurface,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white10, height: 1, indent: 60),
          _InfoTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: _kSuccessTeal,
            title: 'Privacy Policy',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Privacy Policy',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  backgroundColor: _kSurface,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white10, height: 1, indent: 60),
          _InfoTile(
            icon: Icons.favorite_outline_rounded,
            iconColor: _kEmergencyRed,
            title: 'About BayMax',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'BayMax',
                applicationVersion: '1.0.0',
                applicationIcon: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _kAccentAmber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.crisis_alert_rounded,
                    color: _kPrimary,
                    size: 28,
                  ),
                ),
                children: [
                  Text(
                    'BayMax is an AI-assisted emergency operations and public safety application designed to help communities prepare for, respond to, and recover from crisis situations.',
                    style: GoogleFonts.inter(fontSize: 13, height: 1.5),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 550.ms).slideY(begin: 0.1, end: 0);
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing:
          trailing ??
          const Icon(Icons.chevron_right_rounded, color: Colors.white24),
    );
  }
}

// ─── Logout Button ──────────────────────────────────────────────────────────
class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => _showLogoutDialog(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kEmergencyRed,
              side: BorderSide(color: _kEmergencyRed.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: Text(
              'Logout',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 650.ms)
        .slideY(begin: 0.1, end: 0);
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: _kSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Logout',
              style: GoogleFonts.urbanist(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'Are you sure you want to logout? You will need to sign in again to access your profile and settings.',
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await ref.read(authServiceProvider).logout();
                  if (context.mounted) {
                    context.go('/auth');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kEmergencyRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Logout',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }
}
