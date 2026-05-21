import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'edit_post_screen.dart';
import 'create_post_screen.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_repository.dart';



class ManagePostsScreen extends StatefulWidget {
  const ManagePostsScreen({super.key});

  static const String routeName = '/manage-posts';

  @override
  State<ManagePostsScreen> createState() => _ManagePostsScreenState();
}

class _ManagePostsScreenState extends State<ManagePostsScreen> {
  final PostRepository _postRepository = PostRepository();

  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedStatus;
  String? _selectedType;

  List<PostModel> _posts = <PostModel>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPosts();
    });
  }

  Future<void> _openEditPost(PostModel post) async {
    final Object? result = await Navigator.of(context).pushNamed(
      EditPostScreen.routeName,
      arguments: EditPostArguments(
        post: post,
      ),
    );

    if (result == true && mounted) {
      await _loadPosts();
    }
  }

  Future<void> _deletePost(PostModel post) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post?'),
          content: Text(
            'Are you sure you want to delete "${post.title}"?',
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
      await _postRepository.deletePost(post.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      await _loadPosts();
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
          content: Text('Unable to delete post.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<PostModel> result = await _postRepository.getStaffPosts(
        type: _selectedType,
        status: _selectedStatus,
      );

      setState(() {
        _posts = result;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Unable to load posts.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openCreatePost() async {
    await Navigator.of(context).pushNamed(CreatePostScreen.routeName);

    if (!mounted) {
      return;
    }

    await _loadPosts();
  }

  Future<void> _setStatus(String? value) async {
    setState(() {
      _selectedStatus = value;
    });

    await _loadPosts();
  }

  Future<void> _setType(String? value) async {
    setState(() {
      _selectedType = value;
    });

    await _loadPosts();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedStatus = null;
      _selectedType = null;
    });

    await _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Posts',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _isLoading ? null : _loadPosts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePost,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Post'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPosts,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _HeaderCard(totalPosts: _posts.length),
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
                  onRetry: _loadPosts,
                )
              else if (_isLoading)
                const _LoadingCard()
              else if (_posts.isEmpty)
                const _EmptyCard()
              else
                ..._posts.map(
                  (PostModel post) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PostCard(
                        post: post,
                        onEdit: () => _openEditPost(post),
                        onDelete: () => _deletePost(post),
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
    required this.totalPosts,
  });

  final int totalPosts;

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
              Icons.campaign_rounded,
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
                  'Post Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create and view RHU health announcements, advisories, and public updates.',
                  style: TextStyle(
                    color: Color(0xFFE0F2F1),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$totalPosts post/s loaded',
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
                labelText: 'Post type',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('All post types'),
                ),
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

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  final PostModel post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String dateText = _formatDate(post.publishedAt ?? post.createdAt);

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
                    Icons.article_rounded,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        
                        children: <Widget>[
                          if (post.isPinned) ...<Widget>[
                            const Icon(
                              Icons.push_pin_rounded,
                              color: Color(0xFFF59E0B),
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            
                            child: Text(
                              post.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${post.typeLabel} • ${post.status}',
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
                      tooltip: 'Edit post',
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete post',
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
              post.shortContent,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF6B7280),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dateText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const Icon(
                  Icons.visibility_rounded,
                  color: Color(0xFF6B7280),
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  post.viewCount.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'No date';
    }

    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
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
              'Unable to load posts',
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
                Icons.article_outlined,
                color: Color(0xFF0F766E),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No posts found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new health post or clear your filters.',
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
              child: Text('Loading posts...'),
            ),
          ],
        ),
      ),
    );
  }
}