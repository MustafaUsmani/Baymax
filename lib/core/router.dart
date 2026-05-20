import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crisis_link/features/auth/auth_screen.dart';
import 'package:crisis_link/features/dashboard/dashboard_screen.dart';
import 'package:crisis_link/features/maps/maps_screen.dart';
import 'package:crisis_link/features/incidents/create_incident_screen.dart';
import 'package:crisis_link/features/incidents/incident_detail_screen.dart';
import 'package:crisis_link/features/alerts/alerts_screen.dart';
import 'package:crisis_link/features/profile/profile_screen.dart';
import 'package:crisis_link/features/safety_monitor/safety_monitor_screen.dart';
import 'package:crisis_link/features/simulator/strategy_simulator_screen.dart';
import 'package:crisis_link/widgets/shell_screen.dart';
import 'package:crisis_link/services/auth_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Navigation Keys
// ──────────────────────────────────────────────────────────────────────────────

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorDashboardKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellDashboard');
final _shellNavigatorMapsKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellMaps');
final _shellNavigatorReportKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellReport');
final _shellNavigatorAlertsKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellAlerts');
final _shellNavigatorProfileKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellProfile');

// ──────────────────────────────────────────────────────────────────────────────
// Router Provider
// ──────────────────────────────────────────────────────────────────────────────

/// Provides a [GoRouter] instance that reacts to authentication state changes.
///
/// When the user signs out the router automatically redirects to `/auth`.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/auth',
    debugLogDiagnostics: true,

    // ── Redirect ──────────────────────────────────────────────────────────
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isOnAuth = state.matchedLocation == '/auth';

      // Not authenticated → force to /auth.
      if (!isAuthenticated && !isOnAuth) {
        return '/auth';
      }

      // Authenticated but still on /auth → go to dashboard.
      if (isAuthenticated && isOnAuth) {
        return '/dashboard';
      }

      return null; // no redirect needed
    },

    // ── Routes ────────────────────────────────────────────────────────────
    routes: [
      // Auth (full-screen, no shell).
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // ── Bottom-navigation shell ─────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state, navigationShell) {
          return ShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // 0 – Dashboard
          StatefulShellBranch(
            navigatorKey: _shellNavigatorDashboardKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: DashboardScreen(),
                ),
              ),
            ],
          ),

          // 1 – Maps
          StatefulShellBranch(
            navigatorKey: _shellNavigatorMapsKey,
            routes: [
              GoRoute(
                path: '/maps',
                name: 'maps',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MapsScreen(),
                ),
              ),
            ],
          ),

          // 2 – Report / Create Incident
          StatefulShellBranch(
            navigatorKey: _shellNavigatorReportKey,
            routes: [
              GoRoute(
                path: '/report',
                name: 'report',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: CreateIncidentScreen(),
                ),
              ),
            ],
          ),

          // 3 – Alerts
          StatefulShellBranch(
            navigatorKey: _shellNavigatorAlertsKey,
            routes: [
              GoRoute(
                path: '/alerts',
                name: 'alerts',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AlertsScreen(),
                ),
              ),
            ],
          ),

          // 4 – Profile
          StatefulShellBranch(
            navigatorKey: _shellNavigatorProfileKey,
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (pushed over the shell) ──────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/incident/:id',
        name: 'incidentDetail',
        builder: (context, state) {
          final incidentId = state.pathParameters['id']!;
          return IncidentDetailScreen(incidentId: incidentId);
        },
      ),

      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/safety-monitor',
        name: 'safetyMonitor',
        builder: (context, state) => const SafetyMonitorScreen(),
      ),

      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/simulator',
        name: 'simulator',
        builder: (context, state) => const StrategySimulatorScreen(),
      ),
    ],
  );
});
