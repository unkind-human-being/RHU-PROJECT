import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';

class PharmacistDashboardScreen extends StatelessWidget {
  const PharmacistDashboardScreen({super.key});

  static const String routeName = '/pharmacist-dashboard';

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (Route<dynamic> route) => false,
    );
  }

  void _open(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  void _comingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName will be added next.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pharmacy Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              _open(context, '/profile');
            },
            icon: const Icon(Icons.account_circle_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              _logout(context);
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            _HeaderCard(
              email: authProvider.user?.email ?? 'Pharmacist',
              assignedLocation: authProvider.assignedLocation,
            ),
            const SizedBox(height: 18),
            const _SectionTitle(
              title: 'Prescription QR',
              subtitle:
                  'Scan prescription QR codes, verify medicine claims, and sync pharmacy records.',
            ),
            const SizedBox(height: 12),
            _DashboardGrid(
              children: <Widget>[
                _DashboardActionCard(
                  title: 'Scan Prescription QR',
                  subtitle:
                      'Scan patient prescription QR and view prescribed medicines.',
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: () {
                    _open(context, '/pharmacist-prescription-scanner');
                  },
                ),
                _DashboardActionCard(
                  title: 'Claimed Records',
                  subtitle:
                      'View medicines already claimed using prescription QR.',
                  icon: Icons.fact_check_rounded,
                  onTap: () {
                    _open(context, '/pharmacist-claimed-prescriptions');
                  },
                ),
                _DashboardActionCard(
                  title: 'Offline Pharmacy Sync',
                  subtitle:
                      'Sync scanned prescription claims when internet returns.',
                  icon: Icons.sync_rounded,
                  onTap: () {
                    _comingSoon(context, 'Offline Pharmacy Sync');
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle(
              title: 'Account',
              subtitle: 'View your pharmacist account and assigned RHU.',
            ),
            const SizedBox(height: 12),
            _DashboardGrid(
              children: <Widget>[
                _DashboardActionCard(
                  title: 'Profile',
                  subtitle: 'View account and assigned RHU information.',
                  icon: Icons.person_rounded,
                  onTap: () {
                    _open(context, '/profile');
                  },
                ),
                _DashboardActionCard(
                  title: 'Public Updates',
                  subtitle: 'View RHU public posts, events, and surveys.',
                  icon: Icons.campaign_rounded,
                  onTap: () {
                    _open(context, '/public');
                  },
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.email,
    required this.assignedLocation,
  });

  final String email;
  final String assignedLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF7C3AED),
            Color(0xFF5B21B6),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: const Text(
              'PH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Pharmacist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  style: const TextStyle(
                    color: Color(0xFFEDE9FE),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.local_pharmacy_rounded,
                      size: 16,
                      color: Color(0xFFEDE9FE),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        assignedLocation,
                        style: const TextStyle(
                          color: Color(0xFFEDE9FE),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final bool twoColumns = constraints.maxWidth >= 620;
        final double itemWidth =
            twoColumns ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children.map((Widget child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF7C3AED),
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}