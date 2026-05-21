class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.authProvider,
    this.rhuId,
    this.rhuName,
    this.rhuCode,
    this.barangayId,
    this.barangayName,
    this.barangayCode,
    this.position = '',
    this.phoneNumber = '',
    this.isActive = true,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String authProvider;

  final String? rhuId;
  final String? rhuName;
  final String? rhuCode;

  final String? barangayId;
  final String? barangayName;
  final String? barangayCode;

  final String position;
  final String phoneNumber;
  final bool isActive;

  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const String iphoAdminRole = 'ipho_admin';
  static const String rhuAdminRole = 'rhu_admin';
  static const String barangayHealthWorkerRole = 'barangay_health_worker';
  static const String publicUserRole = 'public_user';

  bool get isIPHOAdmin => role == iphoAdminRole;
  bool get isRHUAdmin => role == rhuAdminRole;
  bool get isBarangayHealthWorker => role == barangayHealthWorkerRole;
  bool get isPublicUser => role == publicUserRole;

  bool get isAdmin => isIPHOAdmin || isRHUAdmin;

  bool get isStaff => isIPHOAdmin || isRHUAdmin || isBarangayHealthWorker;

  String get roleDisplayName {
    switch (role) {
      case iphoAdminRole:
        return 'IPHO Admin';
      case rhuAdminRole:
        return 'RHU Admin';
      case barangayHealthWorkerRole:
        return 'Barangay Health Worker';
      case publicUserRole:
        return 'Public User';
      default:
        return 'Unknown Role';
    }
  }

  String get assignedLocation {
    if (isIPHOAdmin) {
      return 'Province-wide Access';
    }

    if (barangayName != null && barangayName!.trim().isNotEmpty) {
      return barangayName!;
    }

    if (rhuName != null && rhuName!.trim().isNotEmpty) {
      return rhuName!;
    }

    return 'No assigned location';
  }

    String get initials {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'U';
    }

    String firstLetter(String value) {
      final String trimmed = value.trim();

      if (trimmed.isEmpty) {
        return '';
      }

      return trimmed.substring(0, 1).toUpperCase();
    }

    if (parts.length == 1) {
      return firstLetter(parts.first);
    }

    return '${firstLetter(parts.first)}${firstLetter(parts.last)}';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final dynamic rhu = json['rhu'];
    final dynamic barangay = json['barangay'];

    return UserModel(
      id: _readString(json['_id'] ?? json['id']),
      fullName: _readString(json['fullName']),
      email: _readString(json['email']),
      role: _readString(json['role']),
      authProvider: _readString(
        json['authProvider'],
        fallback: 'local',
      ),
      rhuId: _readNestedId(rhu),
      rhuName: _readNestedString(rhu, 'name'),
      rhuCode: _readNestedString(rhu, 'code'),
      barangayId: _readNestedId(barangay),
      barangayName: _readNestedString(barangay, 'name'),
      barangayCode: _readNestedString(barangay, 'code'),
      position: _readString(json['position']),
      phoneNumber: _readString(json['phoneNumber']),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      lastLoginAt: _readDate(json['lastLoginAt']),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'authProvider': authProvider,
      'rhu': rhuId == null
          ? null
          : <String, dynamic>{
              '_id': rhuId,
              'name': rhuName,
              'code': rhuCode,
            },
      'barangay': barangayId == null
          ? null
          : <String, dynamic>{
              '_id': barangayId,
              'name': barangayName,
              'code': barangayCode,
            },
      'position': position,
      'phoneNumber': phoneNumber,
      'isActive': isActive,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    String? authProvider,
    String? rhuId,
    String? rhuName,
    String? rhuCode,
    String? barangayId,
    String? barangayName,
    String? barangayCode,
    String? position,
    String? phoneNumber,
    bool? isActive,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      authProvider: authProvider ?? this.authProvider,
      rhuId: rhuId ?? this.rhuId,
      rhuName: rhuName ?? this.rhuName,
      rhuCode: rhuCode ?? this.rhuCode,
      barangayId: barangayId ?? this.barangayId,
      barangayName: barangayName ?? this.barangayName,
      barangayCode: barangayCode ?? this.barangayCode,
      position: position ?? this.position,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _readString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    return value.toString();
  }

  static String? _readNestedId(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value.trim().isEmpty ? null : value;
    }

    if (value is Map<String, dynamic>) {
      final String id = _readString(value['_id'] ?? value['id']);
      return id.trim().isEmpty ? null : id;
    }

    return null;
  }

  static String? _readNestedString(dynamic value, String key) {
    if (value is Map<String, dynamic>) {
      final String result = _readString(value[key]);
      return result.trim().isEmpty ? null : result;
    }

    return null;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}