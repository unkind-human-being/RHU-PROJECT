import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharmacist_dashboard_screen.dart';
import 'health_worker_dashboard_screen.dart';
import 'ipho_dashboard_screen.dart';
import 'rhu_admin_dashboard_screen.dart';


import '../auth/auth_provider.dart';
import '../public/social_health_updates_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const String routeName = '/dashboard';

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (
        BuildContext context,
        AuthProvider authProvider,
        Widget? child,
      ) {
        final String role = authProvider.user?.role ?? '';

        if (role == 'ipho_admin') {
          return const IphoDashboardScreen();
        }

        if (role == 'rhu_admin') {
          return const RhuAdminDashboardScreen();
        }

        if (role == 'barangay_health_worker') {
          return const HealthWorkerDashboardScreen();
        }

        if (role == 'pharmacist') {
          return const PharmacistDashboardScreen();
        }
        if (role == 'public_user') {
          return const SocialHealthUpdatesScreen();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFF59E0B),
                          size: 54,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Unknown Account Role',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This account does not have a supported dashboard role.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () async {
                            await authProvider.logout();

                            if (!context.mounted) {
                              return;
                            }

                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (Route<dynamic> route) => false,
                            );
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Logout'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}