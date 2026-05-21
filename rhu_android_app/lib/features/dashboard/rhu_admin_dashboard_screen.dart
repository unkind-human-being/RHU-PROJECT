import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../notifications/widgets/notification_badge_button.dart';

class RhuAdminDashboardScreen extends StatelessWidget {
  const RhuAdminDashboardScreen({super.key});

  static const String routeName = '/rhu-admin-dashboard';

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

    final String displayName = authProvider.userDisplayName;
    final String email = authProvider.user?.email ?? 'RHU Admin';
    final String assignedLocation = authProvider.assignedLocation;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF047857),
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: const Text(
          'RHU Admin Center',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        actions: <Widget>[
          const NotificationBadgeButton(
            iconColor: Colors.white,
          ),
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
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _TopHeroSection(
                displayName: displayName,
                email: email,
                assignedLocation: assignedLocation,
                onOpenProfile: () {
                  _open(context, '/profile');
                },
                onOpenNotifications: () {
                  _open(context, '/notifications');
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _PriorityActions(
                  onOpenAppointments: () {
                    _open(context, '/manage-appointments');
                  },
                  onOpenPatientView: () {
                    _open(context, '/patient-view');
                  },
                  onOpenMedicineMonitor: () {
                    _open(context, '/medicine-monitor');
                  },
                  onOpenPrescriptionClaims: () {
                    _open(context, '/prescription-claim-monitor');
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: _SectionHeader(
                  title: 'Today’s RHU Workflow',
                  subtitle:
                      'Fast access to the most-used tools for consultations, QR tickets, medicine, and pharmacy coordination.',
                  icon: Icons.dashboard_customize_rounded,
                  color: const Color(0xFF047857),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _FeatureGrid(
                  children: <Widget>[
                    _FeatureCard(
                      title: 'Appointments',
                      subtitle: 'Review, schedule, accept, or reject patient requests.',
                      icon: Icons.event_available_rounded,
                      color: const Color(0xFF0EA5E9),
                      badge: 'Core',
                      onTap: () {
                        _open(context, '/manage-appointments');
                      },
                    ),
                    _FeatureCard(
                      title: 'Patient View',
                      subtitle: 'Open walk-in and online consultation patient records.',
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF2563EB),
                      badge: 'Clinical',
                      onTap: () {
                        _open(context, '/patient-view');
                      },
                    ),
                    _FeatureCard(
                      title: 'Appointment Settings',
                      subtitle: 'Control walk-in, online, available days, and schedule status.',
                      icon: Icons.tune_rounded,
                      color: const Color(0xFF7C3AED),
                      badge: 'Control',
                      onTap: () {
                        _open(context, '/appointment-settings');
                      },
                    ),
                    _FeatureCard(
                      title: 'Scan Appointment QR',
                      subtitle: 'Check in walk-in patients using their QR ticket.',
                      icon: Icons.qr_code_scanner_rounded,
                      color: const Color(0xFFF59E0B),
                      badge: 'Walk-in',
                      onTap: () {
                        _open(context, '/appointment-qr-check-in');
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _SectionHeader(
                  title: 'Medicine & Pharmacy',
                  subtitle:
                      'Manage stock records, transactions, prescription QR codes, and pharmacy claims.',
                  icon: Icons.medication_liquid_rounded,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _FeatureGrid(
                  children: <Widget>[
                    _FeatureCard(
                      title: 'Medicine Monitor',
                      subtitle: 'Check stock levels across barangays under your RHU.',
                      icon: Icons.monitor_heart_rounded,
                      color: const Color(0xFF16A34A),
                      badge: 'Monitor',
                      onTap: () {
                        _open(context, '/medicine-monitor');
                      },
                    ),
                    _FeatureCard(
                      title: 'Medicine Inventory',
                      subtitle: 'View medicine stock records for your assigned RHU.',
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF059669),
                      badge: 'Stock',
                      onTap: () {
                        _open(context, '/medicines');
                      },
                    ),
                    _FeatureCard(
                      title: 'Add Medicine',
                      subtitle: 'Create a new medicine stock record.',
                      icon: Icons.add_box_rounded,
                      color: const Color(0xFF10B981),
                      badge: 'Create',
                      onTap: () {
                        _open(context, '/add-medicine');
                      },
                    ),
                    _FeatureCard(
                      title: 'Record Transaction',
                      subtitle: 'Record received, dispensed, or adjusted stock.',
                      icon: Icons.add_task_rounded,
                      color: const Color(0xFF047857),
                      badge: 'Log',
                      onTap: () {
                        _open(context, '/record-transaction');
                      },
                    ),
                    _FeatureCard(
                      title: 'Transaction History',
                      subtitle: 'Review medicine movement and stock changes.',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF0F766E),
                      badge: 'History',
                      onTap: () {
                        _open(context, '/medicine-transactions');
                      },
                    ),
                    _FeatureCard(
                      title: 'Prescription Claims',
                      subtitle: 'Track prescription QR status and pharmacy claims.',
                      icon: Icons.local_pharmacy_rounded,
                      color: const Color(0xFF15803D),
                      badge: 'Claims',
                      onTap: () {
                        _open(context, '/prescription-claim-monitor');
                      },
                    ),
                    _FeatureCard(
                      title: 'Create Prescription QR',
                      subtitle: 'Generate prescription QR for medicine claim.',
                      icon: Icons.qr_code_2_rounded,
                      color: const Color(0xFF22C55E),
                      badge: 'QR',
                      onTap: () {
                        _open(context, '/create-prescription');
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _SectionHeader(
                  title: 'Public Health Updates',
                  subtitle:
                      'Publish announcements, manage events, collect survey responses, and monitor public activity.',
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _FeatureGrid(
                  children: <Widget>[
                    _FeatureCard(
                      title: 'Public Updates',
                      subtitle: 'View posts, events, and surveys as residents see them.',
                      icon: Icons.public_rounded,
                      color: const Color(0xFF0EA5E9),
                      badge: 'Preview',
                      onTap: () {
                        _open(context, '/public');
                      },
                    ),
                    _FeatureCard(
                      title: 'Manage Posts',
                      subtitle: 'Create, edit, and delete public announcements.',
                      icon: Icons.article_rounded,
                      color: const Color(0xFF2563EB),
                      badge: 'Posts',
                      onTap: () {
                        _open(context, '/manage-posts');
                      },
                    ),
                    _FeatureCard(
                      title: 'Manage Events',
                      subtitle: 'Create, edit, and publish RHU events.',
                      icon: Icons.event_rounded,
                      color: const Color(0xFF9333EA),
                      badge: 'Events',
                      onTap: () {
                        _open(context, '/manage-events');
                      },
                    ),
                    _FeatureCard(
                      title: 'Manage Surveys',
                      subtitle: 'Create, edit, and publish community surveys.',
                      icon: Icons.fact_check_rounded,
                      color: const Color(0xFF7C3AED),
                      badge: 'Surveys',
                      onTap: () {
                        _open(context, '/manage-surveys');
                      },
                    ),
                    _FeatureCard(
                      title: 'Event Registrants',
                      subtitle: 'View and manage public event registrations.',
                      icon: Icons.how_to_reg_rounded,
                      color: const Color(0xFF0891B2),
                      badge: 'People',
                      onTap: () {
                        _open(context, '/event-registrants');
                      },
                    ),
                    _FeatureCard(
                      title: 'Survey Responses',
                      subtitle: 'View public survey answers and feedback.',
                      icon: Icons.poll_rounded,
                      color: const Color(0xFF6366F1),
                      badge: 'Feedback',
                      onTap: () {
                        _open(context, '/survey-responses');
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _SectionHeader(
                  title: 'Accounts & System',
                  subtitle:
                      'Manage staff accounts, notifications, sync, and your RHU administrator profile.',
                  icon: Icons.settings_suggest_rounded,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
                child: _FeatureGrid(
                  children: <Widget>[
                    _FeatureCard(
                      title: 'Health Workers',
                      subtitle: 'Create and manage barangay health worker accounts.',
                      icon: Icons.groups_2_rounded,
                      color: const Color(0xFF0F766E),
                      badge: 'Users',
                      onTap: () {
                        _open(context, '/users');
                      },
                    ),
                    _FeatureCard(
                      title: 'Notifications',
                      subtitle: 'View appointment, QR, survey, event, and pharmacy notices.',
                      icon: Icons.notifications_active_rounded,
                      color: const Color(0xFFEF4444),
                      badge: 'Alerts',
                      onTap: () {
                        _open(context, '/notifications');
                      },
                    ),
                    _FeatureCard(
                      title: 'Sync Center',
                      subtitle: 'Check offline queue and backend connection status.',
                      icon: Icons.sync_rounded,
                      color: const Color(0xFF64748B),
                      badge: 'System',
                      onTap: () {
                        _open(context, '/sync');
                      },
                    ),
                    _FeatureCard(
                      title: 'Profile',
                      subtitle: 'View account and assigned RHU information.',
                      icon: Icons.person_rounded,
                      color: const Color(0xFF334155),
                      badge: 'Account',
                      onTap: () {
                        _open(context, '/profile');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopHeroSection extends StatelessWidget {
  const _TopHeroSection({
    required this.displayName,
    required this.email,
    required this.assignedLocation,
    required this.onOpenProfile,
    required this.onOpenNotifications,
  });

  final String displayName;
  final String email;
  final String assignedLocation;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF047857),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          children: <Widget>[
            _HeaderCard(
              displayName: displayName,
              email: email,
              assignedLocation: assignedLocation,
              onOpenProfile: onOpenProfile,
              onOpenNotifications: onOpenNotifications,
            ),
            const SizedBox(height: 16),
            const _OperationalStatusCard(),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.displayName,
    required this.email,
    required this.assignedLocation,
    required this.onOpenProfile,
    required this.onOpenNotifications,
  });

  final String displayName;
  final String email;
  final String assignedLocation;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;

  String get _initials {
    final List<String> parts = displayName
        .trim()
        .split(' ')
        .where((String item) => item.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'RA';
    }

    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }

    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              _initials,
              style: const TextStyle(
                color: Color(0xFF047857),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD1FAE5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.local_hospital_rounded,
                      color: Color(0xFFD1FAE5),
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        assignedLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD1FAE5),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: <Widget>[
              _HeroIconButton(
                tooltip: 'Profile',
                icon: Icons.person_rounded,
                onTap: onOpenProfile,
              ),
              const SizedBox(height: 8),
              _HeroIconButton(
                tooltip: 'Notifications',
                icon: Icons.notifications_rounded,
                onTap: onOpenNotifications,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 23,
          ),
        ),
      ),
    );
  }
}

class _OperationalStatusCard extends StatelessWidget {
  const _OperationalStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Row(
        children: <Widget>[
          _StatusPill(
            label: 'Portal',
            value: 'Online',
            icon: Icons.cloud_done_rounded,
            color: Color(0xFF16A34A),
          ),
          SizedBox(width: 10),
          _StatusPill(
            label: 'Mode',
            value: 'Admin',
            icon: Icons.admin_panel_settings_rounded,
            color: Color(0xFF0EA5E9),
          ),
          SizedBox(width: 10),
          _StatusPill(
            label: 'Scope',
            value: 'RHU',
            icon: Icons.local_hospital_rounded,
            color: Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: color.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          children: <Widget>[
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityActions extends StatelessWidget {
  const _PriorityActions({
    required this.onOpenAppointments,
    required this.onOpenPatientView,
    required this.onOpenMedicineMonitor,
    required this.onOpenPrescriptionClaims,
  });

  final VoidCallback onOpenAppointments;
  final VoidCallback onOpenPatientView;
  final VoidCallback onOpenMedicineMonitor;
  final VoidCallback onOpenPrescriptionClaims;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(
          title: 'Priority Actions',
          subtitle: 'Start with the work RHU staff usually need first.',
          icon: Icons.bolt_rounded,
          color: Color(0xFFF59E0B),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final bool wide = constraints.maxWidth >= 760;
            final double itemWidth =
                wide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _PriorityCard(
                  title: 'Appointments',
                  subtitle: 'Review requests',
                  icon: Icons.event_available_rounded,
                  color: const Color(0xFF0EA5E9),
                  width: itemWidth,
                  onTap: onOpenAppointments,
                ),
                _PriorityCard(
                  title: 'Patients',
                  subtitle: 'Consultation view',
                  icon: Icons.personal_injury_rounded,
                  color: const Color(0xFF2563EB),
                  width: itemWidth,
                  onTap: onOpenPatientView,
                ),
                _PriorityCard(
                  title: 'Medicine',
                  subtitle: 'Stock monitor',
                  icon: Icons.medication_rounded,
                  color: const Color(0xFF16A34A),
                  width: itemWidth,
                  onTap: onOpenMedicineMonitor,
                ),
                _PriorityCard(
                  title: 'Claims',
                  subtitle: 'Pharmacy QR',
                  icon: Icons.local_pharmacy_rounded,
                  color: const Color(0xFF9333EA),
                  width: itemWidth,
                  onTap: onOpenPrescriptionClaims,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.width,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withValues(alpha: 0.18),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 27,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: color,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
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
        final bool twoColumns = constraints.maxWidth >= 720;
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MiniBadge(
                          label: badge,
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.32,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}