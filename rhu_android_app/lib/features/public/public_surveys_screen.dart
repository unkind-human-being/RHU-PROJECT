import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/survey_model.dart';
import 'public_provider.dart';

class PublicSurveysScreen extends StatefulWidget {
  const PublicSurveysScreen({super.key});

  static const String routeName = '/public-surveys';

  @override
  State<PublicSurveysScreen> createState() => _PublicSurveysScreenState();
}

class _PublicSurveysScreenState extends State<PublicSurveysScreen> {
  String? _selectedType;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicProvider>().loadSurveysOnly();
    });
  }

  Future<void> _refresh() {
    return context.read<PublicProvider>().loadSurveysOnly(
          type: _selectedType,
          refresh: true,
        );
  }

  Future<void> _changeType(String? value) async {
    setState(() {
      _selectedType = value;
    });

    await context.read<PublicProvider>().loadSurveysOnly(
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
              'Public Surveys',
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
                  _HeaderCard(totalSurveys: provider.surveys.length),
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
                  else if (!provider.hasSurveys)
                    const _EmptyCard()
                  else
                    ...provider.surveys.map(
                      (SurveyModel survey) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SurveyCard(survey: survey),
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
    required this.totalSurveys,
  });

  final int totalSurveys;

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
              Icons.poll_rounded,
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
                  'Community Surveys',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'View RHU surveys for health feedback, community needs, and service assessment.',
                  style: TextStyle(
                    color: Color(0xFFE0F2F1),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$totalSurveys survey/s loaded',
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
        labelText: 'Survey type',
        prefixIcon: Icon(Icons.filter_list_rounded),
      ),
      items: const <DropdownMenuItem<String>>[
        DropdownMenuItem<String>(
          value: 'all',
          child: Text('All survey types'),
        ),
        DropdownMenuItem<String>(
          value: 'community_needs',
          child: Text('Community Needs'),
        ),
        DropdownMenuItem<String>(
          value: 'feedback',
          child: Text('Feedback'),
        ),
        DropdownMenuItem<String>(
          value: 'health_assessment',
          child: Text('Health Assessment'),
        ),
        DropdownMenuItem<String>(
          value: 'service_satisfaction',
          child: Text('Service Satisfaction'),
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

class _SurveyCard extends StatelessWidget {
  const _SurveyCard({
    required this.survey,
  });

  final SurveyModel survey;

  @override
  Widget build(BuildContext context) {
    final String dateText = _formatDateRange(
      survey.startDate,
      survey.endDate,
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
                    Icons.fact_check_rounded,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        survey.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${survey.typeLabel} • ${survey.statusLabel}',
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
              survey.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            _InfoLine(
              icon: Icons.location_on_rounded,
              text: survey.audienceLocation,
            ),
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.schedule_rounded,
              text: dateText,
            ),
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.question_answer_rounded,
              text: '${survey.questions.length} question/s',
            ),
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.people_rounded,
              text: '${survey.responseCount} response/s',
            ),
            const SizedBox(height: 8),
            _InfoLine(
              icon: survey.requiresLogin
                  ? Icons.lock_rounded
                  : Icons.public_rounded,
              text: survey.requiresLogin
                  ? 'Login required to answer'
                  : 'Open public survey',
            ),
            if (survey.questions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                'Questions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...survey.questions.take(3).map(
                    (SurveyQuestionModel question) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _QuestionPreview(question: question),
                    ),
                  ),
              if (survey.questions.length > 3)
                Text(
                  '+${survey.questions.length - 3} more question/s',
                  style: const TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      return 'Survey date not specified';
    }

    if (start != null && end == null) {
      return 'Starts ${DateFormat('MMM d, yyyy').format(start)}';
    }

    if (start == null && end != null) {
      return 'Ends ${DateFormat('MMM d, yyyy').format(end)}';
    }

    return '${DateFormat('MMM d, yyyy').format(start!)} - ${DateFormat('MMM d, yyyy').format(end!)}';
  }
}

class _QuestionPreview extends StatelessWidget {
  const _QuestionPreview({
    required this.question,
  });

  final SurveyQuestionModel question;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            question.questionText,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question.isRequired
                ? '${question.typeLabel} • Required'
                : question.typeLabel,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
              'Unable to load surveys',
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
                Icons.poll_outlined,
                color: Color(0xFF0F766E),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No public surveys',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'RHU surveys and community feedback forms will appear here once published.',
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
              child: Text('Loading public surveys...'),
            ),
          ],
        ),
      ),
    );
  }
}