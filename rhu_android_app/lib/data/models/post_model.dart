class PostModel {
  const PostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.status,
    required this.audienceScope,
    this.rhuId,
    this.rhuName,
    this.barangayId,
    this.barangayName,
    this.tags = const <String>[],
    this.isPinned = false,
    this.viewCount = 0,
    this.createdByName,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String type;
  final String status;
  final String audienceScope;

  final String? rhuId;
  final String? rhuName;

  final String? barangayId;
  final String? barangayName;

  final List<String> tags;
  final bool isPinned;
  final int viewCount;

  final String? createdByName;

  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get typeLabel {
    switch (type) {
      case 'announcement':
        return 'Announcement';
      case 'health_tip':
        return 'Health Tip';
      case 'advisory':
        return 'Advisory';
      case 'news':
        return 'News';
      default:
        return _capitalize(type);
    }
  }

  String get locationName {
    if (barangayName != null && barangayName!.trim().isNotEmpty) {
      return barangayName!;
    }

    if (rhuName != null && rhuName!.trim().isNotEmpty) {
      return rhuName!;
    }

    return 'Province-wide';
  }

  String get shortContent {
    final String cleanContent = content.trim();

    if (cleanContent.length <= 120) {
      return cleanContent;
    }

    return '${cleanContent.substring(0, 120)}...';
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final dynamic rhu = json['rhu'];
    final dynamic barangay = json['barangay'];
    final dynamic createdBy = json['createdBy'];

    return PostModel(
      id: _readString(json['_id'] ?? json['id']),
      title: _readString(json['title']),
      content: _readString(json['content']),
      type: _readString(json['type'], fallback: 'announcement'),
      status: _readString(json['status']),
      audienceScope: _readString(json['audienceScope']),
      rhuId: _readNestedId(rhu),
      rhuName: _readNestedString(rhu, 'name'),
      barangayId: _readNestedId(barangay),
      barangayName: _readNestedString(barangay, 'name'),
      tags: _readStringList(json['tags']),
      isPinned: json['isPinned'] is bool ? json['isPinned'] as bool : false,
      viewCount: _readInt(json['viewCount']),
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
      'content': content,
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
      'tags': tags,
      'isPinned': isPinned,
      'viewCount': viewCount,
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