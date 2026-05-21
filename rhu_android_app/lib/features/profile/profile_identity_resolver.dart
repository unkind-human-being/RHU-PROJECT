import 'package:flutter/material.dart';

class ProfileUserTypeInfo {
  const ProfileUserTypeInfo({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class ProfileShortcutInfo {
  const ProfileShortcutInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeName,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String routeName;
  final Color color;
}

class ProfileIdentityResolver {
  const ProfileIdentityResolver._();

  static String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll('.', ' ')
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String roleKey(String role) {
    final String normalized = normalize(role);

    if (normalized.contains('ipho')) {
      return 'ipho_admin';
    }

    if (normalized.contains('rhu') && normalized.contains('admin')) {
      return 'rhu_admin';
    }

    if (normalized.contains('pharmacist')) {
      return 'pharmacist';
    }

    if (normalized.contains('bhw') ||
        normalized.contains('barangay health worker') ||
        normalized.contains('health worker')) {
      return 'bhw';
    }

    return 'public_user';
  }

  static ProfileUserTypeInfo userTypeInfo(String role) {
    switch (roleKey(role)) {
      case 'ipho_admin':
        return const ProfileUserTypeInfo(
          key: 'ipho_admin',
          label: 'IPHO Admin',
          description:
              'Provincial administrator account for monitoring RHUs, users, appointments, and health activities.',
          icon: Icons.admin_panel_settings_rounded,
          color: Color(0xFF7C3AED),
        );

      case 'rhu_admin':
        return const ProfileUserTypeInfo(
          key: 'rhu_admin',
          label: 'RHU Admin',
          description:
              'RHU staff account for managing appointments, patients, consultations, and public health updates.',
          icon: Icons.local_hospital_rounded,
          color: Color(0xFF0F766E),
        );

      case 'pharmacist':
        return const ProfileUserTypeInfo(
          key: 'pharmacist',
          label: 'Pharmacist',
          description:
              'Pharmacy account for scanning prescription QR codes and marking medicines as claimed.',
          icon: Icons.local_pharmacy_rounded,
          color: Color(0xFF7C3AED),
        );

      case 'bhw':
        return const ProfileUserTypeInfo(
          key: 'bhw',
          label: 'Barangay Health Worker',
          description:
              'BHW account for medicine monitoring, barangay health records, and offline transaction support.',
          icon: Icons.health_and_safety_rounded,
          color: Color(0xFF2563EB),
        );

      case 'public_user':
      default:
        return const ProfileUserTypeInfo(
          key: 'public_user',
          label: 'Public User',
          description:
              'Public account for viewing health updates, applying appointments, receiving messages, and checking QR notices.',
          icon: Icons.person_rounded,
          color: Color(0xFF0EA5E9),
        );
    }
  }

  static String? rhuProfileAsset(String location) {
    final String normalized = normalize(location);

    if (normalized.contains('bongao')) {
      return 'assets/images/rhu_profiles/rhu-bongao.png';
    }

    if (normalized.contains('languyan')) {
      return 'assets/images/rhu_profiles/rhu-languyan.png';
    }

    if (normalized.contains('mapun')) {
      return 'assets/images/rhu_profiles/rhu-mapun.png';
    }

    if (normalized.contains('panglima') || normalized.contains('sugala')) {
      return 'assets/images/rhu_profiles/rhu-panglima-sugala.png';
    }

    if (normalized.contains('sapa')) {
      return 'assets/images/rhu_profiles/rhu-sapa-sapa.png';
    }

    if (normalized.contains('sibutu')) {
      return 'assets/images/rhu_profiles/rhu-sibutu.png';
    }

    if (normalized.contains('simunul')) {
      return 'assets/images/rhu_profiles/rhu-simunul.png';
    }

    if (normalized.contains('sitangkai')) {
      return 'assets/images/rhu_profiles/rhu-sitangkai.png';
    }

    if (normalized.contains('south') && normalized.contains('ubian')) {
      return 'assets/images/rhu_profiles/rhu-south ubian.png';
    }

    if (normalized.contains('tandubas')) {
      return 'assets/images/rhu_profiles/rhu-tandubas.png';
    }

    if (normalized.contains('turtle')) {
      return 'assets/images/rhu_profiles/rhu-turtle islands.png';
    }

    return null;
  }

  static bool shouldUseRhuProfilePicture(String role) {
    final String key = roleKey(role);

    return key == 'rhu_admin' || key == 'pharmacist' || key == 'bhw';
  }

  static List<ProfileShortcutInfo> shortcutsForRole(String role) {
    switch (roleKey(role)) {
      case 'rhu_admin':
        return const <ProfileShortcutInfo>[
          ProfileShortcutInfo(
            title: 'Manage Appointments',
            subtitle: 'Review pending and accepted patient requests',
            icon: Icons.event_available_rounded,
            routeName: '/manage-appointments',
            color: Color(0xFF0F766E),
          ),
          ProfileShortcutInfo(
            title: 'Patient View',
            subtitle: 'View walk-in and online consultation patients',
            icon: Icons.groups_rounded,
            routeName: '/patient-view',
            color: Color(0xFF2563EB),
          ),
          ProfileShortcutInfo(
            title: 'Prescription Claims',
            subtitle: 'Track issued and claimed prescription QR records',
            icon: Icons.medication_rounded,
            routeName: '/prescription-claim-monitor',
            color: Color(0xFF16A34A),
          ),
          ProfileShortcutInfo(
            title: 'Appointment Settings',
            subtitle: 'Control walk-in and online availability',
            icon: Icons.tune_rounded,
            routeName: '/appointment-settings',
            color: Color(0xFFF59E0B),
          ),
          ProfileShortcutInfo(
            title: 'Notifications',
            subtitle: 'Check appointment and prescription alerts',
            icon: Icons.notifications_rounded,
            routeName: '/notifications',
            color: Color(0xFF7C3AED),
          ),
        ];

      case 'pharmacist':
        return const <ProfileShortcutInfo>[
          ProfileShortcutInfo(
            title: 'Prescription Claims',
            subtitle: 'Scan and claim patient prescription QR codes',
            icon: Icons.qr_code_scanner_rounded,
            routeName: '/pharmacist-claimed-prescriptions',
            color: Color(0xFF7C3AED),
          ),
          ProfileShortcutInfo(
            title: 'Notifications',
            subtitle: 'Check pharmacy-related alerts',
            icon: Icons.notifications_rounded,
            routeName: '/notifications',
            color: Color(0xFF2563EB),
          ),
        ];

      case 'bhw':
        return const <ProfileShortcutInfo>[
          ProfileShortcutInfo(
            title: 'Medicine Monitor',
            subtitle: 'View barangay medicine stock and status',
            icon: Icons.inventory_2_rounded,
            routeName: '/medicine-monitor',
            color: Color(0xFF0F766E),
          ),
          ProfileShortcutInfo(
            title: 'Record Transaction',
            subtitle: 'Record received, dispensed, or adjusted medicine',
            icon: Icons.post_add_rounded,
            routeName: '/record-transaction',
            color: Color(0xFF2563EB),
          ),
          ProfileShortcutInfo(
            title: 'Sync Center',
            subtitle: 'Sync offline medicine records when internet returns',
            icon: Icons.cloud_sync_rounded,
            routeName: '/sync',
            color: Color(0xFFF59E0B),
          ),
          ProfileShortcutInfo(
            title: 'Notifications',
            subtitle: 'Check RHU or system notices',
            icon: Icons.notifications_rounded,
            routeName: '/notifications',
            color: Color(0xFF7C3AED),
          ),
        ];

      case 'ipho_admin':
        return const <ProfileShortcutInfo>[
          ProfileShortcutInfo(
            title: 'RHU Directory',
            subtitle: 'View RHU offices and assigned areas',
            icon: Icons.local_hospital_rounded,
            routeName: '/public-rhu-directory',
            color: Color(0xFF0F766E),
          ),
          ProfileShortcutInfo(
            title: 'Users',
            subtitle: 'Manage system users and health workers',
            icon: Icons.manage_accounts_rounded,
            routeName: '/users',
            color: Color(0xFF2563EB),
          ),
          ProfileShortcutInfo(
            title: 'Notifications',
            subtitle: 'Check system-wide alerts',
            icon: Icons.notifications_rounded,
            routeName: '/notifications',
            color: Color(0xFF7C3AED),
          ),
        ];

      case 'public_user':
      default:
        return const <ProfileShortcutInfo>[
          ProfileShortcutInfo(
            title: 'Apply Appointment',
            subtitle: 'Request walk-in or online RHU consultation',
            icon: Icons.event_available_rounded,
            routeName: '/apply-appointment',
            color: Color(0xFF0F766E),
          ),
          ProfileShortcutInfo(
            title: 'My Appointments',
            subtitle: 'Track pending, accepted, and completed requests',
            icon: Icons.calendar_month_rounded,
            routeName: '/my-appointments',
            color: Color(0xFF2563EB),
          ),
          ProfileShortcutInfo(
            title: 'Messages',
            subtitle: 'Read RHU messages, video call notices, and QR records',
            icon: Icons.chat_bubble_rounded,
            routeName: '/public-messages',
            color: Color(0xFF7C3AED),
          ),
          ProfileShortcutInfo(
            title: 'Notifications',
            subtitle: 'Check appointment and QR ticket notices',
            icon: Icons.notifications_rounded,
            routeName: '/notifications',
            color: Color(0xFFF59E0B),
          ),
          ProfileShortcutInfo(
            title: 'Activity History',
            subtitle: 'Review your recent RHU activity',
            icon: Icons.history_rounded,
            routeName: '/public-activity-history',
            color: Color(0xFF16A34A),
          ),
        ];
    }
  }
}

class RhuProfileAvatar extends StatelessWidget {
  const RhuProfileAvatar({
    super.key,
    required this.location,
    required this.initials,
    required this.roleInfo,
    required this.role,
    this.size = 112,
  });

  final String location;
  final String initials;
  final String role;
  final ProfileUserTypeInfo roleInfo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? assetPath = ProfileIdentityResolver.shouldUseRhuProfilePicture(
      role,
    )
        ? ProfileIdentityResolver.rhuProfileAsset(location)
        : null;

    if (assetPath == null) {
      return _InitialsAvatar(
        initials: initials,
        roleInfo: roleInfo,
        size: size,
      );
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: 4,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return _InitialsAvatar(
              initials: initials,
              roleInfo: roleInfo,
              size: size,
            );
          },
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.initials,
    required this.roleInfo,
    required this.size,
  });

  final String initials;
  final ProfileUserTypeInfo roleInfo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String safeInitials = initials.trim().isEmpty ? 'U' : initials.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: roleInfo.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: 4,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          safeInitials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}