import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class PublicActivityHistoryScreen extends StatefulWidget {
  const PublicActivityHistoryScreen({super.key});

  static const String routeName = '/public-activity-history';

  @override
  State<PublicActivityHistoryScreen> createState() =>
      _PublicActivityHistoryScreenState();
}

class _PublicActivityHistoryScreenState
    extends State<PublicActivityHistoryScreen> {
  late final ApiClient _apiClient;

  bool _isLoading = false;
  String? _errorMessage;

  String _selectedFilter = 'all';

  List<Map<String, dynamic>> _eventRegistrations = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _surveyResponses = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActivities();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  List<_PublicActivityItem> get _activities {
    final List<_PublicActivityItem> items = <_PublicActivityItem>[
      ..._eventRegistrations.map(_PublicActivityItem.fromEventRegistration),
      ..._surveyResponses.map(_PublicActivityItem.fromSurveyResponse),
    ];

    items.sort((_PublicActivityItem a, _PublicActivityItem b) {
      return b.createdAt.compareTo(a.createdAt);
    });

    if (_selectedFilter == 'all') {
      return items;
    }

    return items.where((_PublicActivityItem item) {
      return item.type == _selectedFilter;
    }).toList();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Map<String, dynamic>> eventRegistrations =
          <Map<String, dynamic>>[];
      final List<Map<String, dynamic>> surveyResponses =
          <Map<String, dynamic>>[];

      final Map<String, dynamic> eventResponse = await _apiClient.get(
        '/api/event-registrations/my',
        requiresAuth: true,
      );

      eventRegistrations.addAll(
        _extractList(eventResponse)
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item)),
      );

      final Map<String, dynamic> surveyResponse = await _apiClient.get(
        '/api/survey-responses/my',
        requiresAuth: true,
      );

      surveyResponses.addAll(
        _extractList(surveyResponse)
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item)),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _eventRegistrations = eventRegistrations;
        _surveyResponses = surveyResponses;
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
        _errorMessage = 'Unable to load your event and survey activity.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
      final dynamic registrations = data['registrations'];
      final dynamic responses = data['responses'];
      final dynamic records = data['records'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (registrations is List) {
        return registrations;
      }

      if (responses is List) {
        return responses;
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

    final dynamic registrations = response['registrations'];
    final dynamic responses = response['responses'];

    if (registrations is List) {
      return registrations;
    }

    if (responses is List) {
      return responses;
    }

    return <dynamic>[];
  }

  void _showActivityDetails(_PublicActivityItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _ActivityDetailsSheet(item: item);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_PublicActivityItem> activities = _activities;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        title: const Text(
          'My RHU Activity',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadActivities,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadActivities,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _HeaderCard(
                    eventCount: _eventRegistrations.length,
                    surveyCount: _surveyResponses.length,
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterHeaderDelegate(
                  selectedFilter: _selectedFilter,
                  onChanged: (String value) {
                    setState(() {
                      _selectedFilter = value;
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
                      onRetry: _loadActivities,
                    ),
                  ),
                )
              else if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _LoadingBox(),
                  ),
                )
              else if (activities.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyState(),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: activities.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _PublicActivityItem item = activities[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: index == 0 ? 12 : 0,
                        bottom: 12,
                      ),
                      child: _ActivityCard(
                        item: item,
                        onTap: () {
                          _showActivityDetails(item);
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

class _PublicActivityItem {
  const _PublicActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.createdAt,
    required this.rawJson,
  });

  factory _PublicActivityItem.fromEventRegistration(
    Map<String, dynamic> json,
  ) {
    final dynamic event = json['event'];

    String title = 'Event Registration';

    if (event is Map<String, dynamic>) {
      title = _readString(
        event,
        <String>['title', 'name'],
        fallback: title,
      );
    }

    return _PublicActivityItem(
      id: _readString(json, <String>['_id', 'id']),
      type: 'event',
      title: title,
      subtitle:
          'Registered: ${_formatDateTimeText(_readString(json, <String>['registeredAt', 'createdAt']))}',
      status: _readString(
        json,
        <String>['status'],
        fallback: 'registered',
      ),
      createdAt: _readDateTime(json, <String>['registeredAt', 'createdAt']),
      rawJson: json,
    );
  }

  factory _PublicActivityItem.fromSurveyResponse(
    Map<String, dynamic> json,
  ) {
    final dynamic survey = json['survey'];

    String title = 'Survey Response';

    if (survey is Map<String, dynamic>) {
      title = _readString(
        survey,
        <String>['title', 'name'],
        fallback: title,
      );
    }

    final List<dynamic> answers = json['answers'] is List
        ? json['answers'] as List<dynamic>
        : <dynamic>[];

    return _PublicActivityItem(
      id: _readString(json, <String>['_id', 'id']),
      type: 'survey',
      title: title,
      subtitle:
          '${answers.length} answer(s) • ${_formatDateTimeText(_readString(json, <String>['submittedAt', 'createdAt']))}',
      status: 'submitted',
      createdAt: _readDateTime(json, <String>['submittedAt', 'createdAt']),
      rawJson: json,
    );
  }

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> rawJson;

  String get typeLabel {
    switch (type) {
      case 'survey':
        return 'Survey';
      default:
        return 'Event';
    }
  }

  IconData get icon {
    switch (type) {
      case 'survey':
        return Icons.poll_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'survey':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF2563EB);
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.eventCount,
    required this.surveyCount,
  });

  final int eventCount;
  final int surveyCount;

  @override
  Widget build(BuildContext context) {
    final int total = eventCount + surveyCount;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0EA5E9),
            Color(0xFF0284C7),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
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
                Icons.fact_check_rounded,
                color: Colors.white,
                size: 34,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'My RHU Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Track your event registrations and submitted survey responses.',
            style: TextStyle(
              color: Color(0xFFE0F2FE),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Total',
                  value: total.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Events',
                  value: eventCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Surveys',
                  value: surveyCount.toString(),
                ),
              ),
            ],
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
              color: Color(0xFFE0F2FE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterHeaderDelegate({
    required this.selectedFilter,
    required this.onChanged,
  });

  final String selectedFilter;
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
      color: const Color(0xFFEFF6FF),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _FilterChipButton(
            label: 'All',
            value: 'all',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Events',
            value: 'event',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Surveys',
            value: 'survey',
            selectedValue: selectedFilter,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return oldDelegate.selectedFilter != selectedFilter;
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
        selectedColor: const Color(0xFF0EA5E9),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF075985),
          fontWeight: FontWeight.w900,
        ),
        side: BorderSide(
          color: selected ? const Color(0xFF0EA5E9) : const Color(0xFFBAE6FD),
        ),
        onSelected: (_) {
          onChanged(value);
        },
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.item,
    required this.onTap,
  });

  final _PublicActivityItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: item.color.withValues(alpha: 0.25),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.typeLabel,
                      style: TextStyle(
                        color: item.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                status: item.status,
                color: item.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.color,
  });

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
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

class _ActivityDetailsSheet extends StatelessWidget {
  const _ActivityDetailsSheet({
    required this.item,
  });

  final _PublicActivityItem item;

  @override
  Widget build(BuildContext context) {
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
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (item.type == 'event')
                _EventRegistrationDetails(registration: item.rawJson)
              else
                _SurveyResponseDetails(response: item.rawJson),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: item.color,
                ),
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

class _EventRegistrationDetails extends StatelessWidget {
  const _EventRegistrationDetails({
    required this.registration,
  });

  final Map<String, dynamic> registration;

  @override
  Widget build(BuildContext context) {
    return _DetailsSection(
      title: 'Event Registration',
      children: <Widget>[
        _InfoLine(
          label: 'Status',
          value: _prettyEnum(
            _readString(registration, <String>['status']),
          ),
        ),
        _InfoLine(
          label: 'Name',
          value: _fallback(
            _readString(registration, <String>['attendeeName']),
          ),
        ),
        _InfoLine(
          label: 'Contact',
          value: _fallback(
            _readString(registration, <String>['contactNumber']),
          ),
        ),
        _InfoLine(
          label: 'Email',
          value: _fallback(
            _readString(registration, <String>['email']),
          ),
        ),
        _InfoLine(
          label: 'Registered',
          value: _formatDateTimeText(
            _readString(registration, <String>['registeredAt', 'createdAt']),
          ),
        ),
        _InfoLine(
          label: 'Checked In',
          value: _formatDateTimeText(
            _readString(registration, <String>['checkedInAt']),
          ),
        ),
        _InfoLine(
          label: 'Notes',
          value: _fallback(
            _readString(registration, <String>['notes']),
          ),
        ),
      ],
    );
  }
}

class _SurveyResponseDetails extends StatelessWidget {
  const _SurveyResponseDetails({
    required this.response,
  });

  final Map<String, dynamic> response;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> answers = response['answers'] is List
        ? response['answers'] as List<dynamic>
        : <dynamic>[];

    return Column(
      children: <Widget>[
        _DetailsSection(
          title: 'Survey Submission',
          children: <Widget>[
            _InfoLine(
              label: 'Name',
              value: _fallback(
                _readString(response, <String>['respondentName']),
              ),
            ),
            _InfoLine(
              label: 'Contact',
              value: _fallback(
                _readString(response, <String>['contactNumber']),
              ),
            ),
            _InfoLine(
              label: 'Email',
              value: _fallback(
                _readString(response, <String>['email']),
              ),
            ),
            _InfoLine(
              label: 'Submitted',
              value: _formatDateTimeText(
                _readString(response, <String>['submittedAt', 'createdAt']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DetailsSection(
          title: 'Answers',
          children: <Widget>[
            if (answers.isEmpty)
              const Text(
                'No answers found.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              ...answers.asMap().entries.map(
                (MapEntry<int, dynamic> entry) {
                  if (entry.value is! Map<String, dynamic>) {
                    return const SizedBox.shrink();
                  }

                  final Map<String, dynamic> answer =
                      entry.value as Map<String, dynamic>;

                  return _AnswerBox(
                    index: entry.key + 1,
                    answer: answer,
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _AnswerBox extends StatelessWidget {
  const _AnswerBox({
    required this.index,
    required this.answer,
  });

  final int index;
  final Map<String, dynamic> answer;

  @override
  Widget build(BuildContext context) {
    final String question = _readString(
      answer,
      <String>['questionText', 'question'],
      fallback: 'Question $index',
    );

    final String answerText = _readString(
      answer,
      <String>['answer'],
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFDDD6FE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$index. $question',
            style: const TextStyle(
              color: Color(0xFF5B21B6),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _fallback(answerText),
            style: const TextStyle(
              color: Color(0xFF1F2937),
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
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

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 14),
            Expanded(
              child: Text('Loading your RHU activity...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.fact_check_outlined,
              color: Color(0xFF0EA5E9),
              size: 54,
            ),
            SizedBox(height: 16),
            Text(
              'No activity yet',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your event registrations and survey submissions will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
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
      color: Colors.white,
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
              'Unable to load activity',
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
