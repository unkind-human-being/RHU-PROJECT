import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';

class IphoDashboardScreen extends StatelessWidget {
  const IphoDashboardScreen({super.key});

  static const String routeName = '/ipho-dashboard';

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

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'IPHO Dashboard',
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
              email: authProvider.user?.email ?? 'IPHO Admin',
              assignedLocation: authProvider.assignedLocation,
            ),
            const SizedBox(height: 18),
            const _SectionTitle(
              title: 'Province-wide Management',
              subtitle:
                  'Manage RHU users, health updates, medicine supply, and monitoring tools.',
            ),
            const SizedBox(height: 12),
            _DashboardActionCard(
              title: 'Medicine Monitor',
              subtitle: 'Check medicine stock by RHU and barangay.',
              icon: Icons.monitor_heart_rounded,
              onTap: () {
                _open(context, '/medicine-monitor');
              },
            ),
            _DashboardGrid(
              children: <Widget>[
                _DashboardActionCard(
                  title: 'User Accounts',
                  subtitle: 'Create, activate, deactivate, or delete users.',
                  icon: Icons.groups_rounded,
                  onTap: () {
                    _open(context, '/users');
                  },
                ),
                _DashboardActionCard(
                  title: 'Medicine Inventory',
                  subtitle: 'View all medicine stock records.',
                  icon: Icons.inventory_2_rounded,
                  onTap: () {
                    _open(context, '/medicines');
                  },
                ),
                _DashboardActionCard(
                  title: 'Add Medicine',
                  subtitle: 'Create a new medicine stock record.',
                  icon: Icons.add_box_rounded,
                  onTap: () {
                    _open(context, '/add-medicine');
                  },
                ),
                _DashboardActionCard(
                  title: 'Transactions',
                  subtitle: 'View medicine transaction history.',
                  icon: Icons.receipt_long_rounded,
                  onTap: () {
                    _open(context, '/medicine-transactions');
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle(
              title: 'Health Updates',
              subtitle:
                  'Manage public posts, health events, and community surveys.',
            ),
            const SizedBox(height: 12),
            _DashboardGrid(
              children: <Widget>[
                _DashboardActionCard(
                  title: 'Public Updates',
                  subtitle: 'See the public health updates page.',
                  icon: Icons.campaign_rounded,
                  onTap: () {
                    _open(context, '/public');
                  },
                ),
                _DashboardActionCard(
                  title: 'Manage Posts',
                  subtitle: 'Create, edit, and delete announcements.',
                  icon: Icons.article_rounded,
                  onTap: () {
                    _open(context, '/manage-posts');
                  },
                ),
                _DashboardActionCard(
                  title: 'Manage Events',
                  subtitle: 'Create, edit, and delete health events.',
                  icon: Icons.event_rounded,
                  onTap: () {
                    _open(context, '/manage-events');
                  },
                ),
                _DashboardActionCard(
                  title: 'Manage Surveys',
                  subtitle: 'Create, edit, and delete community surveys.',
                  icon: Icons.fact_check_rounded,
                  onTap: () {
                    _open(context, '/manage-surveys');
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle(
              title: 'System Tools',
              subtitle: 'Check profile, sync queue, and system readiness.',
            ),
            const SizedBox(height: 12),
            _DashboardGrid(
              children: <Widget>[
                _DashboardActionCard(
                  title: 'Sync Center',
                  subtitle: 'Check offline queue and backend sync status.',
                  icon: Icons.sync_rounded,
                  onTap: () {
                    _open(context, '/sync');
                  },
                ),
                _DashboardActionCard(
                  title: 'Profile',
                  subtitle: 'View account and system information.',
                  icon: Icons.person_rounded,
                  onTap: () {
                    _open(context, '/profile');
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
            Color(0xFF0F766E),
            Color(0xFF115E59),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.18),
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
              'IA',
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
                  'IPHO System Administrator',
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
                    color: Color(0xFFE0F2F1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: Color(0xFFE0F2F1),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        assignedLocation,
                        style: const TextStyle(
                          color: Color(0xFFE0F2F1),
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
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF0F766E),
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