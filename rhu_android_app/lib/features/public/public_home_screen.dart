import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/event_model.dart';
import '../../data/models/post_model.dart';
import '../../data/models/survey_model.dart';
import 'public_provider.dart';

class PublicHomeScreen extends StatefulWidget {
  const PublicHomeScreen({super.key});

  static const String routeName = '/public';

  @override
  State<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends State<PublicHomeScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicProvider>().loadAllPublicData();
    });
  }

  Future<void> _refresh() {
    return context.read<PublicProvider>().loadAllPublicData(refresh: true);
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
              'Health Updates',
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
                  _HeaderCard(provider: provider),
                  const SizedBox(height: 18),

                  _QuickActions(
                    onPosts: () {
                      Navigator.of(context).pushNamed('/public-posts');
                    },
                    onEvents: () {
                      Navigator.of(context).pushNamed('/public-events');
                    },
                    onSurveys: () {
                      Navigator.of(context).pushNamed('/public-surveys');
                    },
                  ),

                  const SizedBox(height: 20),

                  if (provider.errorMessage != null)
                    _ErrorCard(
                      message: provider.errorMessage!,
                      onRetry: _refresh,
                    )
                  else if (provider.isLoading)
                    const _LoadingCard()
                  else ...<Widget>[
                    _SectionTitle(
                      title: 'Latest Posts',
                      onViewAll: () {
                        Navigator.of(context).pushNamed('/public-posts');
                      },
                    ),
                    const SizedBox(height: 10),
                    if (!provider.hasPosts)
                      const _EmptyCard(text: 'No public posts available yet.')
                    else
                      ...provider.posts.take(3).map(
                            (PostModel post) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PostCard(post: post),
                            ),
                          ),

                    const SizedBox(height: 16),

                    _SectionTitle(
                      title: 'Upcoming Events',
                      onViewAll: () {
                        Navigator.of(context).pushNamed('/public-events');
                      },
                    ),
                    const SizedBox(height: 10),
                    if (!provider.hasEvents)
                      const _EmptyCard(text: 'No public events available yet.')
                    else
                      ...provider.events.take(3).map(
                            (EventModel event) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _EventCard(event: event),
                            ),
                          ),

                    const SizedBox(height: 16),

                    _SectionTitle(
                      title: 'Open Surveys',
                      onViewAll: () {
                        Navigator.of(context).pushNamed('/public-surveys');
                      },
                    ),
                    const SizedBox(height: 10),
                    if (!provider.hasSurveys)
                      const _EmptyCard(text: 'No public surveys available yet.')
                    else
                      ...provider.surveys.take(3).map(
                            (SurveyModel survey) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SurveyCard(survey: survey),
                            ),
                          ),
                  ],
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
    required this.provider,
  });

  final PublicProvider provider;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.campaign_rounded,
                color: Colors.white,
                size: 32,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'RHU Public Updates',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'View health announcements, RHU events, and community surveys for Tawi-Tawi residents.',
            style: TextStyle(
              color: Color(0xFFE0F2F1),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricBox(
                  label: 'Posts',
                  value: provider.posts.length.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'Events',
                  value: provider.events.length.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'Surveys',
                  value: provider.surveys.length.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
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
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE0F2F1),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onPosts,
    required this.onEvents,
    required this.onSurveys,
  });

  final VoidCallback onPosts;
  final VoidCallback onEvents;
  final VoidCallback onSurveys;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _QuickButton(
            icon: Icons.article_rounded,
            label: 'Posts',
            onTap: onPosts,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickButton(
            icon: Icons.event_rounded,
            label: 'Events',
            onTap: onEvents,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickButton(
            icon: Icons.poll_rounded,
            label: 'Surveys',
            onTap: onSurveys,
          ),
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                color: const Color(0xFF0F766E),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.onViewAll,
  });

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          child: const Text('View all'),
        ),
      ],
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
    return _PreviewCard(
      icon: Icons.article_rounded,
      title: post.title,
      subtitle: post.shortContent,
      footer: '${post.typeLabel} • ${post.locationName}',
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
    return _PreviewCard(
      icon: Icons.event_rounded,
      title: event.title,
      subtitle: event.locationDisplay,
      footer: '${event.typeLabel} • ${event.statusLabel}',
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
    return _PreviewCard(
      icon: Icons.poll_rounded,
      title: survey.title,
      subtitle: survey.shortDescription,
      footer: '${survey.typeLabel} • ${survey.questions.length} question/s',
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.footer,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    footer,
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
              'Unable to load updates',
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
  const _EmptyCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
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
              child: Text('Loading public health updates...'),
            ),
          ],
        ),
      ),
    );
  }
}