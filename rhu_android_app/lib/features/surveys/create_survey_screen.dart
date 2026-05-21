import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/survey_model.dart';
import '../../data/repositories/survey_repository.dart';
import '../auth/auth_provider.dart';

class CreateSurveyScreen extends StatefulWidget {
  const CreateSurveyScreen({super.key});

  static const String routeName = '/create-survey';

  @override
  State<CreateSurveyScreen> createState() => _CreateSurveyScreenState();
}

class _CreateSurveyScreenState extends State<CreateSurveyScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final SurveyRepository _surveyRepository = SurveyRepository();
  final List<_QuestionInput> _questions = <_QuestionInput>[_QuestionInput()];

  String _type = 'community_needs';
  String _status = 'open';
  String _audienceScope = 'public';

  bool _requiresLogin = false;
  bool _allowMultipleResponses = false;
  bool _isSaving = false;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    for (final _QuestionInput question in _questions) {
      question.dispose();
    }

    super.dispose();
  }

  bool _needsOptions(String type) {
    return type == 'multiple_choice' || type == 'checkbox';
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  Future<void> _pickStartDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _startDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 30));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _endDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        23,
        59,
        59,
      );
    });
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_QuestionInput());
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one question is required.'),
        ),
      );
      return;
    }

    final _QuestionInput removed = _questions.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  List<SurveyQuestionModel> _buildQuestions() {
    final List<SurveyQuestionModel> result = <SurveyQuestionModel>[];

    for (int index = 0; index < _questions.length; index++) {
      final _QuestionInput input = _questions[index];

      final List<String> options = input.optionsController.text
          .split(',')
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toList();

      result.add(
        SurveyQuestionModel(
          questionText: input.questionController.text.trim(),
          type: input.type,
          options: options,
          isRequired: input.isRequired,
          order: index + 1,
        ),
      );
    }

    return result;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final AuthProvider authProvider = context.read<AuthProvider>();
      final String? rhuId = authProvider.user?.rhuId;
      final String? barangayId = authProvider.user?.barangayId;

      if (rhuId == null || rhuId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'RHU is required. This account is not assigned to an RHU.',
            ),
            backgroundColor: Color(0xFFDC2626),
          ),
        );

        setState(() {
          _isSaving = false;
        });

        return;
      }

      await _surveyRepository.createSurvey(
        title: _titleController.text,
        description: _descriptionController.text,
        type: _type,
        status: _status,
        audienceScope: _audienceScope,
        rhuId: rhuId,
        barangayId: barangayId,
        requiresLogin: _requiresLogin,
        allowMultipleResponses: _allowMultipleResponses,
        startDate: _startDate,
        endDate: _endDate,
        questions: _buildQuestions(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Survey created successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      _resetForm();
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
          content: Text('Unable to create survey.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();

    for (final _QuestionInput question in _questions) {
      question.dispose();
    }

    _questions
      ..clear()
      ..add(_QuestionInput());

    setState(() {
      _type = 'community_needs';
      _status = 'open';
      _audienceScope = 'public';
      _requiresLogin = false;
      _allowMultipleResponses = false;
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 30));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Survey',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              const _HeaderCard(),
              const SizedBox(height: 18),
              _SurveyDetailsCard(
                titleController: _titleController,
                descriptionController: _descriptionController,
                type: _type,
                status: _status,
                audienceScope: _audienceScope,
                requiresLogin: _requiresLogin,
                allowMultipleResponses: _allowMultipleResponses,
                startDateText: _formatDate(_startDate),
                endDateText: _formatDate(_endDate),
                onTypeChanged: (String value) {
                  setState(() {
                    _type = value;
                  });
                },
                onStatusChanged: (String value) {
                  setState(() {
                    _status = value;
                  });
                },
                onAudienceChanged: (String value) {
                  setState(() {
                    _audienceScope = value;
                  });
                },
                onRequiresLoginChanged: (bool value) {
                  setState(() {
                    _requiresLogin = value;
                  });
                },
                onAllowMultipleChanged: (bool value) {
                  setState(() {
                    _allowMultipleResponses = value;
                  });
                },
                onPickStartDate: _pickStartDate,
                onPickEndDate: _pickEndDate,
              ),
              const SizedBox(height: 18),
              Text(
                'Survey Questions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...List<Widget>.generate(
                _questions.length,
                (int index) {
                  final _QuestionInput question = _questions[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _QuestionCard(
                      index: index,
                      question: question,
                      needsOptions: _needsOptions(question.type),
                      onRemove: () => _removeQuestion(index),
                      onTypeChanged: (String value) {
                        setState(() {
                          question.type = value;
                        });
                      },
                      onRequiredChanged: (bool value) {
                        setState(() {
                          question.isRequired = value;
                        });
                      },
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _addQuestion,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Question'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving ? 'Creating Survey...' : 'Create Survey',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionInput {
  _QuestionInput();

  final TextEditingController questionController = TextEditingController();
  final TextEditingController optionsController = TextEditingController();

  String type = 'short_text';
  bool isRequired = true;

  void dispose() {
    questionController.dispose();
    optionsController.dispose();
  }
}

class _SurveyDetailsCard extends StatelessWidget {
  const _SurveyDetailsCard({
    required this.titleController,
    required this.descriptionController,
    required this.type,
    required this.status,
    required this.audienceScope,
    required this.requiresLogin,
    required this.allowMultipleResponses,
    required this.startDateText,
    required this.endDateText,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onAudienceChanged,
    required this.onRequiresLoginChanged,
    required this.onAllowMultipleChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;

  final String type;
  final String status;
  final String audienceScope;
  final bool requiresLogin;
  final bool allowMultipleResponses;
  final String startDateText;
  final String endDateText;

  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onAudienceChanged;
  final ValueChanged<bool> onRequiresLoginChanged;
  final ValueChanged<bool> onAllowMultipleChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Survey title',
                hintText: 'Example: Community Health Needs Survey',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (String? value) {
                final String text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return 'Survey title is required.';
                }

                if (text.length < 4) {
                  return 'Survey title is too short.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: descriptionController,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Survey description',
                hintText: 'Explain what this survey is about.',
                prefixIcon: Icon(Icons.description_rounded),
                alignLabelWithHint: true,
              ),
              validator: (String? value) {
                final String text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return 'Survey description is required.';
                }

                if (text.length < 10) {
                  return 'Description is too short.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(
                labelText: 'Survey type',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: const <DropdownMenuItem<String>>[
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
                if (value == null) {
                  return;
                }

                onTypeChanged(value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.publish_rounded),
              ),
              items: const <DropdownMenuItem<String>>[
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
                if (value == null) {
                  return;
                }

                onStatusChanged(value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: audienceScope,
              decoration: const InputDecoration(
                labelText: 'Audience',
                prefixIcon: Icon(Icons.people_rounded),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'public',
                  child: Text('Public'),
                ),
                DropdownMenuItem<String>(
                  value: 'staff',
                  child: Text('Staff Only'),
                ),
                DropdownMenuItem<String>(
                  value: 'rhu',
                  child: Text('RHU Level'),
                ),
                DropdownMenuItem<String>(
                  value: 'barangay',
                  child: Text('Barangay Level'),
                ),
              ],
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }

                onAudienceChanged(value);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: requiresLogin,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Require login',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'Turn on if residents must login before answering.',
              ),
              onChanged: onRequiresLoginChanged,
            ),
            SwitchListTile(
              value: allowMultipleResponses,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Allow multiple responses',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'Turn on if one person can answer more than once.',
              ),
              onChanged: onAllowMultipleChanged,
            ),
            const SizedBox(height: 14),
            _DatePickerTile(
              title: 'Start Date',
              value: startDateText,
              icon: Icons.play_circle_rounded,
              onTap: onPickStartDate,
            ),
            const SizedBox(height: 10),
            _DatePickerTile(
              title: 'End Date',
              value: endDateText,
              icon: Icons.stop_circle_rounded,
              onTap: onPickEndDate,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.needsOptions,
    required this.onRemove,
    required this.onTypeChanged,
    required this.onRequiredChanged,
  });

  final int index;
  final _QuestionInput question;
  final bool needsOptions;
  final VoidCallback onRemove;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<bool> onRequiredChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Question ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: question.questionController,
              decoration: const InputDecoration(
                labelText: 'Question text',
                hintText: 'Example: What medicine is most needed?',
                prefixIcon: Icon(Icons.question_mark_rounded),
              ),
              validator: (String? value) {
                final String text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return 'Question text is required.';
                }

                if (text.length < 4) {
                  return 'Question is too short.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: question.type,
              decoration: const InputDecoration(
                labelText: 'Question type',
                prefixIcon: Icon(Icons.list_alt_rounded),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'short_text',
                  child: Text('Short Text'),
                ),
                DropdownMenuItem<String>(
                  value: 'long_text',
                  child: Text('Long Text'),
                ),
                DropdownMenuItem<String>(
                  value: 'multiple_choice',
                  child: Text('Multiple Choice'),
                ),
                DropdownMenuItem<String>(
                  value: 'checkbox',
                  child: Text('Checkbox'),
                ),
                DropdownMenuItem<String>(
                  value: 'yes_no',
                  child: Text('Yes or No'),
                ),
                DropdownMenuItem<String>(
                  value: 'number',
                  child: Text('Number'),
                ),
              ],
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }

                onTypeChanged(value);
              },
            ),
            if (needsOptions) ...<Widget>[
              const SizedBox(height: 14),
              TextFormField(
                controller: question.optionsController,
                decoration: const InputDecoration(
                  labelText: 'Options',
                  hintText: 'Example: Yes, No, Maybe',
                  prefixIcon: Icon(Icons.checklist_rounded),
                ),
                validator: (String? value) {
                  final String text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return 'Options are required for this question type.';
                  }

                  final int optionCount = text
                      .split(',')
                      .where((String item) => item.trim().isNotEmpty)
                      .length;

                  if (optionCount < 2) {
                    return 'Add at least 2 options separated by comma.';
                  }

                  return null;
                },
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              value: question.isRequired,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Required question',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              onChanged: onRequiredChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: title,
          prefixIcon: Icon(icon),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

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
      child: const Row(
        children: <Widget>[
          Icon(
            Icons.poll_rounded,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Create Community Survey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Create feedback forms, health assessments, and community needs surveys.',
                  style: TextStyle(
                    color: Color(0xFFE0F2F1),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
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
