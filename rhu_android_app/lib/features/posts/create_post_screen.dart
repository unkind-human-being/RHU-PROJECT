import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/post_repository.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';


class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  static const String routeName = '/create-post';

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  final PostRepository _postRepository = PostRepository();

  String _type = 'announcement';
  String _status = 'published';
  String _audienceScope = 'public';
  bool _isPinned = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _readTags() {
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

      await _postRepository.createPost(
        title: _titleController.text,
        content: _contentController.text,
        type: _type,
        status: _status,
        audienceScope: _audienceScope,
        rhuId: rhuId,
        barangayId: barangayId,
        tags: _readTags(),
        isPinned: _isPinned,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post created successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      _titleController.clear();
      _contentController.clear();
      _tagsController.clear();

      setState(() {
        _type = 'announcement';
        _status = 'published';
        _audienceScope = 'public';
        _isPinned = false;
      });
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
          content: Text('Unable to create post.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const _CreatePostHeader(),
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
                        decoration: const InputDecoration(
                          labelText: 'Post title',
                          hintText: 'Example: Free Checkup Announcement',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (String? value) {
                          final String text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'Post title is required.';
                          }

                          if (text.length < 4) {
                            return 'Post title is too short.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _contentController,
                        minLines: 5,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Post content',
                          hintText:
                              'Write the announcement, advisory, or health update here.',
                          prefixIcon: Icon(Icons.description_rounded),
                          alignLabelWithHint: true,
                        ),
                        validator: (String? value) {
                          final String text = value?.trim() ?? '';

                          if (text.isEmpty) {
                            return 'Post content is required.';
                          }

                          if (text.length < 10) {
                            return 'Post content is too short.';
                          }

                          return null;
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
                            value: 'health_tip',
                            child: Text('Health Tip'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'advisory',
                            child: Text('Advisory'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'news',
                            child: Text('News'),
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
                            value: 'published',
                            child: Text('Published'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'draft',
                            child: Text('Draft'),
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
                          hintText: 'Example: checkup, announcement, medicine',
                          prefixIcon: Icon(Icons.tag_rounded),
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
                          'Pinned posts appear as important announcements.',
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
                _isSaving ? 'Creating Post...' : 'Create Post',
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
    );
  }
}

class _CreatePostHeader extends StatelessWidget {
  const _CreatePostHeader();

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
            Icons.campaign_rounded,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Create Health Post',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Publish announcements, advisories, health tips, and RHU news for residents.',
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