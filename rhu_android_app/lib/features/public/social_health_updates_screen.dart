import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../auth/auth_provider.dart';
import '../notifications/widgets/notification_badge_button.dart';

import 'rhu_ai_chat_sheet.dart';


class SocialHealthUpdatesScreen extends StatefulWidget {
  const SocialHealthUpdatesScreen({super.key});
  static const String routeName = '/social-health-updates';
  @override
  State<SocialHealthUpdatesScreen> createState() => _SocialHealthUpdatesScreenState();
}
class _SocialHealthUpdatesScreenState extends State<SocialHealthUpdatesScreen> {
  late final ApiClient _apiClient;
  late final ScrollController _scrollController;
  static const int _pageSize = 5;
  static const int _visibleStep = 5;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _nextPage = 1;
  int _visibleItemCount = _visibleStep;
  String? _errorMessage;
  String _selectedFilter = 'all';
  List<_FeedItem> _items = <_FeedItem>[];
  @override
  void initState() {
    super.initState();
    final TokenStorageService tokenStorageService = TokenStorageService();
    _apiClient = ApiClient(tokenProvider: tokenStorageService.getToken,
    );
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeed();
    });
  }
  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _apiClient.close();
    super.dispose();
  }
  List<_FeedItem> get _filteredItems {
    if (_selectedFilter == 'all') {
      return _items;
    }
    return _items.where((_FeedItem item) {
      return item.type == _selectedFilter;
    }).toList();
  }
  List<_FeedItem> get _displayedItems {
    final List<_FeedItem> filteredItems = _filteredItems;
    if (filteredItems.length <= _visibleItemCount) {
      return filteredItems;
    }
    return filteredItems.take(_visibleItemCount).toList();
  }
  bool get _canShowMore {
    return _visibleItemCount < _filteredItems.length || _hasMore;
  }
  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final double pixels = _scrollController.position.pixels;
    final double maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (maxScrollExtent - pixels <= 420) {
      _showMoreOrLoadMore();
    }
  }
  Future<void> _showMoreOrLoadMore() async {
    if (_isLoading || _isLoadingMore) {
      return;
    }
    if (_visibleItemCount < _filteredItems.length) {
      setState(() {
        _visibleItemCount += _visibleStep;
      });
      return;
    }
    if (!_hasMore) {
      return;
    }
    await _loadMoreFeed();
  }
  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _nextPage = 1;
      _visibleItemCount = _visibleStep;
      _items = <_FeedItem>[];
      _errorMessage = null;
    });
    try {
      final _FeedPageResult result = await _fetchFeedPage(page: 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = _sortAndDeduplicate(result.items);
        _hasMore = result.hasMore;
        _nextPage = 2;
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
        _errorMessage = 'Unable to load social health updates.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  Future<void> _loadMoreFeed() async {
    if (_isLoadingMore || _isLoading || !_hasMore) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final _FeedPageResult result = await _fetchFeedPage(page: _nextPage);
      final Set<String> existingKeys = _items.map((_FeedItem item) {
        return item.uniqueKey;
      }).toSet();
      final List<_FeedItem> newItems = result.items.where((_FeedItem item) {
        return !existingKeys.contains(item.uniqueKey);
      }).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = _sortAndDeduplicate(<_FeedItem>[
          ..._items,
          ...newItems,
        ]);
        _visibleItemCount += _visibleStep;
        _nextPage += 1;
        // If the backend ignores page/limit and sends duplicate records,
        // stop loading more to avoid repeated backend calls.
        _hasMore = result.hasMore && newItems.isNotEmpty;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnack(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showErrorSnack('Unable to load more updates.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }
  Future<_FeedPageResult> _fetchFeedPage({required int page,
  }) async {
    final List<_FeedItem> loadedItems = <_FeedItem>[];
    final Map<String, dynamic> postsResponse = await _apiClient.get('/api/posts/public',
    requiresAuth: false,
    queryParameters: <String, dynamic> {
      'page': page,
      'limit': _pageSize,
    },
    );
    final List<dynamic> rawPosts = _extractList(postsResponse);
    final List<dynamic> limitedPosts = rawPosts.take(_pageSize).toList();
    loadedItems.addAll(limitedPosts.whereType<Map<String, dynamic>>().map((Map<String, dynamic> json) => _FeedItem.fromPost(json),
    ),
    );
    final Map<String, dynamic> eventsResponse = await _apiClient.get('/api/events/public',
    requiresAuth: false,
    queryParameters: <String, dynamic> {
      'page': page,
      'limit': _pageSize,
    },
    );
    final List<dynamic> rawEvents = _extractList(eventsResponse);
    final List<dynamic> limitedEvents = rawEvents.take(_pageSize).toList();
    loadedItems.addAll(limitedEvents.whereType<Map<String, dynamic>>().map((Map<String, dynamic> json) => _FeedItem.fromEvent(json),
    ),
    );
    final Map<String, dynamic> surveysResponse = await _apiClient.get('/api/surveys/public',
    requiresAuth: false,
    queryParameters: <String, dynamic> {
      'page': page,
      'limit': _pageSize,
    },
    );
    final List<dynamic> rawSurveys = _extractList(surveysResponse);
    final List<dynamic> limitedSurveys = rawSurveys.take(_pageSize).toList();
    loadedItems.addAll(limitedSurveys.whereType<Map<String, dynamic>>().map((Map<String, dynamic> json) => _FeedItem.fromSurvey(json),
    ),
    );
    final bool hasMore = rawPosts.length >= _pageSize || rawEvents.length >= _pageSize || rawSurveys.length >= _pageSize;
    loadedItems.sort((_FeedItem a,
    _FeedItem b
    ) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return _FeedPageResult(items: loadedItems,
    hasMore: hasMore,
    );
  }
  List<_FeedItem> _sortAndDeduplicate(List<_FeedItem> items) {
    final Map<String, _FeedItem> itemMap = <String, _FeedItem> {
    };
    for (final _FeedItem item in items) {
      itemMap[
        item.uniqueKey
      ] = item;
    }
    final List<_FeedItem> sortedItems = itemMap.values.toList();
    sortedItems.sort((_FeedItem a,
    _FeedItem b
    ) {
      return b.createdAt.compareTo(a.createdAt);
    });
    return sortedItems;
  }
  List<dynamic> _extractList(Map<String, dynamic> response) {
    final dynamic data = response[
      'data'
    ];
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final dynamic posts = data[
        'posts'
      ];
      final dynamic events = data[
        'events'
      ];
      final dynamic surveys = data[
        'surveys'
      ];
      final dynamic results = data[
        'results'
      ];
      final dynamic docs = data[
        'docs'
      ];
      final dynamic items = data[
        'items'
      ];
      if (posts is List) return posts;
      if (events is List) return events;
      if (surveys is List) return surveys;
      if (results is List) return results;
      if (docs is List) return docs;
      if (items is List) return items;
    }
    final dynamic posts = response[
      'posts'
    ];
    final dynamic events = response[
      'events'
    ];
    final dynamic surveys = response[
      'surveys'
    ];
    if (posts is List) return posts;
    if (events is List) return events;
    if (surveys is List) return surveys;
    return <dynamic>[];
  }
  void _setFilter(String value) {
    setState(() {
      _selectedFilter = value;
      _visibleItemCount = _visibleStep;
    });
  }
  void _open(BuildContext context,
  String routeName
  ) {
    Navigator.of(context).pushNamed(routeName).then((_) {
      if (routeName == '/apply-appointment') {
        _loadFeed();
      }
    });
  }
  void _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/login',
    (Route<dynamic> route) => false,
    );
  }
  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();
    final String userEmail = authProvider.user?.email ?? 'Public user';
    final List<_FeedItem> displayedItems = _displayedItems;
    return Scaffold(backgroundColor: const Color(0xFFEFF6FF),
    floatingActionButton: FloatingActionButton(
      heroTag: 'rhu_ai_chat_button',
      backgroundColor: const Color(0xFF0EA5E9),
      onPressed: () {
        showRhuAiChatSheet(context);
      },
      child: const Icon(
        Icons.smart_toy_rounded,
        color: Colors.white,
      ),
    ),
    appBar: AppBar(elevation: 0,
    backgroundColor: const Color(0xFF0EA5E9),
    foregroundColor: Colors.white,
    titleSpacing: 0,
    title: const FittedBox(fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text('SOCIAL HEALTH UPDATES',
    maxLines: 1,
    style: TextStyle(fontSize: 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.2,
    ),
    ),
    ),
    actions: <Widget>[
      const NotificationBadgeButton(iconColor: Colors.white,
      ),
      IconButton(tooltip: 'Profile',
      onPressed: () {
        _open(context,
        '/profile'
        );
      },
      icon: const Icon(Icons.account_circle_rounded),
      ),
    ],
    ),
    drawer: _PublicUserDrawer(userEmail: userEmail,
    onApplyAppointment: () {
      Navigator.of(context).pop();
      _open(context,
      '/apply-appointment'
      );
    },
    onRhuProfiles: () {
      Navigator.of(context).pop();
      _open(context,
      '/public-rhus'
      );
    },
    onProfile: () {
      Navigator.of(context).pop();
      _open(context,
      '/profile'
      );
    },
    onMessages: () {
      Navigator.of(context).pop();
      _open(context,
      '/public-messages'
      );
    },
    onNotifications: () {
      Navigator.of(context).pop();
      _open(context,
      '/notifications'
      );
    },
    onActivityHistory: () {
      Navigator.of(context).pop();
      _open(context,
      '/public-activity-history'
      );
    },
    onLogout: () {
      Navigator.of(context).pop();
      _logout(context);
    },
    ),
    body: SafeArea(child: RefreshIndicator(onRefresh: _loadFeed,
    child: CustomScrollView(controller: _scrollController,
    slivers: <Widget>[
      SliverToBoxAdapter(child: _HeroHeader(userEmail: userEmail,
      onRhuProfiles: () {
        _open(context,
        '/public-rhus'
        );
      },
      onMessages: () {
        _open(context,
        '/public-messages'
        );
      },
      onNotifications: () {
        _open(context,
        '/notifications'
        );
      },
      onActivityHistory: () {
        _open(context,
        '/public-activity-history'
        );
      },
      ),
      ),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,
      16,
      16,
      0
      ),
      child: _FeedSummaryCard(totalLoaded: _items.length,
      visibleCount: displayedItems.length,
      canLoadMore: _canShowMore,
      onRhuTap: () {
        _open(context,
        '/public-rhus'
        );
      },
      ),
      ),
      ),
      SliverPersistentHeader(pinned: true,
      delegate: _FilterHeaderDelegate(selectedFilter: _selectedFilter,
      onChanged: _setFilter,
      ),
      ),
      if (_errorMessage != null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16),
      child: _ErrorCard(message: _errorMessage!,
      onRetry: _loadFeed,
      ),
      ),
      ) else if (_isLoading) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16),
      child: _LoadingFeed(),
      ),
      ) else if (displayedItems.isEmpty) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16),
      child: _EmptyFeed(),
      ),
      ) else SliverList.builder(itemCount: displayedItems.length,
      itemBuilder: (BuildContext context,
      int index
      ) {
        final _FeedItem item = displayedItems[
          index
        ];
        return Padding(padding: EdgeInsets.only(left: 16,
        right: 16,
        top: index == 0 ? 16 : 0,
        bottom: 12,
        ),
        child: _FeedCard(item: item,
        onTap: () {
          _showFeedDetails(item);
        },
        ),
        );
      },
      ),
      if (!_isLoading && _errorMessage == null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,
      4,
      16,
      16
      ),
      child: _LoadMoreArea(isLoadingMore: _isLoadingMore,
      canLoadMore: _canShowMore,
      onLoadMore: _showMoreOrLoadMore,
      ),
      ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 48),
      ),
    ],
    ),
    ),
    ),
    );
  }
  Future<void> _registerForEvent(_FeedItem item) async {
    if (item.id.trim().isEmpty) {
      _showErrorSnack('Event ID was not found.');
      return;
    }
    final AuthProvider authProvider = context.read<AuthProvider>();
    final _EventRegistrationInput? input = await showDialog<_EventRegistrationInput>(context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _EventRegistrationDialog(defaultName: authProvider.user?.fullName ?? '',
      defaultEmail: authProvider.user?.email ?? '',
      defaultPhone: authProvider.user?.phoneNumber ?? '',
      eventTitle: item.title,
      );
    },
    );
    if (input == null) {
      return;
    }
    try {
      await _apiClient.post('/api/event-registrations/event/${Uri.encodeComponent(item.id)}',
      requiresAuth: true,
      body: input.toJson(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event registration submitted successfully.'),
      backgroundColor: Color(0xFF16A34A),
      ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnack(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showErrorSnack('Unable to submit event registration.');
    }
  }
  Future<void> _submitSurveyResponse(_FeedItem item) async {
    if (item.id.trim().isEmpty) {
      _showErrorSnack('Survey ID was not found.');
      return;
    }
    final AuthProvider authProvider = context.read<AuthProvider>();
    final List<_SurveyQuestion> questions = _SurveyQuestion.fromSurveyJson(item.rawJson,
    );
    final _SurveyResponseInput? input = await showDialog<_SurveyResponseInput>(context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _SurveyResponseDialog(surveyTitle: item.title,
      questions: questions,
      defaultName: authProvider.user?.fullName ?? '',
      defaultEmail: authProvider.user?.email ?? '',
      defaultPhone: authProvider.user?.phoneNumber ?? '',
      );
    },
    );
    if (input == null) {
      return;
    }
    try {
      await _apiClient.post('/api/survey-responses/survey/${Uri.encodeComponent(item.id)}',
      requiresAuth: true,
      body: input.toJson(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Survey response submitted successfully.'),
      backgroundColor: Color(0xFF16A34A),
      ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnack(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showErrorSnack('Unable to submit survey response.');
    }
  }
  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message),
    backgroundColor: const Color(0xFFDC2626),
    ),
    );
  }
  void _showFeedDetails(_FeedItem item) {
    showModalBottomSheet<void>(context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return _FeedDetailsSheet(item: item,
      onRegisterEvent: () {
        Navigator.of(context).pop();
        _registerForEvent(item);
      },
      onAnswerSurvey: () {
        Navigator.of(context).pop();
        _submitSurveyResponse(item);
      },
      );
    },
    );
  }
}
class _FeedPageResult {
  const _FeedPageResult({required this.items,
  required this.hasMore,
  });
  final List<_FeedItem> items;
  final bool hasMore;
}
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.userEmail,
  required this.onRhuProfiles,
  required this.onMessages,
  required this.onNotifications,
  required this.onActivityHistory,
  });
  final String userEmail;
  final VoidCallback onRhuProfiles;
  final VoidCallback onMessages;
  final VoidCallback onNotifications;
  final VoidCallback onActivityHistory;
  @override
  Widget build(BuildContext context) {
    return Container(decoration: const BoxDecoration(color: Color(0xFF0EA5E9),
    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(34),
    bottomRight: Radius.circular(34),
    ),
    ),
    child: Padding(padding: const EdgeInsets.fromLTRB(20,
    4,
    20,
    24
    ),
    child: Column(children: <Widget>[
      Row(children: <Widget>[
        Container(width: 62,
        height: 62,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25),
        ),
        ),
        child: const Icon(Icons.health_and_safety_rounded,
        color: Colors.white,
        size: 34,
        ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('RHU Social Health',
          style: TextStyle(color: Colors.white,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          ),
          ),
          const SizedBox(height: 5),
          Text(userEmail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFE0F2FE),
          fontWeight: FontWeight.w700,
          ),
          ),
        ],
        ),
        ),
      ],
      ),
      const SizedBox(height: 18),
      Container(width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.20),
      ),
      ),
      child: const Text('View official RHU posts, events, surveys, QR notices, and consultation updates.',
      style: TextStyle(color: Colors.white,
      height: 1.45,
      fontWeight: FontWeight.w600,
      ),
      ),
      ),
      const SizedBox(height: 16),
      GridView.count(crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.25,
      children: <Widget>[
        _QuickActionButton(icon: Icons.local_hospital_rounded,
        label: 'RHU Profiles',
        onTap: onRhuProfiles,
        ),
        _QuickActionButton(icon: Icons.fact_check_rounded,
        label: 'My Activity',
        onTap: onActivityHistory,
        ),
        _QuickActionButton(icon: Icons.chat_bubble_rounded,
        label: 'Messages',
        onTap: onMessages,
        ),
        _QuickActionButton(icon: Icons.notifications_rounded,
        label: 'QR Notices',
        onTap: onNotifications,
        ),
      ],
      ),
    ],
    ),
    ),
    );
  }
}
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.icon,
  required this.label,
  required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12,
    vertical: 10,
    ),
    child: Row(children: <Widget>[
      Container(width: 34,
      height: 34,
      decoration: BoxDecoration(color: const Color(0xFFE0F2FE),
      borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon,
      color: const Color(0xFF0EA5E9),
      size: 20,
      ),
      ),
      const SizedBox(width: 9),
      Expanded(child: Text(label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Color(0xFF075985),
      fontSize: 12,
      fontWeight: FontWeight.w900,
      ),
      ),
      ),
    ],
    ),
    ),
    ),
    );
  }
}
class _FeedSummaryCard extends StatelessWidget {
  const _FeedSummaryCard({required this.totalLoaded,
  required this.visibleCount,
  required this.canLoadMore,
  required this.onRhuTap,
  });
  final int totalLoaded;
  final int visibleCount;
  final bool canLoadMore;
  final VoidCallback onRhuTap;
  @override
  Widget build(BuildContext context) {
    return Card(color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24),
    side: const BorderSide(color: Color(0xFFBAE6FD),
    ),
    ),
    child: InkWell(borderRadius: BorderRadius.circular(24),
    onTap: onRhuTap,
    child: Padding(padding: const EdgeInsets.all(18),
    child: Row(children: <Widget>[
      Container(width: 58,
      height: 58,
      decoration: BoxDecoration(color: const Color(0xFFE0F2FE),
      borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.dynamic_feed_rounded,
      color: Color(0xFF0EA5E9),
      size: 32,
      ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Latest public health updates',
        style: TextStyle(color: Color(0xFF0F172A),
        fontSize: 17,
        fontWeight: FontWeight.w900,
        ),
        ),
        const SizedBox(height: 5),
        Text(canLoadMore ? 'Showing $visibleCount update(s). Scroll down to load 5 more.' : 'Showing all available updates.',
        style: const TextStyle(color: Color(0xFF64748B),
        height: 1.35,
        fontWeight: FontWeight.w700,
        ),
        ),
      ],
      ),
      ),
      const SizedBox(width: 8),
      const Icon(Icons.keyboard_arrow_down_rounded,
      color: Color(0xFF0EA5E9),
      ),
    ],
    ),
    ),
    ),
    );
  }
}
class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterHeaderDelegate({required this.selectedFilter,
  required this.onChanged,
  });
  final String selectedFilter;
  final ValueChanged<String> onChanged;
  @override
  double get minExtent => 74;
  @override
  double get maxExtent => 74;
  @override
  Widget build(BuildContext context,
  double shrinkOffset,
  bool overlapsContent,
  ) {
    return Container(color: const Color(0xFFEFF6FF),
    padding: const EdgeInsets.fromLTRB(16,
    12,
    16,
    10
    ),
    child: ListView(scrollDirection: Axis.horizontal,
    children: <Widget>[
      _FilterChipButton(label: 'All',
      icon: Icons.public_rounded,
      value: 'all',
      selectedValue: selectedFilter,
      onChanged: onChanged,
      ),
      _FilterChipButton(label: 'Posts',
      icon: Icons.campaign_rounded,
      value: 'post',
      selectedValue: selectedFilter,
      onChanged: onChanged,
      ),
      _FilterChipButton(label: 'Events',
      icon: Icons.event_rounded,
      value: 'event',
      selectedValue: selectedFilter,
      onChanged: onChanged,
      ),
      _FilterChipButton(label: 'Surveys',
      icon: Icons.poll_rounded,
      value: 'survey',
      selectedValue: selectedFilter,
      onChanged: onChanged,
      ),
    ],
    ),
    );
  }
  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return oldDelegate.selectedFilter != selectedFilter;
  }
}
class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({required this.label,
  required this.icon,
  required this.value,
  required this.selectedValue,
  required this.onChanged,
  });
  final String label;
  final IconData icon;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final bool selected = value == selectedValue;
    return Padding(padding: const EdgeInsets.only(right: 10),
    child: ChoiceChip(selected: selected,
    avatar: Icon(icon,
    size: 18,
    color: selected ? Colors.white : const Color(0xFF0EA5E9),
    ),
    label: Text(label),
    selectedColor: const Color(0xFF0EA5E9),
    backgroundColor: Colors.white,
    labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xFF075985),
    fontWeight: FontWeight.w900,
    ),
    side: BorderSide(color: selected ? const Color(0xFF0EA5E9) : const Color(0xFFBAE6FD),
    ),
    onSelected: (_) {
      onChanged(value);
    },
    ),
    );
  }
}
class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item,
  required this.onTap,
  });
  final _FeedItem item;
  final VoidCallback onTap;
  Color get _color {
    switch (item.type) {
      case 'event':
      return const Color(0xFF2563EB);
      case 'survey':
      return const Color(0xFF7C3AED);
      default:
      return const Color(0xFF0EA5E9);
    }
  }
  IconData get _icon {
    switch (item.type) {
      case 'event':
      return Icons.event_rounded;
      case 'survey':
      return Icons.poll_rounded;
      default:
      return Icons.campaign_rounded;
    }
  }
  String get _typeLabel {
    switch (item.type) {
      case 'event':
      return 'Event';
      case 'survey':
      return 'Survey';
      default:
      return 'Health Post';
    }
  }
  @override
  Widget build(BuildContext context) {
    return Card(color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26),
    side: const BorderSide(color: Color(0xFFBAE6FD),
    ),
    ),
    child: InkWell(borderRadius: BorderRadius.circular(26),
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(children: <Widget>[
        Container(width: 46,
        height: 46,
        decoration: BoxDecoration(color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(_icon,
        color: _color,
        ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(item.rhuName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF0F172A),
          fontWeight: FontWeight.w900,
          ),
          ),
          const SizedBox(height: 2),
          Text('$_typeLabel • ${item.timeAgo}',
          style: const TextStyle(color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          ),
          ),
        ],
        ),
        ),
        _TypeBadge(label: _typeLabel,
        color: _color,
        ),
      ],
      ),
      const SizedBox(height: 14),
      Text(item.title,
      style: const TextStyle(color: Color(0xFF0F172A),
      fontSize: 18,
      fontWeight: FontWeight.w900,
      ),
      ),
      if (item.description.trim().isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        Text(item.description,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF334155),
        height: 1.45,
        fontWeight: FontWeight.w600,
        ),
        ),
      ],
      if (item.dateLine.trim().isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        Row(children: <Widget>[
          Icon(Icons.schedule_rounded,
          color: _color,
          size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(item.dateLine,
          style: TextStyle(color: _color,
          fontWeight: FontWeight.w800,
          ),
          ),
          ),
        ],
        ),
      ],
      const SizedBox(height: 14),
      Row(children: <Widget>[
        const Icon(Icons.visibility_rounded,
        color: Color(0xFF64748B),
        size: 20,
        ),
        const SizedBox(width: 6),
        const Text('View details',
        style: TextStyle(color: Color(0xFF64748B),
        fontWeight: FontWeight.w700,
        ),
        ),
        const Spacer(),
        Icon(Icons.chevron_right_rounded,
        color: _color,
        ),
      ],
      ),
    ],
    ),
    ),
    ),
    );
  }
}
class _LoadMoreArea extends StatelessWidget {
  const _LoadMoreArea({required this.isLoadingMore,
  required this.canLoadMore,
  required this.onLoadMore,
  });
  final bool isLoadingMore;
  final bool canLoadMore;
  final Future<void> Function() onLoadMore;
  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Card(color: Colors.white,
      child: Padding(padding: EdgeInsets.all(16),
      child: Row(children: <Widget>[
        SizedBox(width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        SizedBox(width: 12),
        Expanded(child: Text('Loading 5 more updates...',
        style: TextStyle(color: Color(0xFF64748B),
        fontWeight: FontWeight.w700,
        ),
        ),
        ),
      ],
      ),
      ),
      );
    }
    if (!canLoadMore) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 14),
      child: Center(child: Text('You reached the end of the updates.',
      style: TextStyle(color: Color(0xFF64748B),
      fontWeight: FontWeight.w700,
      ),
      ),
      ),
      );
    }
    return SizedBox(width: double.infinity,
    child: OutlinedButton.icon(onPressed: onLoadMore,
    icon: const Icon(Icons.expand_more_rounded),
    label: const Text('Load 5 More Updates'),
    ),
    );
  }
}
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label,
  required this.color,
  });
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10,
    vertical: 7,
    ),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label,
    style: TextStyle(color: color,
    fontSize: 11,
    fontWeight: FontWeight.w900,
    ),
    ),
    );
  }
}
class _FeedDetailsSheet extends StatelessWidget {
  const _FeedDetailsSheet({required this.item,
  required this.onRegisterEvent,
  required this.onAnswerSurvey,
  });
  final _FeedItem item;
  final VoidCallback onRegisterEvent;
  final VoidCallback onAnswerSurvey;
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(initialChildSize: 0.72,
    minChildSize: 0.40,
    maxChildSize: 0.92,
    builder: (BuildContext context,
    ScrollController scrollController
    ) {
      return Container(decoration: const BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(30),
      ),
      ),
      child: ListView(controller: scrollController,
      padding: const EdgeInsets.all(22),
      children: <Widget>[
        Center(child: Container(width: 48,
        height: 5,
        decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(999),
        ),
        ),
        ),
        const SizedBox(height: 20),
        Text(item.title,
        style: const TextStyle(color: Color(0xFF0F172A),
        fontSize: 24,
        fontWeight: FontWeight.w900,
        ),
        ),
        const SizedBox(height: 10),
        Text('${item.rhuName} • ${item.timeAgo}',
        style: const TextStyle(color: Color(0xFF64748B),
        fontWeight: FontWeight.w700,
        ),
        ),
        if (item.dateLine.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _InfoBox(icon: Icons.schedule_rounded,
          text: item.dateLine,
          ),
        ],
        const SizedBox(height: 18),
        Text(item.description.trim().isEmpty ? 'No additional details provided.' : item.description,
        style: const TextStyle(color: Color(0xFF334155),
        height: 1.55,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        ),
        ),
        const SizedBox(height: 22),
        if (item.type == 'event') ...<Widget>[
          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB),
          ),
          onPressed: onRegisterEvent,
          icon: const Icon(Icons.how_to_reg_rounded),
          label: const Text('Register for Event'),
          ),
          const SizedBox(height: 10),
        ],
        if (item.type == 'survey') ...<Widget>[
          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED),
          ),
          onPressed: onAnswerSurvey,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Answer Survey'),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(onPressed: () {
          Navigator.of(context).pop();
        },
        icon: const Icon(Icons.check_rounded),
        label: const Text('Done'),
        ),
      ],
      ),
      );
    },
    );
  }
}
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon,
  required this.text,
  });
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFEFF6FF),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFBAE6FD),
    ),
    ),
    child: Row(children: <Widget>[
      Icon(icon,
      color: const Color(0xFF0EA5E9),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
      style: const TextStyle(color: Color(0xFF075985),
      fontWeight: FontWeight.w800,
      ),
      ),
      ),
    ],
    ),
    );
  }
}
class _PublicUserDrawer extends StatelessWidget {
  const _PublicUserDrawer({required this.userEmail,
  required this.onApplyAppointment,
  required this.onRhuProfiles,
  required this.onProfile,
  required this.onMessages,
  required this.onNotifications,
  required this.onActivityHistory,
  required this.onLogout,
  });
  final String userEmail;
  final VoidCallback onApplyAppointment;
  final VoidCallback onRhuProfiles;
  final VoidCallback onProfile;
  final VoidCallback onMessages;
  final VoidCallback onNotifications;
  final VoidCallback onActivityHistory;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) {
    return Drawer(child: SafeArea(child: Column(children: <Widget>[
      Container(width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(color: Color(0xFF0EA5E9),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const CircleAvatar(radius: 28,
        backgroundColor: Colors.white,
        child: Icon(Icons.person_rounded,
        color: Color(0xFF0EA5E9),
        size: 34,
        ),
        ),
        const SizedBox(height: 12),
        const Text('Public User',
        style: TextStyle(color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        ),
        ),
        const SizedBox(height: 4),
        Text(userEmail,
        style: const TextStyle(color: Color(0xFFE0F2FE),
        fontWeight: FontWeight.w700,
        ),
        ),
      ],
      ),
      ),
      _DrawerItem(icon: Icons.public_rounded,
      title: 'Social Health Updates',
      onTap: () {
        Navigator.of(context).pop();
      },
      ),
      _DrawerItem(icon: Icons.local_hospital_rounded,
      title: 'RHU Profiles',
      subtitle: 'Contacts and appointment availability',
      onTap: onRhuProfiles,
      ),
      _DrawerItem(icon: Icons.event_available_rounded,
      title: 'Apply Appointment',
      onTap: onApplyAppointment,
      ),
      _DrawerItem(icon: Icons.chat_bubble_rounded,
      title: 'Messages',
      subtitle: 'RHU admin can chat or call you',
      onTap: onMessages,
      ),
      _DrawerItem(icon: Icons.notifications_rounded,
      title: 'Notifications',
      subtitle: 'QR tickets and prescription notices',
      onTap: onNotifications,
      ),
      _DrawerItem(icon: Icons.account_circle_rounded,
      title: 'Account',
      onTap: onProfile,
      ),
      _DrawerItem(icon: Icons.fact_check_rounded,
      title: 'My RHU Activity',
      subtitle: 'Event registrations and survey responses',
      onTap: onActivityHistory,
      ),
      const Spacer(),
      const Divider(height: 1),
      _DrawerItem(icon: Icons.logout_rounded,
      title: 'Logout',
      onTap: onLogout,
      ),
    ],
    ),
    ),
    );
  }
}
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon,
  required this.title,
  required this.onTap,
  this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon,
    color: const Color(0xFF0EA5E9),
    ),
    title: Text(title,
    style: const TextStyle(fontWeight: FontWeight.w900,
    ),
    ),
    subtitle: subtitle == null ? null : Text(subtitle!),
    onTap: onTap,
    );
  }
}
class _FeedItem {
  const _FeedItem({required this.id,
  required this.type,
  required this.title,
  required this.description,
  required this.rhuName,
  required this.createdAt,
  required this.dateLine,
  required this.rawJson,
  });
  factory _FeedItem.fromPost(Map<String, dynamic> json) {
    final String title = _readString(json,
    <String>[
      'title',
      'headline'
    ],
    );
    return _FeedItem(id: _readString(json,
    <String>[
      '_id',
      'id'
    ],
    ),
    type: 'post',
    title: title.isEmpty ? 'Health Update' : title,
    description: _readString(json,
    <String>[
      'content',
      'body',
      'description',
      'message'
    ],
    ),
    rhuName: _readRhuName(json),
    createdAt: _readDateTime(json,
    <String>[
      'publishedAt',
      'createdAt'
    ],
    ),
    dateLine: '',
    rawJson: Map<String, dynamic>.from(json),
    );
  }
  factory _FeedItem.fromEvent(Map<String, dynamic> json) {
    final DateTime startDate = _readDateTime(json,
    <String>[
      'startDate',
      'eventDate',
      'scheduledAt',
      'createdAt'
    ],
    );
    final String title = _readString(json,
    <String>[
      'title',
      'name'
    ],
    );
    return _FeedItem(id: _readString(json,
    <String>[
      '_id',
      'id'
    ],
    ),
    type: 'event',
    title: title.isEmpty ? 'RHU Event' : title,
    description: _readString(json,
    <String>[
      'description',
      'details',
      'content'
    ],
    ),
    rhuName: _readRhuName(json),
    createdAt: _readDateTime(json,
    <String>[
      'createdAt',
      'publishedAt'
    ],
    ),
    dateLine: 'Event date: ${_formatDate(startDate)}',
    rawJson: Map<String, dynamic>.from(json),
    );
  }
  factory _FeedItem.fromSurvey(Map<String, dynamic> json) {
    final DateTime endDate = _readDateTime(json,
    <String>[
      'endDate',
      'closeDate',
      'expiresAt',
      'createdAt'
    ],
    );
    final String title = _readString(json,
    <String>[
      'title',
      'name'
    ],
    );
    return _FeedItem(id: _readString(json,
    <String>[
      '_id',
      'id'
    ],
    ),
    type: 'survey',
    title: title.isEmpty ? 'RHU Survey' : title,
    description: _readString(json,
    <String>[
      'description',
      'details',
      'content'
    ],
    ),
    rhuName: _readRhuName(json),
    createdAt: _readDateTime(json,
    <String>[
      'createdAt',
      'publishedAt'
    ],
    ),
    dateLine: endDate.year <= 1971 ? '' : 'Survey closes: ${_formatDate(endDate)}',
    rawJson: Map<String, dynamic>.from(json),
    );
  }
  final String id;
  final String type;
  final String title;
  final String description;
  final String rhuName;
  final DateTime createdAt;
  final String dateLine;
  final Map<String, dynamic> rawJson;
  String get uniqueKey {
    if (id.trim().isNotEmpty) {
      return '$type-$id';
    }
    return '$type-$title-${createdAt.toIso8601String()}';
  }
  String get timeAgo {
    final Duration difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return _formatDate(createdAt);
  }
}
class _EventRegistrationDialog extends StatefulWidget {
  const _EventRegistrationDialog({required this.eventTitle,
  required this.defaultName,
  required this.defaultEmail,
  required this.defaultPhone,
  });
  final String eventTitle;
  final String defaultName;
  final String defaultEmail;
  final String defaultPhone;
  @override
  State<_EventRegistrationDialog> createState() => _EventRegistrationDialogState();
}
class _EventRegistrationDialogState extends State<_EventRegistrationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  final TextEditingController _notesController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
    _contactController = TextEditingController(text: widget.defaultPhone);
    _emailController = TextEditingController(text: widget.defaultEmail);
  }
  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  String? _requiredValidator(String? value,
  String fieldName
  ) {
    if ((value ?? '').trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }
  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(_EventRegistrationInput(attendeeName: _nameController.text.trim(),
    contactNumber: _contactController.text.trim(),
    email: _emailController.text.trim(),
    notes: _notesController.text.trim(),
    ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(title: const Text('Register for Event',
    style: TextStyle(fontWeight: FontWeight.w900,
    ),
    ),
    content: SizedBox(width: 520,
    child: SingleChildScrollView(child: Form(key: _formKey,
    child: Column(mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      _DialogInfoBox(icon: Icons.event_rounded,
      title: widget.eventTitle,
      subtitle: 'Submit your registration details for this event.',
      color: const Color(0xFF2563EB),
      ),
      const SizedBox(height: 14),
      TextFormField(controller: _nameController,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Attendee name',
      prefixIcon: Icon(Icons.person_rounded),
      ),
      validator: (String? value) {
        return _requiredValidator(value,
        'Attendee name'
        );
      },
      ),
      const SizedBox(height: 12),
      TextFormField(controller: _contactController,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(labelText: 'Contact number optional',
      prefixIcon: Icon(Icons.phone_rounded),
      ),
      ),
      const SizedBox(height: 12),
      TextFormField(controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'Email optional',
      prefixIcon: Icon(Icons.email_rounded),
      ),
      ),
      const SizedBox(height: 12),
      TextFormField(controller: _notesController,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'Notes optional',
      hintText: 'Example: I will bring my child.',
      alignLabelWithHint: true,
      prefixIcon: Icon(Icons.notes_rounded),
      ),
      ),
    ],
    ),
    ),
    ),
    ),
    actions: <Widget>[
      TextButton(onPressed: () {
        Navigator.of(context).pop();
      },
      child: const Text('Cancel'),
      ),
      FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB),
      ),
      onPressed: _submit,
      icon: const Icon(Icons.how_to_reg_rounded),
      label: const Text('Register'),
      ),
    ],
    );
  }
}
class _SurveyResponseDialog extends StatefulWidget {
  const _SurveyResponseDialog({required this.surveyTitle,
  required this.questions,
  required this.defaultName,
  required this.defaultEmail,
  required this.defaultPhone,
  });
  final String surveyTitle;
  final List<_SurveyQuestion> questions;
  final String defaultName;
  final String defaultEmail;
  final String defaultPhone;
  @override
  State<_SurveyResponseDialog> createState() => _SurveyResponseDialogState();
}
class _SurveyResponseDialogState extends State<_SurveyResponseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  final List<TextEditingController> _answerControllers = <TextEditingController>[];
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
    _contactController = TextEditingController(text: widget.defaultPhone);
    _emailController = TextEditingController(text: widget.defaultEmail);
    final List<_SurveyQuestion> questions = _effectiveQuestions;
    for (int index = 0; index < questions.length; index += 1) {
      _answerControllers.add(TextEditingController());
    }
  }
  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    for (final TextEditingController controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  List<_SurveyQuestion> get _effectiveQuestions {
    if (widget.questions.isNotEmpty) {
      return widget.questions;
    }
    return const <_SurveyQuestion>[
      _SurveyQuestion(id: 'general_feedback',
      text: 'Your answer / feedback',
      ),
    ];
  }
  String? _requiredValidator(String? value,
  String fieldName
  ) {
    if ((value ?? '').trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }
  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final List<_SurveyQuestion> questions = _effectiveQuestions;
    final List<_SurveyAnswerInput> answers = <_SurveyAnswerInput>[];
    for (int index = 0; index < questions.length; index += 1) {
      final _SurveyQuestion question = questions[
        index
      ];
      final String answer = _answerControllers[
        index
      ].text.trim();
      answers.add(_SurveyAnswerInput(questionId: question.id,
      questionText: question.text,
      answer: answer,
      ),
      );
    }
    Navigator.of(context).pop(_SurveyResponseInput(respondentName: _nameController.text.trim(),
    contactNumber: _contactController.text.trim(),
    email: _emailController.text.trim(),
    answers: answers,
    ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final List<_SurveyQuestion> questions = _effectiveQuestions;
    return AlertDialog(title: const Text('Answer Survey',
    style: TextStyle(fontWeight: FontWeight.w900,
    ),
    ),
    content: SizedBox(width: 560,
    child: SingleChildScrollView(child: Form(key: _formKey,
    child: Column(mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      _DialogInfoBox(icon: Icons.poll_rounded,
      title: widget.surveyTitle,
      subtitle: 'Your response helps the RHU improve services.',
      color: const Color(0xFF7C3AED),
      ),
      const SizedBox(height: 14),
      TextFormField(controller: _nameController,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Respondent name',
      prefixIcon: Icon(Icons.person_rounded),
      ),
      validator: (String? value) {
        return _requiredValidator(value,
        'Respondent name'
        );
      },
      ),
      const SizedBox(height: 12),
      TextFormField(controller: _contactController,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(labelText: 'Contact number optional',
      prefixIcon: Icon(Icons.phone_rounded),
      ),
      ),
      const SizedBox(height: 12),
      TextFormField(controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'Email optional',
      prefixIcon: Icon(Icons.email_rounded),
      ),
      ),
      const SizedBox(height: 16),
      ...questions.asMap().entries.map((MapEntry<int, _SurveyQuestion> entry) {
        return Padding(padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(controller: _answerControllers[
          entry.key
        ],
        maxLines: 3,
        decoration: InputDecoration(labelText: entry.value.text,
        alignLabelWithHint: true,
        prefixIcon: const Icon(Icons.edit_note_rounded),
        ),
        validator: (String? value) {
          return _requiredValidator(value,
          'Answer',
          );
        },
        ),
        );
      },
      ),
    ],
    ),
    ),
    ),
    ),
    actions: <Widget>[
      TextButton(onPressed: () {
        Navigator.of(context).pop();
      },
      child: const Text('Cancel'),
      ),
      FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED),
      ),
      onPressed: _submit,
      icon: const Icon(Icons.send_rounded),
      label: const Text('Submit Survey'),
      ),
    ],
    );
  }
}
class _DialogInfoBox extends StatelessWidget {
  const _DialogInfoBox({required this.icon,
  required this.title,
  required this.subtitle,
  required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: color.withValues(alpha: 0.24),
    ),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Icon(icon,
      color: color
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title,
        style: TextStyle(color: color,
        fontWeight: FontWeight.w900,
        ),
        ),
        const SizedBox(height: 3),
        Text(subtitle,
        style: const TextStyle(color: Color(0xFF475569),
        height: 1.35,
        fontWeight: FontWeight.w700,
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
class _EventRegistrationInput {
  const _EventRegistrationInput({required this.attendeeName,
  required this.contactNumber,
  required this.email,
  required this.notes,
  });
  final String attendeeName;
  final String contactNumber;
  final String email;
  final String notes;
  Map<String, dynamic> toJson() {
    return <String, dynamic> {
      'attendeeName': attendeeName,
      'contactNumber': contactNumber,
      'email': email,
      'notes': notes,
    };
  }
}
class _SurveyResponseInput {
  const _SurveyResponseInput({required this.respondentName,
  required this.contactNumber,
  required this.email,
  required this.answers,
  });
  final String respondentName;
  final String contactNumber;
  final String email;
  final List<_SurveyAnswerInput> answers;
  Map<String, dynamic> toJson() {
    return <String, dynamic> {
      'respondentName': respondentName,
      'contactNumber': contactNumber,
      'email': email,
      'answers': answers.map((_SurveyAnswerInput answer) {
        return answer.toJson();
      }).toList(),
    };
  }
}
class _SurveyAnswerInput {
  const _SurveyAnswerInput({required this.questionId,
  required this.questionText,
  required this.answer,
  });
  final String questionId;
  final String questionText;
  final String answer;
  Map<String, dynamic> toJson() {
    return <String, dynamic> {
      'questionId': questionId,
      'questionText': questionText,
      'answer': answer,
    };
  }
}
class _SurveyQuestion {
  const _SurveyQuestion({required this.id,
  required this.text,
  });
  final String id;
  final String text;
  static List<_SurveyQuestion> fromSurveyJson(Map<String, dynamic> json) {
    final dynamic rawQuestions = json[
      'questions'
    ] ?? json[
      'items'
    ] ?? json[
      'surveyQuestions'
    ];
    if (rawQuestions is! List) {
      return const <_SurveyQuestion>[];
    }
    final List<_SurveyQuestion> questions = <_SurveyQuestion>[];
    for (int index = 0; index < rawQuestions.length; index += 1) {
      final dynamic rawQuestion = rawQuestions[
        index
      ];
      if (rawQuestion is Map<String, dynamic>) {
        final String text = _readString(rawQuestion,
        <String>[
          'questionText',
          'question',
          'title',
          'label',
          'text'
        ],
        );
        if (text.trim().isNotEmpty) {
          questions.add(_SurveyQuestion(id: _readString(rawQuestion,
          <String>[
            '_id',
            'id',
            'questionId'
          ],
          fallback: 'question_$index',
          ),
          text: text,
          ),
          );
        }
      } else {
        final String text = rawQuestion.toString().trim();
        if (text.isNotEmpty) {
          questions.add(_SurveyQuestion(id: 'question_$index',
          text: text,
          ),
          );
        }
      }
    }
    return questions;
  }
}
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message,
  required this.onRetry,
  });
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Card(color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(22),
    child: Column(children: <Widget>[
      const Icon(Icons.error_outline_rounded,
      color: Color(0xFFDC2626),
      size: 44,
      ),
      const SizedBox(height: 12),
      Text('Unable to load feed',
      style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(message,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Try Again'),
      ),
    ],
    ),
    ),
    );
  }
}
class _LoadingFeed extends StatelessWidget {
  const _LoadingFeed();
  @override
  Widget build(BuildContext context) {
    return Column(children: List<Widget>.generate(4,
    (int index) {
      return const Padding(padding: EdgeInsets.only(bottom: 12),
      child: Card(color: Colors.white,
      child: Padding(padding: EdgeInsets.all(18),
      child: Row(children: <Widget>[
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('Loading social health updates...'),
        ),
      ],
      ),
      ),
      ),
      );
    },
    ),
    );
  }
}
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();
  @override
  Widget build(BuildContext context) {
    return Card(color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(28),
    child: Column(children: <Widget>[
      Container(width: 72,
      height: 72,
      decoration: BoxDecoration(color: const Color(0xFFE0F2FE),
      borderRadius: BorderRadius.circular(26),
      ),
      child: const Icon(Icons.public_off_rounded,
      color: Color(0xFF0EA5E9),
      size: 38,
      ),
      ),
      const SizedBox(height: 16),
      Text('No updates yet',
      style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text('RHU posts, events, and surveys will appear here.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
    ),
    ),
    );
  }
}
String _readRhuName(Map<String, dynamic> json) {
  final dynamic rhu = json[
    'rhu'
  ];
  if (rhu is Map<String, dynamic>) {
    final String name = _readString(rhu,
    <String>[
      'name',
      'rhuName',
      'officeName'
    ],
    );
    if (name.trim().isNotEmpty) {
      return name;
    }
  }
  final String directName = _readString(json,
  <String>[
    'rhuName',
    'officeName',
    'municipality'
  ],
  );
  if (directName.trim().isNotEmpty) {
    return directName;
  }
  return 'RHU Tawi-Tawi';
}
String _readString(Map<String, dynamic> json,
List<String> keys,
{String fallback = '',
}) {
  for (final String key in keys) {
    final dynamic value = json[
      key
    ];
    if (value == null) {
      continue;
    }
    if (value is Map<String, dynamic>) {
      final String nestedValue = _readString(value,
      <String>[
        'name',
        'title',
        'fullName',
        'email'
      ],
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
DateTime _readDateTime(Map<String, dynamic> json,
List<String> keys,
) {
  for (final String key in keys) {
    final dynamic value = json[
      key
    ];
    if (value == null) {
      continue;
    }
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      continue;
    }
  }
  return DateTime.now();
}
String _formatDate(DateTime date) {
  final String year = date.year.toString().padLeft(4,
  '0'
  );
  final String month = date.month.toString().padLeft(2,
  '0'
  );
  final String day = date.day.toString().padLeft(2,
  '0'
  );
  return '$year-$month-$day';
}
