import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'create_event_screen.dart';
import 'edit_event_screen.dart';


import '../../core/network/api_exception.dart';
import '../../data/models/event_model.dart';
import '../../data/repositories/event_repository.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  static const String routeName = '/manage-events';

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  final EventRepository _eventRepository = EventRepository();

  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedStatus;
  String? _selectedType;

  List<EventModel> _events = <EventModel>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
    });
  }

  Future<void> _openEditEvent(EventModel event) async {
    final Object? result = await Navigator.of(context).pushNamed(
      EditEventScreen.routeName,
      arguments: EditEventArguments(
        event: event,
      ),
    );

    if (result == true && mounted) {
      await _loadEvents();
    }
  }


  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<EventModel> result = await _eventRepository.getStaffEvents(
        type: _selectedType,
        status: _selectedStatus,
      );

      setState(() {
        _events = result;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Unable to load events.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteEvent(EventModel event) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Event?'),
          content: Text(
            'Are you sure you want to delete "${event.title}"?',
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
      await _eventRepository.deleteEvent(event.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event deleted successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      await _loadEvents();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete event.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _openCreateEvent() async {
    await Navigator.of(context).pushNamed(CreateEventScreen.routeName);

    if (!mounted) {
      return;
    }

    await _loadEvents();
  }

  Future<void> _setStatus(String? value) async {
    setState(() {
      _selectedStatus = value;
    });

    await _loadEvents();
  }

  Future<void> _setType(String? value) async {
    setState(() {
      _selectedType = value;
    });

    await _loadEvents();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedStatus = null;
      _selectedType = null;
    });

    await _loadEvents();
  }

  String _formatSchedule(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      return 'Schedule not specified';
    }

    if (start != null && end == null) {
      return DateFormat('MMM d, yyyy • h:mm a').format(start);
    }

    if (start == null && end != null) {
      return DateFormat('MMM d, yyyy • h:mm a').format(end);
    }

    final String startText = DateFormat('MMM d, yyyy • h:mm a').format(start!);
    final String endText = DateFormat('h:mm a').format(end!);

    return '$startText - $endText';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Events',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _isLoading ? null : _loadEvents,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateEvent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Event'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadEvents,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _HeaderCard(totalEvents: _events.length),
              const SizedBox(height: 18),
              _FilterCard(
                selectedStatus: _selectedStatus,
                selectedType: _selectedType,
                onStatusChanged: _setStatus,
                onTypeChanged: _setType,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 18),
              if (_errorMessage != null)
                _ErrorCard(
                  message: _errorMessage!,
                  onRetry: _loadEvents,
                )
              else if (_isLoading)
                const _LoadingCard()
              else if (_events.isEmpty)
                const _EmptyCard()
              else
                ..._events.map(
                  (EventModel event) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EventCard(
                        event: event,
                        scheduleText: _formatSchedule(
                          event.startDate,
                          event.endDate,
                        ),
                        onEdit: () => _openEditEvent(event),
                        onDelete: () => _deleteEvent(event),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.totalEvents,
  });

  final int totalEvents;

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
      child: Row(
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
              Icons.event_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Event Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create and view RHU events, medical missions, seminars, and public health activities.',
                  style: TextStyle(
                    color: Color(0xFFE0F2F1),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$totalEvents event/s loaded',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.selectedStatus,
    required this.selectedType,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onClear,
  });

  final String? selectedStatus;
  final String? selectedType;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            DropdownButtonFormField<String>(
              value: selectedStatus ?? 'all',
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.publish_rounded),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('All statuses'),
                ),
                DropdownMenuItem<String>(
                  value: 'open',
                  child: Text('Open'),
                ),
                DropdownMenuItem<String>(
                  value: 'draft',
                  child: Text('Draft'),
                ),
                DropdownMenuItem<String>(
                  value: 'closed',
                  child: Text('Closed'),
                ),
                DropdownMenuItem<String>(
                  value: 'cancelled',
                  child: Text('Cancelled'),
                ),
                DropdownMenuItem<String>(
                  value: 'completed',
                  child: Text('Completed'),
                ),
              ],
              onChanged: (String? value) {
                if (value == null || value == 'all') {
                  onStatusChanged(null);
                  return;
                }

                onStatusChanged(value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: selectedType ?? 'all',
              decoration: const InputDecoration(
                labelText: 'Event type',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('All event types'),
                ),
                DropdownMenuItem<String>(
                  value: 'medical_mission',
                  child: Text('Medical Mission'),
                ),
                DropdownMenuItem<String>(
                  value: 'vaccination',
                  child: Text('Vaccination'),
                ),
                DropdownMenuItem<String>(
                  value: 'deworming',
                  child: Text('Deworming'),
                ),
                DropdownMenuItem<String>(
                  value: 'seminar',
                  child: Text('Seminar'),
                ),
                DropdownMenuItem<String>(
                  value: 'health_checkup',
                  child: Text('Health Checkup'),
                ),
              ],
              onChanged: (String? value) {
                if (value == null || value == 'all') {
                  onTypeChanged(null);
                  return;
                }

                onTypeChanged(value);
              },
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

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.scheduleText,
    required this.onEdit,
    required this.onDelete,
  });

  final EventModel event;
  final String scheduleText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${event.typeLabel} • ${event.statusLabel}',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Edit event',
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete event',
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              event.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            _InfoLine(
              icon: Icons.schedule_rounded,
              text: scheduleText,
            ),
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.location_on_rounded,
              text: event.locationDisplay,
            ),
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.groups_rounded,
              text: event.registrationRequired
                  ? event.hasParticipantLimit
                      ? '${event.registeredCount}/${event.maxParticipants} registered'
                      : 'Registration required'
                  : 'No registration required',
            ),
          ],
        ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          color: const Color(0xFF6B7280),
          size: 17,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text.trim().isEmpty ? 'N/A' : text,
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
              'Unable to load events',
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
                Icons.event_busy_rounded,
                color: Color(0xFF0F766E),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No events found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new RHU event or clear your filters.',
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
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text('Loading events...'),
            ),
          ],
        ),
      ),
    );
  }
}