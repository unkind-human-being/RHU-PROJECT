import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../models/event_model.dart';

class EventService {
  EventService({
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
  }) : _apiClient = apiClient ??
            ApiClient(
              tokenProvider:
                  (tokenStorageService ?? TokenStorageService()).getToken,
            );

  final ApiClient _apiClient;

  Future<List<EventModel>> getPublicEvents({
    String? type,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) async {
    final Map<String, dynamic> response = await _apiClient.get(
      ApiConstants.publicEvents,
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
      return <EventModel>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(EventModel.fromJson)
        .toList();
  }

  Future<List<EventModel>> getStaffEvents({
    String? type,
    String? status,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) async {
    final Map<String, dynamic> response = await _apiClient.get(
      ApiConstants.events,
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
      return <EventModel>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(EventModel.fromJson)
        .toList();
  }

  Future<EventModel> createEvent({
    required String title,
    required String description,
    required String type,
    required String status,
    required String audienceScope,
    String? rhuId,
    String? barangayId,
    required String locationName,
    required String address,
    required DateTime startDate,
    required DateTime endDate,
    bool registrationRequired = false,
    int maxParticipants = 0,
    String contactPerson = '',
    String contactNumber = '',
    List<String> requirements = const <String>[],
  }) async {
    if (title.trim().isEmpty) {
      throw const ApiException(
        message: 'Event title is required.',
        statusCode: 400,
      );
    }

    if (description.trim().isEmpty) {
      throw const ApiException(
        message: 'Event description is required.',
        statusCode: 400,
      );
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'type': type.trim(),
      'status': status.trim(),
      'audienceScope': audienceScope.trim(),
      'locationName': locationName.trim(),
      'address': address.trim(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'registrationRequired': registrationRequired,
      'maxParticipants': maxParticipants,
      'contactPerson': contactPerson.trim(),
      'contactNumber': contactNumber.trim(),
      'requirements': requirements,
    };

    if (rhuId != null && rhuId.trim().isNotEmpty) {
      body['rhu'] = rhuId.trim();
    }

    if (barangayId != null && barangayId.trim().isNotEmpty) {
      body['barangay'] = barangayId.trim();
    }

    final Map<String, dynamic> response = await _apiClient.post(
      ApiConstants.events,
      requiresAuth: true,
      body: body,
    );

    final dynamic data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Invalid event response from server.',
      );
    }

    return EventModel.fromJson(data);
  }

  Future<void> deleteEvent(String eventId) async {
    if (eventId.trim().isEmpty) {
      throw const ApiException(
        message: 'Event ID is required.',
        statusCode: 400,
      );
    }

    await _apiClient.delete(
      '${ApiConstants.events}/$eventId',
      requiresAuth: true,
    );
  }

  Future<EventModel> updateEvent({
    required String eventId,
    required String title,
    required String description,
    required String type,
    required String status,
    required String audienceScope,
    required String locationName,
    required String address,
    required DateTime startDate,
    required DateTime endDate,
    bool registrationRequired = false,
    int maxParticipants = 0,
    String contactPerson = '',
    String contactNumber = '',
    List<String> requirements = const <String>[],
  }) async {
    if (eventId.trim().isEmpty) {
      throw const ApiException(
        message: 'Event ID is required.',
        statusCode: 400,
      );
    }

    if (title.trim().isEmpty) {
      throw const ApiException(
        message: 'Event title is required.',
        statusCode: 400,
      );
    }

    if (description.trim().isEmpty) {
      throw const ApiException(
        message: 'Event description is required.',
        statusCode: 400,
      );
    }

    if (endDate.isBefore(startDate)) {
      throw const ApiException(
        message: 'End date must be after start date.',
        statusCode: 400,
      );
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'type': type.trim(),
      'status': status.trim(),
      'audienceScope': audienceScope.trim(),
      'locationName': locationName.trim(),
      'address': address.trim(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'registrationRequired': registrationRequired,
      'maxParticipants': maxParticipants,
      'contactPerson': contactPerson.trim(),
      'contactNumber': contactNumber.trim(),
      'requirements': requirements,
    };

    final Map<String, dynamic> response = await _apiClient.patch(
      '${ApiConstants.events}/$eventId',
      requiresAuth: true,
      body: body,
    );

    final dynamic data = response['data'] ?? response['event'];

    if (data is Map<String, dynamic>) {
      return EventModel.fromJson(data);
    }

    if (response.containsKey('_id') || response.containsKey('id')) {
      return EventModel.fromJson(response);
    }

    throw const ApiException(
      message: 'Invalid event response from server.',
    );
  }
}