import '../models/survey_model.dart';
import '../services/survey_service.dart';

class SurveyRepository {
  SurveyRepository({
    SurveyService? surveyService,
  }) : _surveyService = surveyService ?? SurveyService();

  final SurveyService _surveyService;

  Future<List<SurveyModel>> getPublicSurveys({
    String? type,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) {
    return _surveyService.getPublicSurveys(
      type: type,
      rhuId: rhuId,
      barangayId: barangayId,
      page: page,
      limit: limit,
    );
  }

  Future<List<SurveyModel>> getStaffSurveys({
    String? type,
    String? status,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) {
    return _surveyService.getStaffSurveys(
      type: type,
      status: status,
      rhuId: rhuId,
      barangayId: barangayId,
      page: page,
      limit: limit,
    );
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
  }) {
    return _surveyService.createSurvey(
      title: title,
      description: description,
      type: type,
      status: status,
      audienceScope: audienceScope,
      rhuId: rhuId,
      barangayId: barangayId,
      requiresLogin: requiresLogin,
      allowMultipleResponses: allowMultipleResponses,
      questions: questions,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> deleteSurvey(String surveyId) {
    return _surveyService.deleteSurvey(surveyId);
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
  }) {
    return _surveyService.updateSurvey(
      surveyId: surveyId,
      title: title,
      description: description,
      type: type,
      status: status,
      audienceScope: audienceScope,
      requiresLogin: requiresLogin,
      allowMultipleResponses: allowMultipleResponses,
      startDate: startDate,
      endDate: endDate,
      questions: questions,
    );
  }
}