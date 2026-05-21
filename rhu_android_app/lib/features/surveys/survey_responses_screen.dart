import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class SurveyResponsesScreen extends StatefulWidget {
  const SurveyResponsesScreen({super.key});

  static const String routeName = '/survey-responses';

  @override
  State<SurveyResponsesScreen> createState() => _SurveyResponsesScreenState();
}

class _SurveyResponsesScreenState extends State<SurveyResponsesScreen> {
  late final ApiClient _apiClient;

  bool _isLoadingSurveys = false;
  bool _isLoadingResponses = false;

  String? _errorMessage;
  String _searchText = '';

  List<Map<String, dynamic>> _surveys = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _responses = <Map<String, dynamic>>[];

  Map<String, dynamic>? _selectedSurvey;

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSurveys();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredResponses {
    final String query = _searchText.trim().toLowerCase();

    if (query.isEmpty) {
      return _responses;
    }

    return _responses.where((Map<String, dynamic> response) {
      final String name = _readString(
        response,
        <String>['respondentName'],
      ).toLowerCase();

      final String contact = _readString(
        response,
        <String>['contactNumber'],
      ).toLowerCase();

      final String email = _readString(
        response,
        <String>['email'],
      ).toLowerCase();

      final List<dynamic> answers = response['answers'] is List
          ? response['answers'] as List<dynamic>
          : <dynamic>[];

      final bool answerMatches = answers.any((dynamic rawAnswer) {
        if (rawAnswer is! Map<String, dynamic>) {
          return false;
        }

        final String question = _readString(
          rawAnswer,
          <String>['questionText', 'question'],
        ).toLowerCase();

        final String answer = _readString(
          rawAnswer,
          <String>['answer'],
        ).toLowerCase();

        return question.contains(query) || answer.contains(query);
      });

      return name.contains(query) ||
          contact.contains(query) ||
          email.contains(query) ||
          answerMatches;
    }).toList();
  }

  Future<void> _loadSurveys() async {
    setState(() {
      _isLoadingSurveys = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/surveys',
        requiresAuth: true,
        queryParameters: <String, dynamic>{
          'limit': 100,
        },
      );

      final List<dynamic> rawSurveys = _extractList(response);

      final List<Map<String, dynamic>> surveys = rawSurveys
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      surveys.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime bDate = _readDateTime(
          b,
          <String>['createdAt', 'publishedAt', 'startDate'],
        );
        final DateTime aDate = _readDateTime(
          a,
          <String>['createdAt', 'publishedAt', 'startDate'],
        );

        return bDate.compareTo(aDate);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _surveys = surveys;
      });

      if (surveys.isNotEmpty) {
        await _selectSurvey(surveys.first);
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
        _errorMessage = 'Unable to load RHU surveys.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSurveys = false;
        });
      }
    }
  }

  Future<void> _selectSurvey(Map<String, dynamic> survey) async {
    setState(() {
      _selectedSurvey = survey;
      _responses = <Map<String, dynamic>>[];
      _searchText = '';
    });

    await _loadResponsesForSurvey(survey);
  }

  Future<void> _loadResponsesForSurvey(Map<String, dynamic> survey) async {
    final String surveyId = _readString(survey, <String>['_id', 'id']);

    if (surveyId.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Survey ID was not found.';
      });
      return;
    }

    setState(() {
      _isLoadingResponses = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/survey-responses/survey/${Uri.encodeComponent(surveyId)}',
        requiresAuth: true,
      );

      final List<dynamic> rawResponses = _extractList(response);

      final List<Map<String, dynamic>> responses = rawResponses
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      responses.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime bDate = _readDateTime(
          b,
          <String>['submittedAt', 'createdAt'],
        );
        final DateTime aDate = _readDateTime(
          a,
          <String>['submittedAt', 'createdAt'],
        );

        return bDate.compareTo(aDate);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _responses = responses;
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
        _errorMessage = 'Unable to load survey responses.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingResponses = false;
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
      final dynamic surveys = data['surveys'];
      final dynamic responses = data['responses'];
      final dynamic records = data['records'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (surveys is List) {
        return surveys;
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

    final dynamic surveys = response['surveys'];
    final dynamic responses = response['responses'];

    if (surveys is List) {
      return surveys;
    }

    if (responses is List) {
      return responses;
    }

    return <dynamic>[];
  }

  void _showResponseDetails(Map<String, dynamic> response) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _ResponseDetailsSheet(response: response);
      },
    );
  }

  void _showSurveyPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _SurveyPickerSheet(
          surveys: _surveys,
          selectedSurvey: _selectedSurvey,
          onSelected: (Map<String, dynamic> survey) {
            Navigator.of(context).pop();
            _selectSurvey(survey);
          },
        );
      },
    );
  }

  Future<void> _refreshCurrent() async {
    if (_selectedSurvey == null) {
      await _loadSurveys();
      return;
    }

    await _loadResponsesForSurvey(_selectedSurvey!);
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filteredResponses = _filteredResponses;
    final Map<String, dynamic>? selectedSurvey = _selectedSurvey;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Survey Responses',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoadingSurveys || _isLoadingResponses
                ? null
                : _refreshCurrent,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshCurrent,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _HeaderCard(
                    selectedSurvey: selectedSurvey,
                    totalSurveys: _surveys.length,
                    totalResponses: _responses.length,
                    totalQuestions: _surveyQuestionCount(selectedSurvey),
                    onChooseSurvey: _surveys.isEmpty ? null : _showSurveyPicker,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: _SearchBox(
                    onChanged: (String value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                  ),
                ),
              ),
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _ErrorCard(
                      message: _errorMessage!,
                      onRetry: _refreshCurrent,
                    ),
                  ),
                )
              else if (_isLoadingSurveys || _isLoadingResponses)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _LoadingBox(),
                  ),
                )
              else if (_surveys.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptySurveysState(),
                  ),
                )
              else if (filteredResponses.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyResponsesState(),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: filteredResponses.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> response =
                        filteredResponses[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: index == 0 ? 12 : 0,
                        bottom: 12,
                      ),
                      child: _ResponseCard(
                        response: response,
                        onTap: () {
                          _showResponseDetails(response);
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
    required this.selectedSurvey,
    required this.totalSurveys,
    required this.totalResponses,
    required this.totalQuestions,
    required this.onChooseSurvey,
  });

  final Map<String, dynamic>? selectedSurvey;
  final int totalSurveys;
  final int totalResponses;
  final int totalQuestions;
  final VoidCallback? onChooseSurvey;

  @override
  Widget build(BuildContext context) {
    final String title = selectedSurvey == null
        ? 'No Survey Selected'
        : _surveyTitle(selectedSurvey!);

    final String description = selectedSurvey == null
        ? 'Choose an RHU survey to view public responses.'
        : _fallback(
            _readString(
              selectedSurvey!,
              <String>['description', 'details', 'content'],
            ),
          );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF7C3AED),
            Color(0xFF5B21B6),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
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
                Icons.poll_rounded,
                color: Colors.white,
                size: 34,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Survey Responses',
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
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFEDE9FE),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Surveys',
                  value: totalSurveys.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Responses',
                  value: totalResponses.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Questions',
                  value: totalQuestions.toString(),
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
                foregroundColor: const Color(0xFF7C3AED),
              ),
              onPressed: onChooseSurvey,
              icon: const Icon(Icons.assignment_rounded),
              label: const Text(
                'Choose Survey',
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
              color: Color(0xFFEDE9FE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.onChanged,
  });

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search respondent, contact, question, or answer...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFDDD6FE),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFDDD6FE),
          ),
        ),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({
    required this.response,
    required this.onTap,
  });

  final Map<String, dynamic> response;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> answers = response['answers'] is List
        ? response['answers'] as List<dynamic>
        : <dynamic>[];

    final String previewAnswer = _firstAnswerPreview(answers);

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
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _fallback(
                        _readString(response, <String>['respondentName']),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${answers.length} answer(s) • ${_formatDateTimeText(_readString(response, <String>['submittedAt', 'createdAt']))}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (previewAnswer.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        previewAnswer,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7C3AED),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponseDetailsSheet extends StatelessWidget {
  const _ResponseDetailsSheet({
    required this.response,
  });

  final Map<String, dynamic> response;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> answers = response['answers'] is List
        ? response['answers'] as List<dynamic>
        : <dynamic>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
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
              Text(
                _fallback(
                  _readString(response, <String>['respondentName']),
                ),
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Submitted: ${_formatDateTimeText(_readString(response, <String>['submittedAt', 'createdAt']))}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _DetailsSection(
                title: 'Respondent Information',
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
                ],
              ),
              const SizedBox(height: 16),
              _DetailsSection(
                title: 'Survey Answers',
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
                        final dynamic rawAnswer = entry.value;

                        if (rawAnswer is! Map<String, dynamic>) {
                          return const SizedBox.shrink();
                        }

                        return _AnswerBox(
                          index: entry.key + 1,
                          answer: rawAnswer,
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
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

class _SurveyPickerSheet extends StatelessWidget {
  const _SurveyPickerSheet({
    required this.surveys,
    required this.selectedSurvey,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> surveys;
  final Map<String, dynamic>? selectedSurvey;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    final String selectedId = selectedSurvey == null
        ? ''
        : _readString(selectedSurvey!, <String>['_id', 'id']);

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
                'Choose Survey',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              ...surveys.map((Map<String, dynamic> survey) {
                final String surveyId =
                    _readString(survey, <String>['_id', 'id']);
                final bool selected = surveyId == selectedId;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    color: selected ? const Color(0xFFEDE9FE) : Colors.white,
                    child: ListTile(
                      leading: Icon(
                        Icons.poll_rounded,
                        color: selected
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF64748B),
                      ),
                      title: Text(
                        _surveyTitle(survey),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        _readString(
                          survey,
                          <String>['description', 'details', 'content'],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF7C3AED),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        onSelected(survey);
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
              child: Text('Loading survey responses...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySurveysState extends StatelessWidget {
  const _EmptySurveysState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.assignment_outlined,
              color: Color(0xFF7C3AED),
              size: 52,
            ),
            SizedBox(height: 14),
            Text(
              'No surveys found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Create RHU surveys first. Responses will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResponsesState extends StatelessWidget {
  const _EmptyResponsesState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.rate_review_outlined,
              color: Color(0xFF7C3AED),
              size: 52,
            ),
            SizedBox(height: 14),
            Text(
              'No responses found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Public users who answer this survey will appear here.',
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
              'Unable to load survey responses',
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

int _surveyQuestionCount(Map<String, dynamic>? survey) {
  if (survey == null) {
    return 0;
  }

  final dynamic questions =
      survey['questions'] ?? survey['items'] ?? survey['surveyQuestions'];

  if (questions is List) {
    return questions.length;
  }

  return 0;
}

String _surveyTitle(Map<String, dynamic> survey) {
  return _fallback(
    _readString(survey, <String>['title', 'name'], fallback: 'RHU Survey'),
  );
}

String _firstAnswerPreview(List<dynamic> answers) {
  if (answers.isEmpty) {
    return '';
  }

  final dynamic firstAnswer = answers.first;

  if (firstAnswer is! Map<String, dynamic>) {
    return '';
  }

  final String question = _readString(
    firstAnswer,
    <String>['questionText', 'question'],
  );

  final String answer = _readString(
    firstAnswer,
    <String>['answer'],
  );

  if (question.trim().isEmpty && answer.trim().isEmpty) {
    return '';
  }

  return '$question: $answer';
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
