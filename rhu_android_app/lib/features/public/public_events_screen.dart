import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/event_model.dart';
import 'public_provider.dart';

class PublicEventsScreen extends StatefulWidget {
  const PublicEventsScreen({super.key});

  static const String routeName = '/public-events';

  @override
  State<PublicEventsScreen> createState() => _PublicEventsScreenState();
}

class _PublicEventsScreenState extends State<PublicEventsScreen> {
  String? _selectedType;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicProvider>().loadEventsOnly();
    });
  }

  Future<void> _refresh() {
    return context.read<PublicProvider>().loadEventsOnly(
          type: _selectedType,
          refresh: true,
        );
  }

  Future<void> _changeType(String? value) async {
    setState(() {
      _selectedType = value;
    });

    await context.read<PublicProvider>().loadEventsOnly(
          type: value,
          refresh: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PublicProvider>(
      builder: (
        BuildContext context,
        PublicProvider provider,
        Widget? child,
      ) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Public Events',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: <Widget>[
              IconButton(
                onPressed: provider.isLoading ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  _HeaderCard(totalEvents: provider.events.length),
                  const SizedBox(height: 18),
                  _TypeFilter(
                    selectedType: _selectedType,
                    onChanged: _changeType,
                  ),
                  const SizedBox(height: 18),
                  if (provider.errorMessage != null)
                    _ErrorCard(
                      message: provider.errorMessage!,
                      onRetry: _refresh,
                    )
                  else if (provider.isLoading)
                    const _LoadingCard()
                  else if (!provider.hasEvents)
                    const _EmptyCard()
                  else
                    ...provider.events.map(
                      (EventModel event) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _EventCard(event: event),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
                  'RHU Events',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'View medical missions, vaccination schedules, seminars, and public health activities.',
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

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({
    required this.selectedType,
    required this.onChanged,
  });

  final String? selectedType;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedType ?? 'all',
      decoration: const InputDecoration(
        labelText: 'Event type',
        prefixIcon: Icon(Icons.filter_list_rounded),
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
          onChanged(null);
          return;
        }

        onChanged(value);
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
  });

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final String scheduleText = _formatSchedule(
      event.startDate,
      event.endDate,
    );

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
              ],
            ),
            const SizedBox(height: 14),
            Text(
              event.description,
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
                  ? event.isFull
                      ? 'Registration full'
                      : event.hasParticipantLimit
                          ? '${event.remainingSlots} slot/s remaining'
                          : 'Registration required'
                  : 'No registration required',
            ),
            if (event.contactPerson.trim().isNotEmpty ||
                event.contactNumber.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.phone_rounded,
                text:
                    '${event.contactPerson} ${event.contactNumber}'.trim(),
              ),
            ],
            if (event.requirements.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                'Requirements',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: event.requirements.map(
                  (String item) {
                    return Chip(
                      label: Text(item),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatSchedule(DateTime? start, DateTime? end) {
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
              'No public events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'RHU events and public health activities will appear here once published.',
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
              child: Text('Loading public events...'),
            ),
          ],
        ),
      ),
    );
  }
}