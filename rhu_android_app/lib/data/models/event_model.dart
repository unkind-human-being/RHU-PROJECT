class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.audienceScope,
    this.rhuId,
    this.rhuName,
    this.barangayId,
    this.barangayName,
    this.locationName = '',
    this.address = '',
    this.startDate,
    this.endDate,
    this.registrationRequired = false,
    this.registrationDeadline,
    this.maxParticipants = 0,
    this.registeredCount = 0,
    this.requirements = const <String>[],
    this.contactPerson = '',
    this.contactNumber = '',
    this.createdByName,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String status;
  final String audienceScope;

  final String? rhuId;
  final String? rhuName;

  final String? barangayId;
  final String? barangayName;

  final String locationName;
  final String address;

  final DateTime? startDate;
  final DateTime? endDate;

  final bool registrationRequired;
  final DateTime? registrationDeadline;
  final int maxParticipants;
  final int registeredCount;

  final List<String> requirements;

  final String contactPerson;
  final String contactNumber;

  final String? createdByName;

  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get typeLabel {
    switch (type) {
      case 'medical_mission':
        return 'Medical Mission';
      case 'vaccination':
        return 'Vaccination';
      case 'deworming':
        return 'Deworming';
      case 'seminar':
        return 'Seminar';
      case 'health_checkup':
        return 'Health Checkup';
      default:
        return _capitalize(type);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'open':
        return 'Open';
      case 'closed':
        return 'Closed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return _capitalize(status);
    }
  }

  String get locationDisplay {
    if (locationName.trim().isNotEmpty && address.trim().isNotEmpty) {
      return '$locationName • $address';
    }

    if (locationName.trim().isNotEmpty) {
      return locationName;
    }

    if (address.trim().isNotEmpty) {
      return address;
    }

    if (barangayName != null && barangayName!.trim().isNotEmpty) {
      return barangayName!;
    }

    if (rhuName != null && rhuName!.trim().isNotEmpty) {
      return rhuName!;
    }

    return 'Location not specified';
  }

  String get audienceLocation {
    if (barangayName != null && barangayName!.trim().isNotEmpty) {
      return barangayName!;
    }

    if (rhuName != null && rhuName!.trim().isNotEmpty) {
      return rhuName!;
    }

    return 'Province-wide';
  }

  bool get hasParticipantLimit => maxParticipants > 0;

  bool get isFull {
    if (!hasParticipantLimit) {
      return false;
    }

    return registeredCount >= maxParticipants;
  }

  int get remainingSlots {
    if (!hasParticipantLimit) {
      return 0;
    }

    final int remaining = maxParticipants - registeredCount;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final dynamic rhu = json['rhu'];
    final dynamic barangay = json['barangay'];
    final dynamic createdBy = json['createdBy'];

    return EventModel(
      id: _readString(json['_id'] ?? json['id']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      type: _readString(json['type'], fallback: 'event'),
      status: _readString(json['status']),
      audienceScope: _readString(json['audienceScope']),
      rhuId: _readNestedId(rhu),
      rhuName: _readNestedString(rhu, 'name'),
      barangayId: _readNestedId(barangay),
      barangayName: _readNestedString(barangay, 'name'),
      locationName: _readString(json['locationName']),
      address: _readString(json['address']),
      startDate: _readDate(json['startDate']),
      endDate: _readDate(json['endDate']),
      registrationRequired:
          json['registrationRequired'] is bool ? json['registrationRequired'] as bool : false,
      registrationDeadline: _readDate(json['registrationDeadline']),
      maxParticipants: _readInt(json['maxParticipants']),
      registeredCount: _readInt(json['registeredCount']),
      requirements: _readStringList(json['requirements']),
      contactPerson: _readString(json['contactPerson']),
      contactNumber: _readString(json['contactNumber']),
      createdByName: _readNestedString(createdBy, 'fullName'),
      publishedAt: _readDate(json['publishedAt']),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_id': id,
      'title': title,
      'description': description,
      'type': type,
      'status': status,
      'audienceScope': audienceScope,
      'rhu': rhuId == null
          ? null
          : <String, dynamic>{
              '_id': rhuId,
              'name': rhuName,
            },
      'barangay': barangayId == null
          ? null
          : <String, dynamic>{
              '_id': barangayId,
              'name': barangayName,
            },
      'locationName': locationName,
      'address': address,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'registrationRequired': registrationRequired,
      'registrationDeadline': registrationDeadline?.toIso8601String(),
      'maxParticipants': maxParticipants,
      'registeredCount': registeredCount,
      'requirements': requirements,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'createdBy': createdByName == null
          ? null
          : <String, dynamic>{
              'fullName': createdByName,
            },
      'publishedAt': publishedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static String _capitalize(String value) {
    final String cleanValue = value.trim();

    if (cleanValue.isEmpty) {
      return 'Unknown';
    }

    return cleanValue.substring(0, 1).toUpperCase() +
        cleanValue.substring(1).replaceAll('_', ' ');
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

  static int _readInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((dynamic item) => item.toString())
        .where((String item) => item.trim().isNotEmpty)
        .toList();
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