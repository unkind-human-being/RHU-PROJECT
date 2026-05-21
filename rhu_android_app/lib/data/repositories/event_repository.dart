import '../models/event_model.dart';
import '../services/event_service.dart';

class EventRepository {
  EventRepository({
    EventService? eventService,
  }) : _eventService = eventService ?? EventService();

  final EventService _eventService;

  Future<List<EventModel>> getPublicEvents({
    String? type,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) {
    return _eventService.getPublicEvents(
      type: type,
      rhuId: rhuId,
      barangayId: barangayId,
      page: page,
      limit: limit,
    );
  }

  Future<List<EventModel>> getStaffEvents({
    String? type,
    String? status,
    String? rhuId,
    String? barangayId,
    int page = 1,
    int limit = 50,
  }) {
    return _eventService.getStaffEvents(
      type: type,
      status: status,
      rhuId: rhuId,
      barangayId: barangayId,
      page: page,
      limit: limit,
    );
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
  }) {
    return _eventService.createEvent(
      title: title,
      description: description,
      type: type,
      status: status,
      audienceScope: audienceScope,
      rhuId: rhuId,
      barangayId: barangayId,
      locationName: locationName,
      address: address,
      startDate: startDate,
      endDate: endDate,
      registrationRequired: registrationRequired,
      maxParticipants: maxParticipants,
      contactPerson: contactPerson,
      contactNumber: contactNumber,
      requirements: requirements,
    );
  }
    Future<void> deleteEvent(String eventId) {
    return _eventService.deleteEvent(eventId);
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
  }) {
    return _eventService.updateEvent(
      eventId: eventId,
      title: title,
      description: description,
      type: type,
      status: status,
      audienceScope: audienceScope,
      locationName: locationName,
      address: address,
      startDate: startDate,
      endDate: endDate,
      registrationRequired: registrationRequired,
      maxParticipants: maxParticipants,
      contactPerson: contactPerson,
      contactNumber: contactNumber,
      requirements: requirements,
    );
  }
}