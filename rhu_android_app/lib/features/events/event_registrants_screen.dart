import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class EventRegistrantsScreen extends StatefulWidget {
  const EventRegistrantsScreen({super.key});

  static const String routeName = '/event-registrants';

  @override
  State<EventRegistrantsScreen> createState() => _EventRegistrantsScreenState();
}

class _EventRegistrantsScreenState extends State<EventRegistrantsScreen> {
  late final ApiClient _apiClient;

  bool _isLoadingEvents = false;
  bool _isLoadingRegistrants = false;
  bool _isUpdatingStatus = false;

  String? _errorMessage;
  String _selectedStatus = 'all';

  List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _registrants = <Map<String, dynamic>>[];

  Map<String, dynamic>? _selectedEvent;

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredRegistrants {
    if (_selectedStatus == 'all') {
      return _registrants;
    }

    return _registrants.where((Map<String, dynamic> registrant) {
      return _readString(registrant, <String>['status']) == _selectedStatus;
    }).toList();
  }

  int _countByStatus(String status) {
    return _registrants.where((Map<String, dynamic> registrant) {
      return _readString(registrant, <String>['status']) == status;
    }).length;
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/events',
        requiresAuth: true,
        queryParameters: <String, dynamic>{
          'limit': 100,
        },
      );

      final List<dynamic> rawEvents = _extractList(response);

      final List<Map<String, dynamic>> events = rawEvents
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      events.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime bDate = _readDateTime(
          b,
          <String>['startDate', 'eventDate', 'scheduledAt', 'createdAt'],
        );
        final DateTime aDate = _readDateTime(
          a,
          <String>['startDate', 'eventDate', 'scheduledAt', 'createdAt'],
        );

        return bDate.compareTo(aDate);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _events = events;
      });

      if (events.isNotEmpty) {
        await _selectEvent(events.first);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load RHU events.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  Future<void> _selectEvent(Map<String, dynamic> event) async {
    setState(() {
      _selectedEvent = event;
      _registrants = <Map<String, dynamic>>[];
      _selectedStatus = 'all';
    });

    await _loadRegistrantsForEvent(event);
  }

  Future<void> _loadRegistrantsForEvent(Map<String, dynamic> event) async {
    final String eventId = _readString(event, <String>['_id', 'id']);

    if (eventId.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Event ID was not found.';
      });
      return;
    }

    setState(() {
      _isLoadingRegistrants = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/event-registrations/event/${Uri.encodeComponent(eventId)}',
        requiresAuth: true,
      );

      final List<dynamic> rawRegistrants = _extractList(response);

      final List<Map<String, dynamic>> registrants = rawRegistrants
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      registrants.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime bDate = _readDateTime(
          b,
          <String>['registeredAt', 'createdAt'],
        );
        final DateTime aDate = _readDateTime(
          a,
          <String>['registeredAt', 'createdAt'],
        );

        return bDate.compareTo(aDate);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _registrants = registrants;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load event registrants.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRegistrants = false;
        });
      }
    }
  }

  List<dynamic> _extractList(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final dynamic events = data['events'];
      final dynamic registrations = data['registrations'];
      final dynamic records = data['records'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (events is List) {
        return events;
      }

      if (registrations is List) {
        return registrations;
      }

      if (records is List) {
        return records;
      }

      if (results is List) {
        return results;
      }

      if (docs is List) {
        return docs;
      }

      if (items is List) {
        return items;
      }
    }

    final dynamic events = response['events'];
    final dynamic registrations = response['registrations'];

    if (events is List) {
      return events;
    }

    if (registrations is List) {
      return registrations;
    }

    return <dynamic>[];
  }

  Future<void> _updateRegistrantStatus({
    required Map<String, dynamic> registrant,
    required String status,
  }) async {
    final String registrationId = _readString(registrant, <String>['_id', 'id']);

    if (registrationId.trim().isEmpty) {
      _showError('Registration ID was not found.');
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.patch(
        '/api/event-registrations/${Uri.encodeComponent(registrationId)}/status',
        requiresAuth: true,
        body: <String, dynamic>{
          'status': status,
        },
      );

      final Map<String, dynamic> updated = _extractMap(response);

      if (!mounted) {
        return;
      }

      setState(() {
        final int index = _registrants.indexWhere(
          (Map<String, dynamic> item) {
            return _readString(item, <String>['_id', 'id']) == registrationId;
          },
        );

        if (index >= 0) {
          _registrants[index] = updated;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registrant marked as ${_prettyEnum(status)}.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to update registrant status.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Map<String, dynamic> _extractMap(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return response;
  }

  void _showRegistrantDetails(Map<String, dynamic> registrant) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _RegistrantDetailsSheet(
          registrant: registrant,
          isUpdatingStatus: _isUpdatingStatus,
          onMarkRegistered: () {
            Navigator.of(context).pop();
            _updateRegistrantStatus(
              registrant: registrant,
              status: 'registered',
            );
          },
          onMarkAttended: () {
            Navigator.of(context).pop();
            _updateRegistrantStatus(
              registrant: registrant,
              status: 'attended',
            );
          },
          onMarkNoShow: () {
            Navigator.of(context).pop();
            _updateRegistrantStatus(
              registrant: registrant,
              status: 'no_show',
            );
          },
          onCancel: () {
            Navigator.of(context).pop();
            _updateRegistrantStatus(
              registrant: registrant,
              status: 'cancelled',
            );
          },
        );
      },
    );
  }

  void _showEventPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _EventPickerSheet(
          events: _events,
          selectedEvent: _selectedEvent,
          onSelected: (Map<String, dynamic> event) {
            Navigator.of(context).pop();
            _selectEvent(event);
          },
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filteredRegistrants =
        _filteredRegistrants;
    final Map<String, dynamic>? selectedEvent = _selectedEvent;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Event Registrants',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoadingEvents || _isLoadingRegistrants
                ? null
                : () async {
                    if (_selectedEvent == null) {
                      await _loadEvents();
                    } else {
                      await _loadRegistrantsForEvent(_selectedEvent!);
                    }
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (_selectedEvent == null) {
              await _loadEvents();
            } else {
              await _loadRegistrantsForEvent(_selectedEvent!);
            }
          },
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _HeaderCard(
                    selectedEvent: selectedEvent,
                    totalEvents: _events.length,
                    totalRegistrants: _registrants.length,
                    attended: _countByStatus('attended'),
                    onChooseEvent: _events.isEmpty ? null : _showEventPicker,
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StatusFilterHeaderDelegate(
                  selectedStatus: _selectedStatus,
                  onChanged: (String value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
              ),
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _ErrorCard(
                      message: _errorMessage!,
                      onRetry: () async {
                        if (_selectedEvent == null) {
                          await _loadEvents();
                        } else {
                          await _loadRegistrantsForEvent(_selectedEvent!);
                        }
                      },
                    ),
                  ),
                )
              else if (_isLoadingEvents || _isLoadingRegistrants)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _LoadingBox(),
                  ),
                )
              else if (_events.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyEventsState(),
                  ),
                )
              else if (filteredRegistrants.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyRegistrantsState(),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: filteredRegistrants.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> registrant =
                        filteredRegistrants[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: index == 0 ? 12 : 0,
                        bottom: 12,
                      ),
                      child: _RegistrantCard(
                        registrant: registrant,
                        onTap: () {
                          _showRegistrantDetails(registrant);
                        },
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 90),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.selectedEvent,
    required this.totalEvents,
    required this.totalRegistrants,
    required this.attended,
    required this.onChooseEvent,
  });

  final Map<String, dynamic>? selectedEvent;
  final int totalEvents;
  final int totalRegistrants;
  final int attended;
  final VoidCallback? onChooseEvent;

  @override
  Widget build(BuildContext context) {
    final String title = selectedEvent == null
        ? 'No Event Selected'
        : _eventTitle(selectedEvent!);

    final String eventDate = selectedEvent == null
        ? 'Choose an RHU event to view registrants.'
        : _eventDateLine(selectedEvent!);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.how_to_reg_rounded,
                color: Colors.white,
                size: 34,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Event Registrants',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            eventDate,
            style: const TextStyle(
              color: Color(0xFFDBEAFE),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Events',
                  value: totalEvents.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Registered',
                  value: totalRegistrants.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Attended',
                  value: attended.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2563EB),
              ),
              onPressed: onChooseEvent,
              icon: const Icon(Icons.event_rounded),
              label: const Text(
                'Choose Event',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDBEAFE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StatusFilterHeaderDelegate({
    required this.selectedStatus,
    required this.onChanged,
  });

  final String selectedStatus;
  final ValueChanged<String> onChanged;

  @override
  double get minExtent => 74;

  @override
  double get maxExtent => 74;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _FilterChipButton(
            label: 'All',
            value: 'all',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Registered',
            value: 'registered',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Attended',
            value: 'attended',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'No Show',
            value: 'no_show',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Cancelled',
            value: 'cancelled',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StatusFilterHeaderDelegate oldDelegate) {
    return oldDelegate.selectedStatus != selectedStatus;
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool selected = value == selectedValue;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        selectedColor: const Color(0xFF2563EB),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF1D4ED8),
          fontWeight: FontWeight.w900,
        ),
        side: BorderSide(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE),
        ),
        onSelected: (_) {
          onChanged(value);
        },
      ),
    );
  }
}

class _RegistrantCard extends StatelessWidget {
  const _RegistrantCard({
    required this.registrant,
    required this.onTap,
  });

  final Map<String, dynamic> registrant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String status = _readString(registrant, <String>['status']);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _statusIcon(status),
                  color: _statusColor(status),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _fallback(
                        _readString(registrant, <String>['attendeeName']),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _fallback(
                        _readString(registrant, <String>['contactNumber']),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registered: ${_formatDateTimeText(_readString(registrant, <String>['registeredAt', 'createdAt']))}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrantDetailsSheet extends StatelessWidget {
  const _RegistrantDetailsSheet({
    required this.registrant,
    required this.isUpdatingStatus,
    required this.onMarkRegistered,
    required this.onMarkAttended,
    required this.onMarkNoShow,
    required this.onCancel,
  });

  final Map<String, dynamic> registrant;
  final bool isUpdatingStatus;
  final VoidCallback onMarkRegistered;
  final VoidCallback onMarkAttended;
  final VoidCallback onMarkNoShow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final String status = _readString(registrant, <String>['status']);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(22),
            children: <Widget>[
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _fallback(
                        _readString(registrant, <String>['attendeeName']),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 18),
              _DetailsSection(
                title: 'Registrant Information',
                children: <Widget>[
                  _InfoLine(
                    label: 'Name',
                    value: _fallback(
                      _readString(registrant, <String>['attendeeName']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Contact',
                    value: _fallback(
                      _readString(registrant, <String>['contactNumber']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Email',
                    value: _fallback(
                      _readString(registrant, <String>['email']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Notes',
                    value: _fallback(
                      _readString(registrant, <String>['notes']),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsSection(
                title: 'Registration Record',
                children: <Widget>[
                  _InfoLine(
                    label: 'Registered',
                    value: _formatDateTimeText(
                      _readString(registrant, <String>['registeredAt']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Checked-in',
                    value: _formatDateTimeText(
                      _readString(registrant, <String>['checkedInAt']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Status',
                    value: _prettyEnum(status),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                    onPressed: isUpdatingStatus ? null : onMarkAttended,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Attended'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isUpdatingStatus ? null : onMarkRegistered,
                    icon: const Icon(Icons.how_to_reg_rounded),
                    label: const Text('Registered'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isUpdatingStatus ? null : onMarkNoShow,
                    icon: const Icon(Icons.person_off_rounded),
                    label: const Text('No Show'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isUpdatingStatus ? null : onCancel,
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.done_rounded),
                label: const Text('Done'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

class _EventPickerSheet extends StatelessWidget {
  const _EventPickerSheet({
    required this.events,
    required this.selectedEvent,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> events;
  final Map<String, dynamic>? selectedEvent;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    final String selectedId = selectedEvent == null
        ? ''
        : _readString(selectedEvent!, <String>['_id', 'id']);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Event',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              ...events.map((Map<String, dynamic> event) {
                final String eventId = _readString(event, <String>['_id', 'id']);
                final bool selected = eventId == selectedId;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    color: selected ? const Color(0xFFDBEAFE) : Colors.white,
                    child: ListTile(
                      leading: Icon(
                        Icons.event_rounded,
                        color: selected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                      ),
                      title: Text(
                        _eventTitle(event),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(_eventDateLine(event)),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF2563EB),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        onSelected(event);
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _prettyEnum(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 14),
            Expanded(
              child: Text('Loading event registrants...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEventsState extends StatelessWidget {
  const _EmptyEventsState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.event_busy_rounded,
              color: Color(0xFF2563EB),
              size: 52,
            ),
            SizedBox(height: 14),
            Text(
              'No events found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Create RHU events first. Registrants will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRegistrantsState extends StatelessWidget {
  const _EmptyRegistrantsState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.people_outline_rounded,
              color: Color(0xFF2563EB),
              size: 52,
            ),
            SizedBox(height: 14),
            Text(
              'No registrants found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Public users who register for this event will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
              'Unable to load event registrants',
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

String _eventTitle(Map<String, dynamic> event) {
  return _fallback(
    _readString(event, <String>['title', 'name'], fallback: 'RHU Event'),
  );
}

String _eventDateLine(Map<String, dynamic> event) {
  final DateTime date = _readDateTime(
    event,
    <String>['startDate', 'eventDate', 'scheduledAt', 'createdAt'],
  );

  return 'Event date: ${_formatDate(date)}';
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'attended':
      return Icons.check_circle_rounded;
    case 'no_show':
      return Icons.person_off_rounded;
    case 'cancelled':
      return Icons.cancel_rounded;
    default:
      return Icons.how_to_reg_rounded;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'attended':
      return const Color(0xFF16A34A);
    case 'no_show':
      return const Color(0xFFF59E0B);
    case 'cancelled':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF2563EB);
  }
}

String _prettyEnum(String value) {
  if (value.trim().isEmpty) {
    return 'N/A';
  }

  return value
      .split('_')
      .where((String item) => item.trim().isNotEmpty)
      .map((String item) {
    return item[0].toUpperCase() + item.substring(1);
  }).join(' ');
}

String _fallback(String value) {
  if (value.trim().isEmpty || value.trim() == 'null') {
    return 'N/A';
  }

  return value.trim();
}

DateTime _readDateTime(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      continue;
    }
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _formatDate(DateTime date) {
  if (date.year <= 1971) {
    return 'N/A';
  }

  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

String _formatDateTime(DateTime dateTime) {
  if (dateTime.year <= 1971) {
    return 'N/A';
  }

  final String year = dateTime.year.toString().padLeft(4, '0');
  final String month = dateTime.month.toString().padLeft(2, '0');
  final String day = dateTime.day.toString().padLeft(2, '0');

  final int hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final String minute = dateTime.minute.toString().padLeft(2, '0');
  final String period = dateTime.hour >= 12 ? 'PM' : 'AM';

  return '$year-$month-$day $hour12:$minute $period';
}

String _formatDateTimeText(String value) {
  if (value.trim().isEmpty || value.trim() == 'null') {
    return 'N/A';
  }

  try {
    return _formatDateTime(DateTime.parse(value).toLocal());
  } catch (_) {
    return value;
  }
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    if (value is Map<String, dynamic>) {
      final String nestedValue = _readString(
        value,
        <String>['name', 'title', 'fullName', 'email', '_id', 'id'],
      );

      if (nestedValue.trim().isNotEmpty) {
        return nestedValue;
      }
    }

    final String text = value.toString().trim();

    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }

  return fallback;
}
