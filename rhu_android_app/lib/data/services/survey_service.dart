import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../models/survey_model.dart';

class SurveyService {
  SurveyService({
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
  }) : _apiClient = apiClient ??
            ApiClient(
              tokenProvider:
                  (tokenStorageService ?? TokenStorageService()).getToken,
            );

  final ApiClient _apiClient;

  Future<List<SurveyModel>> getPublicSurveys({
    String? type,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) async {
    final Map<String, dynamic> response = await _apiClient.get(
      ApiConstants.publicSurveys,
      requiresAuth: false,
      queryParameters: <String, dynamic>{
        'type': type,
        'rhu': rhuId,
        'barangay': barangayId,
        'page': page,
        'limit': limit,
      },
    );

    final dynamic data = response['data'];

    if (data is! List) {
      return <SurveyModel>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(SurveyModel.fromJson)
        .toList();
  }

  Future<List<SurveyModel>> getStaffSurveys({
    String? type,
    String? status,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) async {
    final Map<String, dynamic> response = await _apiClient.get(
      ApiConstants.surveys,
      requiresAuth: true,
      queryParameters: <String, dynamic>{
        'type': type,
        'status': status,
        'rhu': rhuId,
        'barangay': barangayId,
        'page': page,
        'limit': limit,
      },
    );

    final dynamic data = response['data'];

    if (data is! List) {
      return <SurveyModel>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(SurveyModel.fromJson)
        .toList();
  }

  Future<SurveyModel> createSurvey({
    required String title,
    required String description,
    required String type,
    required String status,
    required String audienceScope,
    String? rhuId,
    String? barangayId,
    bool requiresLogin = false,
    bool allowMultipleResponses = false,
    required List<SurveyQuestionModel> questions,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (title.trim().isEmpty) {
      throw const ApiException(
        message: 'Survey title is required.',
        statusCode: 400,
      );
    }

    if (description.trim().isEmpty) {
      throw const ApiException(
        message: 'Survey description is required.',
        statusCode: 400,
      );
    }

    if (questions.isEmpty) {
      throw const ApiException(
        message: 'At least one survey question is required.',
        statusCode: 400,
      );
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'type': type.trim(),
      'status': status.trim(),
      'audienceScope': audienceScope.trim(),
      'requiresLogin': requiresLogin,
      'allowMultipleResponses': allowMultipleResponses,
      'questions': questions.map((SurveyQuestionModel question) {
        return question.toJson();
      }).toList(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };

    if (rhuId != null && rhuId.trim().isNotEmpty) {
      body['rhu'] = rhuId.trim();
    }

    if (barangayId != null && barangayId.trim().isNotEmpty) {
      body['barangay'] = barangayId.trim();
    }

    final Map<String, dynamic> response = await _apiClient.post(
      ApiConstants.surveys,
      requiresAuth: true,
      body: body,
    );

    final dynamic data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Invalid survey response from server.',
      );
    }

    return SurveyModel.fromJson(data);
  }

  Future<void> deleteSurvey(String surveyId) async {
    if (surveyId.trim().isEmpty) {
      throw const ApiException(
        message: 'Survey ID is required.',
        statusCode: 400,
      );
    }

    await _apiClient.delete(
      '${ApiConstants.surveys}/$surveyId',
      requiresAuth: true,
    );
  }

  Future<SurveyModel> updateSurvey({
    required String surveyId,
    required String title,
    required String description,
    required String type,
    required String status,
    required String audienceScope,
    required bool requiresLogin,
    required bool allowMultipleResponses,
    required DateTime startDate,
    required DateTime endDate,
    required List<SurveyQuestionModel> questions,
  }) async {
    if (surveyId.trim().isEmpty) {
      throw const ApiException(
        message: 'Survey ID is required.',
        statusCode: 400,
      );
    }

    if (title.trim().isEmpty) {
      throw const ApiException(
        message: 'Survey title is required.',
        statusCode: 400,
      );
    }

    if (description.trim().isEmpty) {
      throw const ApiException(
        message: 'Survey description is required.',
        statusCode: 400,
      );
    }

    if (endDate.isBefore(startDate)) {
      throw const ApiException(
        message: 'End date must be after start date.',
        statusCode: 400,
      );
    }

    if (questions.isEmpty) {
      throw const ApiException(
        message: 'At least one survey question is required.',
        statusCode: 400,
      );
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'type': type.trim(),
      'status': status.trim(),
      'audienceScope': audienceScope.trim(),
      'requiresLogin': requiresLogin,
      'allowMultipleResponses': allowMultipleResponses,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'questions': questions
          .map((SurveyQuestionModel question) => question.toJson())
          .toList(),
    };

    final Map<String, dynamic> response = await _apiClient.patch(
      '${ApiConstants.surveys}/$surveyId',
      requiresAuth: true,
      body: body,
    );

    final dynamic data = response['data'] ?? response['survey'];

    if (data is Map<String, dynamic>) {
      return SurveyModel.fromJson(data);
    }

    if (response.containsKey('_id') || response.containsKey('id')) {
      return SurveyModel.fromJson(response);
    }

    throw const ApiException(
      message: 'Invalid survey response from server.',
    );
  }
}