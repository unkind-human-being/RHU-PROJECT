import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/event_model.dart';
import '../../data/models/post_model.dart';
import '../../data/models/survey_model.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/survey_repository.dart';

class PublicProvider extends ChangeNotifier {
  PublicProvider({
    PostRepository? postRepository,
    EventRepository? eventRepository,
    SurveyRepository? surveyRepository,
  })  : _postRepository = postRepository ?? PostRepository(),
        _eventRepository = eventRepository ?? EventRepository(),
        _surveyRepository = surveyRepository ?? SurveyRepository();

  final PostRepository _postRepository;
  final EventRepository _eventRepository;
  final SurveyRepository _surveyRepository;

  final List<PostModel> _posts = <PostModel>[];
  final List<EventModel> _events = <EventModel>[];
  final List<SurveyModel> _surveys = <SurveyModel>[];

  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  List<PostModel> get posts {
    return List<PostModel>.unmodifiable(_posts);
  }

  List<EventModel> get events {
    return List<EventModel>.unmodifiable(_events);
  }

  List<SurveyModel> get surveys {
    return List<SurveyModel>.unmodifiable(_surveys);
  }

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  bool get hasPosts => _posts.isNotEmpty;
  bool get hasEvents => _events.isNotEmpty;
  bool get hasSurveys => _surveys.isNotEmpty;

  int get totalUpdates {
    return _posts.length + _events.length + _surveys.length;
  }

  Future<void> loadAllPublicData({
    bool refresh = false,
  }) async {
    if (_isLoading || _isRefreshing) {
      return;
    }

    if (refresh) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final List<dynamic> results = await Future.wait<dynamic>(
        <Future<dynamic>>[
          _postRepository.getPublicPosts(),
          _eventRepository.getPublicEvents(),
          _surveyRepository.getPublicSurveys(),
        ],
      );

      final List<PostModel> posts = results[0] as List<PostModel>;
      final List<EventModel> events = results[1] as List<EventModel>;
      final List<SurveyModel> surveys = results[2] as List<SurveyModel>;

      _posts
        ..clear()
        ..addAll(posts);

      _events
        ..clear()
        ..addAll(events);

      _surveys
        ..clear()
        ..addAll(surveys);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Unable to load public health updates.';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadPostsOnly({
    String? type,
    bool refresh = false,
  }) async {
    if (refresh) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final List<PostModel> result = await _postRepository.getPublicPosts(
        type: type,
      );

      _posts
        ..clear()
        ..addAll(result);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Unable to load public posts.';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadEventsOnly({
    String? type,
    bool refresh = false,
  }) async {
    if (refresh) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final List<EventModel> result = await _eventRepository.getPublicEvents(
        type: type,
      );

      _events
        ..clear()
        ..addAll(result);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Unable to load public events.';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadSurveysOnly({
    String? type,
    bool refresh = false,
  }) async {
    if (refresh) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final List<SurveyModel> result =
          await _surveyRepository.getPublicSurveys(
        type: type,
      );

      _surveys
        ..clear()
        ..addAll(result);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Unable to load public surveys.';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}