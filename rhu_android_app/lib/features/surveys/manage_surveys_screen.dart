import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'create_survey_screen.dart';
import 'edit_survey_screen.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/survey_model.dart';
import '../../data/repositories/survey_repository.dart';


class ManageSurveysScreen extends StatefulWidget {
  const ManageSurveysScreen({super.key});

  static const String routeName = '/manage-surveys';

  @override
  State<ManageSurveysScreen> createState() => _ManageSurveysScreenState();
}

class _ManageSurveysScreenState extends State<ManageSurveysScreen> {
  final SurveyRepository _surveyRepository = SurveyRepository();

  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedStatus;
  String? _selectedType;

  List<SurveyModel> _surveys = <SurveyModel>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSurveys();
    });
  }

  Future<void> _openEditSurvey(SurveyModel survey) async {
    final Object? result = await Navigator.of(context).pushNamed(
      EditSurveyScreen.routeName,
      arguments: EditSurveyArguments(
        survey: survey,
      ),
    );

    if (result == true && mounted) {
      await _loadSurveys();
    }
  }

  Future<void> _deleteSurvey(SurveyModel survey) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Survey?'),
          content: Text(
            'Are you sure you want to delete "${survey.title}"?',
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
      await _surveyRepository.deleteSurvey(survey.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Survey deleted successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      await _loadSurveys();
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
          content: Text('Unable to delete survey.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _loadSurveys() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<SurveyModel> result = await _surveyRepository.getStaffSurveys(
        type: _selectedType,
        status: _selectedStatus,
      );

      setState(() {
        _surveys = result;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Unable to load surveys.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openCreateSurvey() async {
    await Navigator.of(context).pushNamed(CreateSurveyScreen.routeName);

    if (!mounted) {
      return;
    }

    await _loadSurveys();
  }

  Future<void> _setStatus(String? value) async {
    setState(() {
      _selectedStatus = value;
    });

    await _loadSurveys();
  }

  Future<void> _setType(String? value) async {
    setState(() {
      _selectedType = value;
    });

    await _loadSurveys();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedStatus = null;
      _selectedType = null;
    });

    await _loadSurveys();
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Surveys',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _isLoading ? null : _loadSurveys,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSurvey,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Survey'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSurveys,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _HeaderCard(totalSurveys: _surveys.length),
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
                  onRetry: _loadSurveys,
                )
              else if (_isLoading)
                const _LoadingCard()
              else if (_surveys.isEmpty)
                const _EmptyCard()
              else
                ..._surveys.map(
                  (SurveyModel survey) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SurveyCard(
                        survey: survey,
                        dateText: _formatDateRange(
                          survey.startDate,
                          survey.endDate,
                        ),
                        onEdit: () => _openEditSurvey(survey),
                        onDelete: () => _deleteSurvey(survey),
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
                  'Survey Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create and view community surveys, feedback forms, and health assessment questionnaires.',
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
                  value: 'archived',
                  child: Text('Archived'),
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
                labelText: 'Survey type',
                prefixIcon: Icon(Icons.category_rounded),
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

class _SurveyCard extends StatelessWidget {
  const _SurveyCard({
    required this.survey,
    required this.dateText,
    required this.onEdit,
    required this.onDelete,
  });

  final SurveyModel survey;
  final String dateText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = survey.isOpen
        ? const Color(0xFF16A34A)
        : survey.isClosed
            ? const Color(0xFFDC2626)
            : const Color(0xFFF59E0B);

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
                        style: TextStyle(
                          color: statusColor,
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
                      tooltip: 'Edit survey',
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete survey',
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
              survey.shortDescription,
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
              text: survey.requiresLogin ? 'Login required' : 'Open public survey',
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
              'No surveys found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new survey or clear your filters.',
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
              child: Text('Loading surveys...'),
            ),
          ],
        ),
      ),
    );
  }
}