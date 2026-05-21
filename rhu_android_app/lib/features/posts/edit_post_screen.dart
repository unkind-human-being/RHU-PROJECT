import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_repository.dart';

class EditPostArguments {
  const EditPostArguments({
    required this.post,
  });

  final PostModel post;
}

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({
    super.key,
    required this.post,
  });

  static const String routeName = '/edit-post';

  final PostModel post;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagsController;

  final PostRepository _postRepository = PostRepository();

  String _type = 'announcement';
  String _status = 'published';
  String _audienceScope = 'public';

  bool _isPinned = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final dynamic post = widget.post;

    _titleController = TextEditingController(
      text: _safeText(post.title),
    );

    _contentController = TextEditingController(
      text: _safeText(post.content),
    );

    _tagsController = TextEditingController(
      text: _readTags(post.tags).join(', '),
    );

    _type = _normalizeDropdownValue(
      _safeText(post.type),
      allowedValues: <String>[
        'announcement',
        'advisory',
        'health_tip',
        'news',
        'emergency',
      ],
      fallback: 'announcement',
    );

    _status = _normalizeDropdownValue(
      _safeText(post.status),
      allowedValues: <String>[
        'draft',
        'published',
        'archived',
      ],
      fallback: 'published',
    );

    _audienceScope = _normalizeDropdownValue(
      _safeText(post.audienceScope),
      allowedValues: <String>[
        'public',
        'staff',
        'rhu',
        'barangay',
      ],
      fallback: 'public',
    );

    _isPinned = _readBool(post.isPinned);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    final String text = value.toString().trim();

    if (text.isEmpty || text == 'null') {
      return fallback;
    }

    return text;
  }

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final String text = value?.toString().trim().toLowerCase() ?? '';

    return text == 'true' || text == '1' || text == 'yes';
  }

  List<String> _readTags(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }

    final String text = value?.toString().trim() ?? '';

    if (text.isEmpty || text == 'null') {
      return <String>[];
    }

    return text
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  String _normalizeDropdownValue(
    String value, {
    required List<String> allowedValues,
    required String fallback,
  }) {
    final String lower = value.trim().toLowerCase();

    if (allowedValues.contains(lower)) {
      return lower;
    }

    return fallback;
  }

  List<String> _readTagsFromInput() {
    return _tagsController.text
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
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
      await _postRepository.updatePost(
        postId: widget.post.id,
        title: _titleController.text,
        content: _contentController.text,
        type: _type,
        status: _status,
        audienceScope: _audienceScope,
        tags: _readTagsFromInput(),
        isPinned: _isPinned,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post updated successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      Navigator.of(context).pop(true);
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
          content: Text('Unable to update post.'),
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

  String? _requiredValidator(String? value, String fieldName) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '$fieldName is required.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Post',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const _HeaderCard(),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Post title',
                          hintText: 'Example: Free Checkup Announcement',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (String? value) {
                          return _requiredValidator(value, 'Post title');
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _contentController,
                        minLines: 5,
                        maxLines: 9,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Post content',
                          hintText: 'Write the health update details here.',
                          prefixIcon: Icon(Icons.article_rounded),
                          alignLabelWithHint: true,
                        ),
                        validator: (String? value) {
                          return _requiredValidator(value, 'Post content');
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: const InputDecoration(
                          labelText: 'Post type',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'announcement',
                            child: Text('Announcement'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'advisory',
                            child: Text('Advisory'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'health_tip',
                            child: Text('Health Tip'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'news',
                            child: Text('News'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'emergency',
                            child: Text('Emergency'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _type = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(Icons.publish_rounded),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'draft',
                            child: Text('Draft'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'published',
                            child: Text('Published'),
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

                          setState(() {
                            _status = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _audienceScope,
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

                          setState(() {
                            _audienceScope = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags optional',
                          hintText: 'Example: health, announcement, bongao',
                          prefixIcon: Icon(Icons.sell_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _isPinned,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Pin this post',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Pinned posts can be highlighted in public updates.',
                        ),
                        onChanged: (bool value) {
                          setState(() {
                            _isPinned = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
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
                _isSaving ? 'Saving Changes...' : 'Save Changes',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                      Navigator.of(context).pop(false);
                    },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
          ],
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
            Icons.edit_note_rounded,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Edit Health Post',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Update title, content, status, audience, tags, and pinned setting.',
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
