import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import 'profile_identity_resolver.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const String routeName = '/profile';

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

  void _openRoute(
    BuildContext context,
    String routeName,
  ) {
    try {
      Navigator.of(context).pushNamed(routeName);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This shortcut is not available yet: $routeName'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _showHelpSheet(BuildContext context, ProfileUserTypeInfo roleInfo) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _HelpSheet(roleInfo: roleInfo);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (
        BuildContext context,
        AuthProvider authProvider,
        Widget? child,
      ) {
        final user = authProvider.user;

        final ProfileUserTypeInfo roleInfo =
            ProfileIdentityResolver.userTypeInfo(authProvider.userRole);

        final List<ProfileShortcutInfo> shortcuts =
            ProfileIdentityResolver.shortcutsForRole(authProvider.userRole);

        return Scaffold(
          backgroundColor: const Color(0xFFF6FAF9),
          appBar: AppBar(
            title: const Text(
              'Profile',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Help',
                onPressed: () {
                  _showHelpSheet(context, roleInfo);
                },
                icon: const Icon(Icons.help_outline_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                _ProfileHero(
                  name: authProvider.userDisplayName,
                  email: user?.email ?? 'No email',
                  role: authProvider.userRole,
                  location: authProvider.assignedLocation,
                  initials: user?.initials ?? 'U',
                  roleInfo: roleInfo,
                ),
                const SizedBox(height: 18),
                _QuickActionsCard(
                  shortcuts: shortcuts,
                  onOpenRoute: (String routeName) {
                    _openRoute(context, routeName);
                  },
                ),
                const SizedBox(height: 18),
                _AccountCard(
                  fullName: user?.fullName ?? 'Unknown',
                  email: user?.email ?? 'Unknown',
                  roleInfo: roleInfo,
                  systemRole: authProvider.userRole,
                  assignedLocation: authProvider.assignedLocation,
                ),
                const SizedBox(height: 18),
                _HelpCard(
                  roleInfo: roleInfo,
                  onTap: () {
                    _showHelpSheet(context, roleInfo);
                  },
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(
                      color: Color(0xFFFCA5A5),
                    ),
                  ),
                  onPressed: () {
                    _logout(context);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.role,
    required this.location,
    required this.initials,
    required this.roleInfo,
  });

  final String name;
  final String email;
  final String role;
  final String location;
  final String initials;
  final ProfileUserTypeInfo roleInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            roleInfo.color,
            const Color(0xFF0F172A),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: roleInfo.color.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          RhuProfileAvatar(
            location: location,
            initials: initials,
            roleInfo: roleInfo,
            role: role,
            size: 118,
          ),
          const SizedBox(height: 16),
          Text(
            name.trim().isEmpty ? 'User' : name.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE0F2F1),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _HeroBadge(
                icon: roleInfo.icon,
                label: roleInfo.label,
              ),
              _HeroBadge(
                icon: Icons.location_on_rounded,
                label: location.trim().isEmpty ? 'No location' : location,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final String safeLabel = label.trim().isEmpty ? 'N/A' : label.trim();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              safeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.shortcuts,
    required this.onOpenRoute,
  });

  final List<ProfileShortcutInfo> shortcuts;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    if (shortcuts.isEmpty) {
      return const SizedBox.shrink();
    }

    return _ProfileSection(
      title: 'Quick Actions',
      subtitle: 'Open your most important tools quickly.',
      child: Column(
        children: shortcuts.map((ProfileShortcutInfo shortcut) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ShortcutTile(
              shortcut: shortcut,
              onTap: () {
                onOpenRoute(shortcut.routeName);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.shortcut,
    required this.onTap,
  });

  final ProfileShortcutInfo shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: shortcut.color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: shortcut.color.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: shortcut.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  shortcut.icon,
                  color: shortcut.color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      shortcut.title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shortcut.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: shortcut.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.fullName,
    required this.email,
    required this.roleInfo,
    required this.systemRole,
    required this.assignedLocation,
  });

  final String fullName;
  final String email;
  final ProfileUserTypeInfo roleInfo;
  final String systemRole;
  final String assignedLocation;

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'Account',
      subtitle: 'Your basic account information.',
      child: Column(
        children: <Widget>[
          _InfoTile(
            icon: Icons.person_rounded,
            label: 'Full Name',
            value: fullName,
          ),
          _InfoTile(
            icon: Icons.email_rounded,
            label: 'Email',
            value: email,
          ),
          _InfoTile(
            icon: roleInfo.icon,
            label: 'Account Type',
            value: roleInfo.label,
          ),
          _InfoTile(
            icon: Icons.verified_user_rounded,
            label: 'System Role',
            value: systemRole,
          ),
          _InfoTile(
            icon: Icons.location_on_rounded,
            label: 'Assigned Location',
            value: assignedLocation,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.roleInfo,
    required this.onTap,
  });

  final ProfileUserTypeInfo roleInfo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'Help',
      subtitle: 'Guides and support for your account.',
      child: Column(
        children: <Widget>[
          Material(
            color: roleInfo.color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: roleInfo.color.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: roleInfo.color.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        Icons.support_agent_rounded,
                        color: roleInfo.color,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Need help?',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'View simple instructions for using this account.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: roleInfo.color,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 19,
                fontWeight: FontWeight.w900,
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
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final String safeValue = value.trim().isEmpty ? 'N/A' : value.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF0F766E),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  safeValue,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet({
    required this.roleInfo,
  });

  final ProfileUserTypeInfo roleInfo;

  @override
  Widget build(BuildContext context) {
    final List<String> tips = _tipsForRole(roleInfo.key);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.38,
      maxChildSize: 0.92,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(22),
            children: <Widget>[
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: roleInfo.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      roleInfo.icon,
                      color: roleInfo.color,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${roleInfo.label} Help',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                roleInfo.description,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              ...tips.map((String tip) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HelpTip(
                    text: tip,
                    color: roleInfo.color,
                  ),
                );
              }),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: roleInfo.color,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Got it'),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _tipsForRole(String roleKey) {
    switch (roleKey) {
      case 'rhu_admin':
        return const <String>[
          'Use Manage Appointments to accept, reject, or complete consultation requests.',
          'Open Consultation Chat from accepted appointments to message the patient, start video calls, or send prescription QR.',
          'Use Prescription Claims to track if the patient already claimed the medicine from the pharmacy.',
          'Use Appointment Settings to control whether your RHU accepts walk-in or online consultations.',
        ];

      case 'pharmacist':
        return const <String>[
          'Use Prescription Claims to scan the patient prescription QR.',
          'Review the patient and medicine details before claiming the prescription.',
          'If the internet is unavailable, claims can be saved offline and synced later.',
        ];

      case 'bhw':
        return const <String>[
          'Use Medicine Monitor to check available barangay medicine stocks.',
          'Use Record Transaction when medicines are received, dispensed, or adjusted.',
          'Use Sync Center only when you need to check pending offline records.',
        ];

      case 'ipho_admin':
        return const <String>[
          'Use your admin tools to monitor RHU activity and system records.',
          'Check users, RHU directory, and notifications regularly.',
          'Coordinate with RHU admins for appointment and health update concerns.',
        ];

      case 'public_user':
      default:
        return const <String>[
          'Use Apply Appointment to request a walk-in or online RHU consultation.',
          'Use My Appointments to check if your request is pending, accepted, or completed.',
          'Use Messages to receive RHU instructions, video call notices, and prescription QR codes.',
          'Use Notifications to check QR tickets, appointment updates, and prescription notices.',
        ];
    }
  }
}

class _HelpTip extends StatelessWidget {
  const _HelpTip({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.check_circle_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF334155),
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}