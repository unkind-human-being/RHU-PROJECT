class SurveyModel {
  const SurveyModel({
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
    this.requiresLogin = false,
    this.allowMultipleResponses = false,
    this.questions = const <SurveyQuestionModel>[],
    this.responseCount = 0,
    this.startDate,
    this.endDate,
    this.createdByName,
    this.publishedAt,
    this.closedAt,
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

  final bool requiresLogin;
  final bool allowMultipleResponses;

  final List<SurveyQuestionModel> questions;
  final int responseCount;

  final DateTime? startDate;
  final DateTime? endDate;

  final String? createdByName;

  final DateTime? publishedAt;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get typeLabel {
    switch (type) {
      case 'community_needs':
        return 'Community Needs';
      case 'feedback':
        return 'Feedback';
      case 'health_assessment':
        return 'Health Assessment';
      case 'service_satisfaction':
        return 'Service Satisfaction';
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
      case 'archived':
        return 'Archived';
      default:
        return _capitalize(status);
    }
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

  String get shortDescription {
    final String cleanDescription = description.trim();

    if (cleanDescription.length <= 120) {
      return cleanDescription;
    }

    return '${cleanDescription.substring(0, 120)}...';
  }

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';

  factory SurveyModel.fromJson(Map<String, dynamic> json) {
    final dynamic rhu = json['rhu'];
    final dynamic barangay = json['barangay'];
    final dynamic createdBy = json['createdBy'];

    return SurveyModel(
      id: _readString(json['_id'] ?? json['id']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      type: _readString(json['type'], fallback: 'survey'),
      status: _readString(json['status']),
      audienceScope: _readString(json['audienceScope']),
      rhuId: _readNestedId(rhu),
      rhuName: _readNestedString(rhu, 'name'),
      barangayId: _readNestedId(barangay),
      barangayName: _readNestedString(barangay, 'name'),
      requiresLogin: json['requiresLogin'] is bool
          ? json['requiresLogin'] as bool
          : false,
      allowMultipleResponses: json['allowMultipleResponses'] is bool
          ? json['allowMultipleResponses'] as bool
          : false,
      questions: _readQuestions(json['questions']),
      responseCount: _readInt(json['responseCount']),
      startDate: _readDate(json['startDate']),
      endDate: _readDate(json['endDate']),
      createdByName: _readNestedString(createdBy, 'fullName'),
      publishedAt: _readDate(json['publishedAt']),
      closedAt: _readDate(json['closedAt']),
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
      'requiresLogin': requiresLogin,
      'allowMultipleResponses': allowMultipleResponses,
      'questions': questions.map((SurveyQuestionModel item) {
        return item.toJson();
      }).toList(),
      'responseCount': responseCount,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'createdBy': createdByName == null
          ? null
          : <String, dynamic>{
              'fullName': createdByName,
            },
      'publishedAt': publishedAt?.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static List<SurveyQuestionModel> _readQuestions(dynamic value) {
    if (value is! List) {
      return <SurveyQuestionModel>[];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map(SurveyQuestionModel.fromJson)
        .toList();
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

class SurveyQuestionModel {
  const SurveyQuestionModel({
    required this.questionText,
    required this.type,
    this.options = const <String>[],
    this.isRequired = false,
    this.order = 0,
  });

  final String questionText;
  final String type;
  final List<String> options;
  final bool isRequired;
  final int order;

  String get typeLabel {
    switch (type) {
      case 'short_text':
        return 'Short Text';
      case 'long_text':
        return 'Long Text';
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'checkbox':
        return 'Checkbox';
      case 'yes_no':
        return 'Yes or No';
      case 'number':
        return 'Number';
      default:
        return _capitalize(type);
    }
  }

  factory SurveyQuestionModel.fromJson(Map<String, dynamic> json) {
    return SurveyQuestionModel(
      questionText: _readString(json['questionText']),
      type: _readString(json['type']),
      options: _readStringList(json['options']),
      isRequired:
          json['isRequired'] is bool ? json['isRequired'] as bool : false,
      order: _readInt(json['order']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'questionText': questionText,
      'type': type,
      'options': options,
      'isRequired': isRequired,
      'order': order,
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
}