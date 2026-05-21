import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../auth/auth_provider.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  static const String routeName = '/users';

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  late final ApiClient _apiClient;

  bool _isLoading = false;
  String? _errorMessage;
  String _selectedRole = 'all';

  List<_UserSummary> _users = <_UserSummary>[];
  List<_RhuRecord> _rhus = <_RhuRecord>[];
  List<_BarangayRecord> _barangays = <_BarangayRecord>[];

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _apiClient.close();
    super.dispose();
  }

  List<_UserSummary> get _filteredUsers {
    final String search = _searchController.text.trim().toLowerCase();

    return _users.where((_UserSummary user) {
      final bool matchesRole =
          _selectedRole == 'all' || user.role == _selectedRole;

      final bool matchesSearch = search.isEmpty ||
          user.fullName.toLowerCase().contains(search) ||
          user.email.toLowerCase().contains(search) ||
          user.phoneNumber.toLowerCase().contains(search) ||
          user.roleLabel.toLowerCase().contains(search) ||
          user.locationText.toLowerCase().contains(search) ||
          user.position.toLowerCase().contains(search);

      return matchesRole && matchesSearch;
    }).toList();
  }

  int get _activeCount {
    return _users.where((_UserSummary user) => user.isActive).length;
  }

  int get _inactiveCount {
    return _users.where((_UserSummary user) => !user.isActive).length;
  }

  int _roleCount(String role) {
    return _users.where((_UserSummary user) => user.role == role).length;
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> usersResponse = await _apiClient.get(
        '/api/users',
        requiresAuth: true,
      );

      List<dynamic> rawRhus = <dynamic>[];
      List<dynamic> rawBarangays = <dynamic>[];

      try {
        rawRhus = _extractList(
          await _apiClient.get(
            '/api/rhus',
            requiresAuth: true,
          ),
        );
      } catch (_) {
        rawRhus = <dynamic>[];
      }

      try {
        rawBarangays = _extractList(
          await _apiClient.get(
            '/api/barangays',
            requiresAuth: true,
          ),
        );
      } catch (_) {
        rawBarangays = <dynamic>[];
      }

      final List<_RhuRecord> rhus = rawRhus
          .whereType<Map<String, dynamic>>()
          .map(_RhuRecord.fromJson)
          .where((_RhuRecord rhu) => rhu.id.trim().isNotEmpty)
          .toList();

      final List<_BarangayRecord> barangays = rawBarangays
          .whereType<Map<String, dynamic>>()
          .map(_BarangayRecord.fromJson)
          .where((_BarangayRecord barangay) {
        return barangay.id.trim().isNotEmpty;
      }).toList();

      final Map<String, _RhuRecord> rhuById = <String, _RhuRecord>{
        for (final _RhuRecord rhu in rhus) rhu.id: rhu,
      };

      final Map<String, _BarangayRecord> barangayById =
          <String, _BarangayRecord>{
        for (final _BarangayRecord barangay in barangays) barangay.id: barangay,
      };

      final List<dynamic> rawUsers = _extractUsers(usersResponse);

      final List<_UserSummary> users = rawUsers
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> json) => _UserSummary.fromJson(
              json,
              rhuById: rhuById,
              barangayById: barangayById,
            ),
          )
          .toList();

      users.sort((_UserSummary a, _UserSummary b) {
        if (a.rolePriority != b.rolePriority) {
          return a.rolePriority.compareTo(b.rolePriority);
        }

        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _rhus = rhus;
        _barangays = barangays;
        _users = users;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load users.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> _extractUsers(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final dynamic users = data['users'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (users is List) return users;
      if (results is List) return results;
      if (docs is List) return docs;
      if (items is List) return items;
    }

    final dynamic users = response['users'];

    if (users is List) {
      return users;
    }

    return <dynamic>[];
  }

  List<dynamic> _extractList(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final dynamic rhus = data['rhus'];
      final dynamic barangays = data['barangays'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (rhus is List) return rhus;
      if (barangays is List) return barangays;
      if (results is List) return results;
      if (docs is List) return docs;
      if (items is List) return items;
    }

    final dynamic rhus = response['rhus'];
    final dynamic barangays = response['barangays'];

    if (rhus is List) return rhus;
    if (barangays is List) return barangays;

    return <dynamic>[];
  }

  Future<void> _openCreateHealthWorker() async {
    await Navigator.of(context).pushNamed('/create-health-worker');

    if (!mounted) {
      return;
    }

    await _loadUsers();
  }

  Future<void> _toggleUserStatus(_UserSummary user, bool makeActive) async {
    if (user.email == 'admin@rhu-tawitawi.local') {
      _showError('The main IPHO admin account cannot be deactivated.');
      return;
    }

    final String action = makeActive ? 'reactivate' : 'deactivate';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            makeActive ? 'Reactivate User?' : 'Deactivate User?',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            makeActive
                ? 'Do you want to reactivate "${user.fullName}"?'
                : 'Do you want to deactivate "${user.fullName}"? The user will stay visible but become inactive.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: makeActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFD97706),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(makeActive ? 'Reactivate' : 'Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _apiClient.patch(
        '/api/users/${user.id}/$action',
        requiresAuth: true,
        body: <String, dynamic>{},
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final int index = _users.indexWhere((_UserSummary item) {
          return item.id == user.id;
        });

        if (index != -1) {
          _users[index] = user.copyWith(isActive: makeActive);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            makeActive
                ? 'User reactivated successfully.'
                : 'User deactivated successfully.',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError(
        makeActive ? 'Unable to reactivate user.' : 'Unable to deactivate user.',
      );
    }
  }

  Future<void> _deleteUser(_UserSummary user) async {
    if (user.email == 'admin@rhu-tawitawi.local') {
      _showError('The main IPHO admin account cannot be deleted.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Permanently Delete User?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete "${user.fullName}"? This account will disappear from the list.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _apiClient.delete(
        '/api/users/${user.id}',
        requiresAuth: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _users.removeWhere((_UserSummary item) {
          return item.id == user.id;
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User permanently deleted successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to permanently delete user.');
    }
  }

  void _showUserDetails(_UserSummary user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _UserDetailsSheet(user: user);
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  void _setRole(String? value) {
    if (value == null) {
      return;
    }

    setState(() {
      _selectedRole = value;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedRole = 'all';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<_UserSummary> filteredUsers = _filteredUsers;

    final AuthProvider authProvider = context.watch<AuthProvider>();
    final bool isMainAdmin =
        authProvider.user?.email == 'admin@rhu-tawitawi.local';

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF9),
      appBar: AppBar(
        title: const Text(
          'User Accounts',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateHealthWorker,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New Staff'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUsers,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _HeaderCard(
                totalUsers: _users.length,
                activeUsers: _activeCount,
                inactiveUsers: _inactiveCount,
                rhuAdminCount: _roleCount('rhu_admin'),
                bhwCount: _roleCount('barangay_health_worker'),
                pharmacistCount: _roleCount('pharmacist'),
                barangayCount: _barangays.length,
                rhuCount: _rhus.length,
              ),
              const SizedBox(height: 18),
              _FilterCard(
                searchController: _searchController,
                selectedRole: _selectedRole,
                onSearchChanged: (_) {
                  setState(() {});
                },
                onRoleChanged: _setRole,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 18),
              if (_errorMessage != null)
                _ErrorCard(
                  message: _errorMessage!,
                  onRetry: _loadUsers,
                )
              else if (_isLoading)
                const _LoadingCard()
              else if (filteredUsers.isEmpty)
                const _EmptyCard()
              else
                ...filteredUsers.map(
                  (_UserSummary user) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _UserCard(
                        user: user,
                        canManage: isMainAdmin &&
                            user.email != 'admin@rhu-tawitawi.local',
                        onTap: () {
                          _showUserDetails(user);
                        },
                        onStatusChanged: (bool value) {
                          _toggleUserStatus(user, value);
                        },
                        onDelete: () {
                          _deleteUser(user);
                        },
                      ),
                    );
                  },
                ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }
}

class _RhuRecord {
  const _RhuRecord({
    required this.id,
    required this.name,
    required this.code,
    required this.municipality,
  });

  factory _RhuRecord.fromJson(Map<String, dynamic> json) {
    return _RhuRecord(
      id: _readString(
        json,
        <String>['_id', 'id'],
      ),
      name: _readString(
        json,
        <String>['name', 'rhuName', 'officeName'],
        fallback: 'Unnamed RHU',
      ),
      code: _readString(
        json,
        <String>['code', 'rhuCode'],
      ),
      municipality: _readString(
        json,
        <String>['municipality', 'city'],
      ),
    );
  }

  final String id;
  final String name;
  final String code;
  final String municipality;
}

class _BarangayRecord {
  const _BarangayRecord({
    required this.id,
    required this.name,
    required this.rhuId,
    required this.municipality,
  });

  factory _BarangayRecord.fromJson(Map<String, dynamic> json) {
    return _BarangayRecord(
      id: _readString(
        json,
        <String>['_id', 'id'],
      ),
      name: _readString(
        json,
        <String>['name', 'barangayName'],
        fallback: 'Unnamed Barangay',
      ),
      rhuId: _readRelationIdFromKeys(
        json,
        <String>['rhu', 'rhuId', 'assignedRhu', 'assignedRhuId'],
      ),
      municipality: _readString(
        json,
        <String>['municipality', 'city'],
      ),
    );
  }

  final String id;
  final String name;
  final String rhuId;
  final String municipality;
}

class _UserSummary {
  const _UserSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.roleLabel,
    required this.position,
    required this.rhuId,
    required this.rhuName,
    required this.barangayId,
    required this.barangayName,
    required this.isActive,
  });

  factory _UserSummary.fromJson(
    Map<String, dynamic> json, {
    required Map<String, _RhuRecord> rhuById,
    required Map<String, _BarangayRecord> barangayById,
  }) {
    final String role = _readString(
      json,
      <String>['role', 'userRole'],
    );

    final String rhuId = _readRelationIdFromKeys(
      json,
      <String>['rhu', 'rhuId', 'assignedRhu', 'assignedRhuId'],
    );

    final String barangayId = _readRelationIdFromKeys(
      json,
      <String>['barangay', 'barangayId', 'assignedBarangay', 'assignedBarangayId'],
    );

    String rhuName = _readString(
      json,
      <String>['rhuName', 'assignedRhuName'],
    );

    if (rhuName.isEmpty) {
      rhuName = _readNestedString(
        json,
        'rhu',
        <String>['name', 'rhuName', 'officeName'],
      );
    }

    if (rhuName.isEmpty && rhuById.containsKey(rhuId)) {
      rhuName = rhuById[rhuId]!.name;
    }

    String barangayName = _readString(
      json,
      <String>['barangayName', 'assignedBarangayName'],
    );

    if (barangayName.isEmpty) {
      barangayName = _readNestedString(
        json,
        'barangay',
        <String>['name', 'barangayName'],
      );
    }

    if (barangayName.isEmpty && barangayById.containsKey(barangayId)) {
      barangayName = barangayById[barangayId]!.name;
    }

    final String status = _readString(
      json,
      <String>['status'],
    ).toLowerCase();

    final dynamic isActiveRaw = json['isActive'];

    final bool isActive = isActiveRaw is bool
        ? isActiveRaw
        : status.isEmpty
            ? true
            : status != 'inactive' && status != 'disabled';

    final String fullName = _readString(
      json,
      <String>['fullName', 'name', 'displayName'],
      fallback: 'Unnamed User',
    );

    final String email = _readString(
      json,
      <String>['email', 'username'],
      fallback: 'No email',
    );

    return _UserSummary(
      id: _readString(
        json,
        <String>['_id', 'id'],
      ),
      fullName: fullName,
      email: email,
      phoneNumber: _readString(
        json,
        <String>['phoneNumber', 'contactNumber', 'phone'],
      ),
      role: role,
      roleLabel: _formatRole(role),
      position: _readString(
        json,
        <String>['position', 'designation'],
      ),
      rhuId: rhuId,
      rhuName: rhuName,
      barangayId: barangayId,
      barangayName: barangayName,
      isActive: isActive,
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String role;
  final String roleLabel;
  final String position;
  final String rhuId;
  final String rhuName;
  final String barangayId;
  final String barangayName;
  final bool isActive;

  _UserSummary copyWith({
    bool? isActive,
  }) {
    return _UserSummary(
      id: id,
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      role: role,
      roleLabel: roleLabel,
      position: position,
      rhuId: rhuId,
      rhuName: rhuName,
      barangayId: barangayId,
      barangayName: barangayName,
      isActive: isActive ?? this.isActive,
    );
  }

  int get rolePriority {
    switch (role) {
      case 'ipho_admin':
        return 1;
      case 'rhu_admin':
        return 2;
      case 'pharmacist':
        return 3;
      case 'barangay_health_worker':
        return 4;
      case 'public_user':
        return 5;
      default:
        return 9;
    }
  }

  String get initials {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String item) => item.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'U';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String get locationText {
    if (rhuName.isNotEmpty && barangayName.isNotEmpty) {
      return '$barangayName • $rhuName';
    }

    if (rhuName.isNotEmpty) {
      return rhuName;
    }

    if (barangayName.isNotEmpty) {
      return barangayName;
    }

    if (role == 'ipho_admin') {
      return 'Province-wide access';
    }

    if (role == 'public_user') {
      return 'Public user account';
    }

    return 'No assigned location';
  }

  String get cleanPosition {
    if (position.trim().isNotEmpty) {
      return position;
    }

    return roleLabel;
  }

  static String _formatRole(String role) {
    switch (role) {
      case 'ipho_admin':
        return 'IPHO Admin';
      case 'rhu_admin':
        return 'RHU Admin';
      case 'barangay_health_worker':
        return 'Barangay Health Worker';
      case 'pharmacist':
        return 'Pharmacist';
      case 'public_user':
        return 'Public User';
      default:
        if (role.trim().isEmpty) {
          return 'Unknown Role';
        }

        return role
            .replaceAll('_', ' ')
            .split(' ')
            .where((String item) => item.trim().isNotEmpty)
            .map((String word) {
          final String lower = word.toLowerCase();

          return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
        }).join(' ');
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.totalUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.rhuAdminCount,
    required this.bhwCount,
    required this.pharmacistCount,
    required this.rhuCount,
    required this.barangayCount,
  });

  final int totalUsers;
  final int activeUsers;
  final int inactiveUsers;
  final int rhuAdminCount;
  final int bhwCount;
  final int pharmacistCount;
  final int rhuCount;
  final int barangayCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
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
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'User Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Manage staff accounts and check assigned RHU or barangay.',
                      style: TextStyle(
                        color: Color(0xFFE0F2F1),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricBox(
                  label: 'Total',
                  value: totalUsers.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'Active',
                  value: activeUsers.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'Inactive',
                  value: inactiveUsers.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricBox(
                  label: 'RHU Admin',
                  value: rhuAdminCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'BHW',
                  value: bhwCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'Pharmacy',
                  value: pharmacistCount.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$rhuCount RHUs • $barangayCount barangays loaded',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE0F2F1),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.searchController,
    required this.selectedRole,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String selectedRole;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Search users',
                hintText: 'Name, email, phone, role, RHU, or barangay',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: selectedRole,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.admin_panel_settings_rounded),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('All roles'),
                ),
                DropdownMenuItem<String>(
                  value: 'ipho_admin',
                  child: Text('IPHO Admin'),
                ),
                DropdownMenuItem<String>(
                  value: 'rhu_admin',
                  child: Text('RHU Admin'),
                ),
                DropdownMenuItem<String>(
                  value: 'barangay_health_worker',
                  child: Text('Barangay Health Worker'),
                ),
                DropdownMenuItem<String>(
                  value: 'pharmacist',
                  child: Text('Pharmacist'),
                ),
                DropdownMenuItem<String>(
                  value: 'public_user',
                  child: Text('Public User'),
                ),
              ],
              onChanged: onRoleChanged,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.canManage,
    required this.onTap,
    required this.onStatusChanged,
    required this.onDelete,
  });

  final _UserSummary user;
  final bool canManage;
  final VoidCallback onTap;
  final ValueChanged<bool> onStatusChanged;
  final VoidCallback onDelete;

  Color get _roleColor {
    switch (user.role) {
      case 'ipho_admin':
        return const Color(0xFF7C3AED);
      case 'rhu_admin':
        return const Color(0xFF0F766E);
      case 'barangay_health_worker':
        return const Color(0xFF2563EB);
      case 'pharmacist':
        return const Color(0xFF9333EA);
      case 'public_user':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData get _roleIcon {
    switch (user.role) {
      case 'ipho_admin':
        return Icons.admin_panel_settings_rounded;
      case 'rhu_admin':
        return Icons.local_hospital_rounded;
      case 'barangay_health_worker':
        return Icons.health_and_safety_rounded;
      case 'pharmacist':
        return Icons.local_pharmacy_rounded;
      case 'public_user':
        return Icons.person_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        user.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    final Color statusBackground =
        user.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2);

    return Card(
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Opacity(
                opacity: user.isActive ? 1 : 0.45,
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.initials,
                    style: TextStyle(
                      color: _roleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  opacity: user.isActive ? 1 : 0.62,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.fullName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (user.phoneNumber.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          user.phoneNumber,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _SmallChip(
                            text: user.roleLabel,
                            icon: _roleIcon,
                            color: _roleColor,
                            backgroundColor: _roleColor.withValues(alpha: 0.10),
                          ),
                          _SmallChip(
                            text: user.isActive ? 'Active' : 'Deactivated',
                            icon: user.isActive
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: statusColor,
                            backgroundColor: statusBackground,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _InfoLine(
                        icon: Icons.location_on_rounded,
                        text: user.locationText,
                      ),
                      const SizedBox(height: 6),
                      _InfoLine(
                        icon: Icons.work_rounded,
                        text: user.cleanPosition,
                      ),
                      if (canManage) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  user.isActive
                                      ? 'Account is active'
                                      : 'Account is deactivated',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Switch(
                                value: user.isActive,
                                onChanged: onStatusChanged,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (canManage)
                IconButton(
                  tooltip: 'Delete user',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                  ),
                )
              else
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

class _UserDetailsSheet extends StatelessWidget {
  const _UserDetailsSheet({
    required this.user,
  });

  final _UserSummary user;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.38,
      maxChildSize: 0.90,
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
              const SizedBox(height: 22),
              Row(
                children: <Widget>[
                  Container(
                    width: 66,
                    height: 66,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        color: Color(0xFF0F766E),
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
                          user.fullName,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.roleLabel,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailsBox(
                children: <Widget>[
                  _DetailsLine(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    value: user.email,
                  ),
                  _DetailsLine(
                    icon: Icons.phone_rounded,
                    label: 'Phone',
                    value: user.phoneNumber.trim().isEmpty
                        ? 'No phone number'
                        : user.phoneNumber,
                  ),
                  _DetailsLine(
                    icon: Icons.badge_rounded,
                    label: 'Role',
                    value: user.roleLabel,
                  ),
                  _DetailsLine(
                    icon: Icons.work_rounded,
                    label: 'Position',
                    value: user.cleanPosition,
                  ),
                  _DetailsLine(
                    icon: Icons.local_hospital_rounded,
                    label: 'Assigned RHU',
                    value: user.rhuName.trim().isEmpty
                        ? 'No assigned RHU'
                        : user.rhuName,
                  ),
                  _DetailsLine(
                    icon: Icons.location_city_rounded,
                    label: 'Barangay',
                    value: user.barangayName.trim().isEmpty
                        ? 'Not assigned'
                        : user.barangayName,
                  ),
                  _DetailsLine(
                    icon: user.isActive
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    label: 'Status',
                    value: user.isActive ? 'Active' : 'Deactivated',
                    isLast: true,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsBox extends StatelessWidget {
  const _DetailsBox({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _DetailsLine extends StatelessWidget {
  const _DetailsLine({
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
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            color: const Color(0xFF0F766E),
            size: 21,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.text,
    required this.icon,
    this.color = const Color(0xFF0F766E),
    this.backgroundColor = const Color(0xFFE0F2F1),
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF6B7280),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load users',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                color: Color(0xFF0F766E),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new staff account or clear your filters.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text('Loading users, RHUs, and barangays...'),
            ),
          ],
        ),
      ),
    );
  }
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    final String text = value.toString().trim();

    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }

  return fallback;
}

String _readNestedString(
  Map<String, dynamic> json,
  String objectKey,
  List<String> keys,
) {
  final dynamic object = json[objectKey];

  if (object is! Map<String, dynamic>) {
    return '';
  }

  return _readString(object, keys);
}

String _readRelationIdFromKeys(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final String key in keys) {
    final dynamic value = json[key];
    final String id = _readRelationId(value);

    if (id.trim().isNotEmpty) {
      return id;
    }
  }

  return '';
}

String _readRelationId(dynamic value) {
  if (value == null) {
    return '';
  }

  if (value is String) {
    return value.trim();
  }

  if (value is Map<String, dynamic>) {
    return _readString(
      value,
      <String>['_id', 'id'],
    );
  }

  return value.toString().trim();
}