import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/post_model.dart';
import 'public_provider.dart';

class PublicPostsScreen extends StatefulWidget {
  const PublicPostsScreen({super.key});

  static const String routeName = '/public-posts';

  @override
  State<PublicPostsScreen> createState() => _PublicPostsScreenState();
}

class _PublicPostsScreenState extends State<PublicPostsScreen> {
  String? _selectedType;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicProvider>().loadPostsOnly();
    });
  }

  Future<void> _refresh() {
    return context.read<PublicProvider>().loadPostsOnly(
          type: _selectedType,
          refresh: true,
        );
  }

  Future<void> _changeType(String? value) async {
    setState(() {
      _selectedType = value;
    });

    await context.read<PublicProvider>().loadPostsOnly(
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
              'Public Posts',
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
                  _HeaderCard(totalPosts: provider.posts.length),
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
                  else if (!provider.hasPosts)
                    const _EmptyCard()
                  else
                    ...provider.posts.map(
                      (PostModel post) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PostCard(post: post),
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
              Icons.article_rounded,
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
                  'Health Announcements',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Read RHU announcements, advisories, health tips, and public news.',
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
        labelText: 'Post type',
        prefixIcon: Icon(Icons.filter_list_rounded),
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
          onChanged(null);
          return;
        }

        onChanged(value);
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
  });

  final PostModel post;

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
                    Icons.campaign_rounded,
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
                        '${post.typeLabel} • ${post.locationName}',
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
              post.content,
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
            if (post.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: post.tags.map(
                  (String tag) {
                    return Chip(
                      label: Text(tag),
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
              'No public posts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'RHU announcements and public posts will appear here once published.',
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
              child: Text('Loading public posts...'),
            ),
          ],
        ),
      ),
    );
  }
}