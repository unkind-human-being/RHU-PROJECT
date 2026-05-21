import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class PublicRhuDirectoryScreen extends StatefulWidget {
  const PublicRhuDirectoryScreen({super.key});

  static const String routeName = '/public-rhus';

  @override
  State<PublicRhuDirectoryScreen> createState() =>
      _PublicRhuDirectoryScreenState();
}

class _PublicRhuDirectoryScreenState extends State<PublicRhuDirectoryScreen> {
  late final ApiClient _apiClient;

  bool _isLoading = false;
  String? _errorMessage;
  String _searchText = '';

  List<_RhuProfile> _rhus = <_RhuProfile>[];
  List<_PublicUpdateItem> _publicUpdates = <_PublicUpdateItem>[];
  final Map<String, _AppointmentSetting> _settingsByRhuId =
      <String, _AppointmentSetting>{};
  final Set<String> _loadingSettingIds = <String>{};

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRhus();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  List<_RhuProfile> get _filteredRhus {
    final String query = _searchText.trim().toLowerCase();

    if (query.isEmpty) {
      return _rhus;
    }

    return _rhus.where((_RhuProfile rhu) {
      return rhu.name.toLowerCase().contains(query) ||
          rhu.municipality.toLowerCase().contains(query) ||
          rhu.province.toLowerCase().contains(query) ||
          rhu.contactNumber.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _loadRhus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/rhus',
        requiresAuth: true,
      );

      final List<dynamic> rawRhus = _extractList(response);

      final List<_RhuProfile> rhus = rawRhus
          .whereType<Map<String, dynamic>>()
          .map(_RhuProfile.fromJson)
          .where((_RhuProfile rhu) => rhu.id.trim().isNotEmpty)
          .toList();

      rhus.sort((_RhuProfile a, _RhuProfile b) {
        return a.municipality.compareTo(b.municipality);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _rhus = rhus;
      });

      for (final _RhuProfile rhu in rhus) {
        _loadAppointmentSettingSilently(rhu.id);
      }

      await _loadPublicUpdatesSilently();
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
        _errorMessage = 'Unable to load RHU profiles.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAppointmentSettingSilently(String rhuId) async {
    if (rhuId.trim().isEmpty ||
        _settingsByRhuId.containsKey(rhuId) ||
        _loadingSettingIds.contains(rhuId)) {
      return;
    }

    setState(() {
      _loadingSettingIds.add(rhuId);
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/appointment-settings/rhu/${Uri.encodeComponent(rhuId)}',
        requiresAuth: true,
      );

      final Map<String, dynamic> data = _extractMap(response);
      final _AppointmentSetting setting = _AppointmentSetting.fromJson(data);

      if (!mounted) {
        return;
      }

      setState(() {
        _settingsByRhuId[rhuId] = setting;
      });
    } catch (_) {
      // RHU profile still displays even when settings fail to load.
    } finally {
      if (mounted) {
        setState(() {
          _loadingSettingIds.remove(rhuId);
        });
      }
    }
  }

  Future<void> _loadPublicUpdatesSilently() async {
    try {
      final List<_PublicUpdateItem> loadedUpdates = <_PublicUpdateItem>[];

      final Map<String, dynamic> postsResponse = await _apiClient.get(
        '/api/posts/public',
        requiresAuth: false,
      );

      loadedUpdates.addAll(
        _extractList(postsResponse).whereType<Map<String, dynamic>>().map(
              (Map<String, dynamic> json) => _PublicUpdateItem.fromPost(json),
            ),
      );

      final Map<String, dynamic> eventsResponse = await _apiClient.get(
        '/api/events/public',
        requiresAuth: false,
      );

      loadedUpdates.addAll(
        _extractList(eventsResponse).whereType<Map<String, dynamic>>().map(
              (Map<String, dynamic> json) => _PublicUpdateItem.fromEvent(json),
            ),
      );

      final Map<String, dynamic> surveysResponse = await _apiClient.get(
        '/api/surveys/public',
        requiresAuth: false,
      );

      loadedUpdates.addAll(
        _extractList(surveysResponse).whereType<Map<String, dynamic>>().map(
              (Map<String, dynamic> json) => _PublicUpdateItem.fromSurvey(json),
            ),
      );

      loadedUpdates.sort((_PublicUpdateItem a, _PublicUpdateItem b) {
        return b.createdAt.compareTo(a.createdAt);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _publicUpdates = loadedUpdates;
      });
    } catch (_) {
      // RHU profiles still work even if public updates fail to load.
    }
  }

  List<_PublicUpdateItem> _updatesForRhu(_RhuProfile rhu) {
    return _publicUpdates.where((_PublicUpdateItem update) {
      final bool matchesId =
          update.rhuId.trim().isNotEmpty && update.rhuId == rhu.id;

      final bool matchesName = update.rhuName.trim().isNotEmpty &&
          update.rhuName.toLowerCase() == rhu.name.toLowerCase();

      final bool matchesMunicipality = update.rhuName.trim().isNotEmpty &&
          update.rhuName.toLowerCase().contains(rhu.municipality.toLowerCase());

      return matchesId || matchesName || matchesMunicipality;
    }).toList();
  }

  List<dynamic> _extractList(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final dynamic rhus = data['rhus'];
      final dynamic posts = data['posts'];
      final dynamic events = data['events'];
      final dynamic surveys = data['surveys'];
      final dynamic records = data['records'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (rhus is List) {
        return rhus;
      }

      if (posts is List) {
        return posts;
      }

      if (events is List) {
        return events;
      }

      if (surveys is List) {
        return surveys;
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

    final dynamic rhus = response['rhus'];
    final dynamic posts = response['posts'];
    final dynamic events = response['events'];
    final dynamic surveys = response['surveys'];

    if (rhus is List) {
      return rhus;
    }

    if (posts is List) {
      return posts;
    }

    if (events is List) {
      return events;
    }

    if (surveys is List) {
      return surveys;
    }

    return <dynamic>[];
  }

  Map<String, dynamic> _extractMap(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return response;
  }

  void _openRhuProfile(_RhuProfile rhu) {
    _loadAppointmentSettingSilently(rhu.id);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _RhuProfileSheet(
          rhu: rhu,
          setting: _settingsByRhuId[rhu.id],
          isLoadingSetting: _loadingSettingIds.contains(rhu.id),
          publicUpdates: _updatesForRhu(rhu),
          onApplyAppointment: () {
            Navigator.of(context).pop();

            Future<void>.delayed(const Duration(milliseconds: 180), () {
              if (!mounted) {
                return;
              }

              Navigator.of(this.context).pushNamed(
                '/apply-appointment',
                arguments: <String, dynamic>{
                  'rhuId': rhu.id,
                },
              );
            });
          },
        );
      },
    );
  }

  void _openApplyAppointment() {
    Navigator.of(context).pushNamed('/apply-appointment');
  }

  @override
  Widget build(BuildContext context) {
    final List<_RhuProfile> filteredRhus = _filteredRhus;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        title: const Text(
          'RHU Profiles',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadRhus,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRhus,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _HeaderCard(
                    totalRhus: _rhus.length,
                    openRhus: _settingsByRhuId.values.where(
                      (_AppointmentSetting setting) {
                        return setting.isAcceptingAppointments;
                      },
                    ).length,
                    onApplyAppointment: _openApplyAppointment,
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
                      onRetry: _loadRhus,
                    ),
                  ),
                )
              else if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _LoadingBox(),
                  ),
                )
              else if (filteredRhus.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyState(),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: filteredRhus.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _RhuProfile rhu = filteredRhus[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: index == 0 ? 12 : 0,
                        bottom: 12,
                      ),
                      child: _RhuProfileCard(
                        rhu: rhu,
                        setting: _settingsByRhuId[rhu.id],
                        isLoadingSetting: _loadingSettingIds.contains(rhu.id),
                        onTap: () {
                          _openRhuProfile(rhu);
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

class _RhuProfile {
  const _RhuProfile({
    required this.id,
    required this.code,
    required this.name,
    required this.municipality,
    required this.province,
    required this.address,
    required this.contactNumber,
    required this.email,
    required this.barangayCount,
  });

  factory _RhuProfile.fromJson(Map<String, dynamic> json) {
    return _RhuProfile(
      id: _readString(json, <String>['_id', 'id']),
      code: _readString(json, <String>['code']),
      name: _readString(
        json,
        <String>['name', 'rhuName', 'officeName'],
        fallback: 'Unnamed RHU',
      ),
      municipality: _readString(json, <String>['municipality', 'city']),
      province: _readString(
        json,
        <String>['province'],
        fallback: 'Tawi-Tawi',
      ),
      address: _readString(json, <String>['address']),
      contactNumber: _readString(
        json,
        <String>['contactNumber', 'phoneNumber', 'phone'],
      ),
      email: _readString(json, <String>['email']),
      barangayCount: int.tryParse(
            _readString(json, <String>['barangayCount']),
          ) ??
          0,
    );
  }

  final String id;
  final String code;
  final String name;
  final String municipality;
  final String province;
  final String address;
  final String contactNumber;
  final String email;
  final int barangayCount;
}

class _AppointmentSetting {
  const _AppointmentSetting({
    required this.isAcceptingAppointments,
    required this.allowWalkIn,
    required this.allowOnline,
    required this.unavailableReason,
    required this.walkInStartTime,
    required this.walkInEndTime,
    required this.onlineStartTime,
    required this.onlineEndTime,
    required this.instructionsForPatients,
  });

  factory _AppointmentSetting.fromJson(Map<String, dynamic> json) {
    return _AppointmentSetting(
      isAcceptingAppointments: _readBool(
        json,
        'isAcceptingAppointments',
        fallback: true,
      ),
      allowWalkIn: _readBool(json, 'allowWalkIn', fallback: true),
      allowOnline: _readBool(json, 'allowOnline', fallback: true),
      unavailableReason: _readString(json, <String>['unavailableReason']),
      walkInStartTime: _readString(
        json,
        <String>['walkInStartTime'],
        fallback: '08:00',
      ),
      walkInEndTime: _readString(
        json,
        <String>['walkInEndTime'],
        fallback: '17:00',
      ),
      onlineStartTime: _readString(
        json,
        <String>['onlineStartTime'],
        fallback: '08:00',
      ),
      onlineEndTime: _readString(
        json,
        <String>['onlineEndTime'],
        fallback: '17:00',
      ),
      instructionsForPatients: _readString(
        json,
        <String>['instructionsForPatients'],
      ),
    );
  }

  final bool isAcceptingAppointments;
  final bool allowWalkIn;
  final bool allowOnline;
  final String unavailableReason;
  final String walkInStartTime;
  final String walkInEndTime;
  final String onlineStartTime;
  final String onlineEndTime;
  final String instructionsForPatients;
}

class _PublicUpdateItem {
  const _PublicUpdateItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.rhuId,
    required this.rhuName,
    required this.createdAt,
    required this.dateLine,
  });

  factory _PublicUpdateItem.fromPost(Map<String, dynamic> json) {
    return _PublicUpdateItem(
      id: _readString(json, <String>['_id', 'id']),
      type: 'post',
      title: _readString(json, <String>['title', 'headline']).isEmpty
          ? 'Health Update'
          : _readString(json, <String>['title', 'headline']),
      description: _readString(
        json,
        <String>['content', 'body', 'description', 'message'],
      ),
      rhuId: _readRhuId(json),
      rhuName: _readRhuName(json),
      createdAt: _readDateTime(json, <String>['publishedAt', 'createdAt']),
      dateLine: '',
    );
  }

  factory _PublicUpdateItem.fromEvent(Map<String, dynamic> json) {
    final DateTime startDate = _readDateTime(
      json,
      <String>['startDate', 'eventDate', 'scheduledAt', 'createdAt'],
    );

    return _PublicUpdateItem(
      id: _readString(json, <String>['_id', 'id']),
      type: 'event',
      title: _readString(json, <String>['title', 'name']).isEmpty
          ? 'RHU Event'
          : _readString(json, <String>['title', 'name']),
      description: _readString(
        json,
        <String>['description', 'details', 'content'],
      ),
      rhuId: _readRhuId(json),
      rhuName: _readRhuName(json),
      createdAt: _readDateTime(json, <String>['createdAt', 'publishedAt']),
      dateLine: 'Event date: ${_formatDate(startDate)}',
    );
  }

  factory _PublicUpdateItem.fromSurvey(Map<String, dynamic> json) {
    final DateTime endDate = _readDateTime(
      json,
      <String>['endDate', 'closeDate', 'expiresAt', 'createdAt'],
    );

    return _PublicUpdateItem(
      id: _readString(json, <String>['_id', 'id']),
      type: 'survey',
      title: _readString(json, <String>['title', 'name']).isEmpty
          ? 'RHU Survey'
          : _readString(json, <String>['title', 'name']),
      description: _readString(
        json,
        <String>['description', 'details', 'content'],
      ),
      rhuId: _readRhuId(json),
      rhuName: _readRhuName(json),
      createdAt: _readDateTime(json, <String>['createdAt', 'publishedAt']),
      dateLine:
          endDate.year <= 1971 ? '' : 'Survey closes: ${_formatDate(endDate)}',
    );
  }

  final String id;
  final String type;
  final String title;
  final String description;
  final String rhuId;
  final String rhuName;
  final DateTime createdAt;
  final String dateLine;

  String get typeLabel {
    switch (type) {
      case 'event':
        return 'Event';
      case 'survey':
        return 'Survey';
      default:
        return 'Post';
    }
  }

  IconData get icon {
    switch (type) {
      case 'event':
        return Icons.event_rounded;
      case 'survey':
        return Icons.poll_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'event':
        return const Color(0xFF2563EB);
      case 'survey':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF0EA5E9);
    }
  }
}

class _PublicUpdatePreviewCard extends StatelessWidget {
  const _PublicUpdatePreviewCard({
    required this.update,
  });

  final _PublicUpdateItem update;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: update.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: update.color.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            update.icon,
            color: update.color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  update.typeLabel,
                  style: TextStyle(
                    color: update.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  update.title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (update.description.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    update.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (update.dateLine.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    update.dateLine,
                    style: TextStyle(
                      color: update.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.totalRhus,
    required this.openRhus,
    required this.onApplyAppointment,
  });

  final int totalRhus;
  final int openRhus;
  final VoidCallback onApplyAppointment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0EA5E9),
            Color(0xFF0284C7),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
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
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 34,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'RHU Public Profiles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'View RHU contact details, appointment availability, and public health services.',
            style: TextStyle(
              color: Color(0xFFE0F2FE),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'RHU Profiles',
                  value: totalRhus.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Open RHUs',
                  value: openRhus.toString(),
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
                foregroundColor: const Color(0xFF0284C7),
              ),
              onPressed: onApplyAppointment,
              icon: const Icon(Icons.event_available_rounded),
              label: const Text(
                'Apply Appointment',
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
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE0F2FE),
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
        hintText: 'Search RHU or municipality...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFBAE6FD),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFBAE6FD),
          ),
        ),
      ),
    );
  }
}

class _RhuProfileCard extends StatelessWidget {
  const _RhuProfileCard({
    required this.rhu,
    required this.setting,
    required this.isLoadingSetting,
    required this.onTap,
  });

  final _RhuProfile rhu;
  final _AppointmentSetting? setting;
  final bool isLoadingSetting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isOpen = setting?.isAcceptingAppointments ?? true;
    final String contact = rhu.contactNumber.trim().isEmpty
        ? 'No contact number listed'
        : rhu.contactNumber;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(
          color: Color(0xFFBAE6FD),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isOpen
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.local_hospital_rounded,
                  color: isOpen
                      ? const Color(0xFF0EA5E9)
                      : const Color(0xFFDC2626),
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      rhu.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fallback(rhu.municipality)} • ${_fallback(rhu.province)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact,
                      style: const TextStyle(
                        color: Color(0xFF075985),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (isLoadingSetting)
                      const Text(
                        'Checking availability...',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      _AvailabilityMiniLine(setting: setting),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF0EA5E9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityMiniLine extends StatelessWidget {
  const _AvailabilityMiniLine({
    required this.setting,
  });

  final _AppointmentSetting? setting;

  @override
  Widget build(BuildContext context) {
    if (setting == null) {
      return const Text(
        'Availability not loaded',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    if (!setting!.isAcceptingAppointments) {
      return const Text(
        'Appointments closed',
        style: TextStyle(
          color: Color(0xFFDC2626),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    final List<String> types = <String>[];

    if (setting!.allowWalkIn) {
      types.add('Walk-in');
    }

    if (setting!.allowOnline) {
      types.add('Online');
    }

    return Text(
      types.isEmpty ? 'No appointment type open' : 'Open: ${types.join(', ')}',
      style: const TextStyle(
        color: Color(0xFF16A34A),
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _RhuProfileSheet extends StatelessWidget {
  const _RhuProfileSheet({
    required this.rhu,
    required this.setting,
    required this.isLoadingSetting,
    required this.publicUpdates,
    required this.onApplyAppointment,
  });

  final _RhuProfile rhu;
  final _AppointmentSetting? setting;
  final bool isLoadingSetting;
  final List<_PublicUpdateItem> publicUpdates;
  final VoidCallback onApplyAppointment;

  @override
  Widget build(BuildContext context) {
    final String contact = rhu.contactNumber.trim().isEmpty
        ? 'No contact number listed'
        : rhu.contactNumber;

    final String email = rhu.email.trim().isEmpty ? 'No email listed' : rhu.email;
    final String address =
        rhu.address.trim().isEmpty ? 'No address listed' : rhu.address;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
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
                rhu.name,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_fallback(rhu.municipality)} • ${_fallback(rhu.province)}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _ProfileSection(
                title: 'RHU Contact Details',
                icon: Icons.contact_phone_rounded,
                children: <Widget>[
                  _InfoLine(label: 'Phone', value: contact),
                  _InfoLine(label: 'Email', value: email),
                  _InfoLine(label: 'Address', value: address),
                  _InfoLine(
                    label: 'Barangays',
                    value: rhu.barangayCount <= 0
                        ? 'Not listed'
                        : rhu.barangayCount.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ProfileSection(
                title: 'Appointment Availability',
                icon: Icons.event_available_rounded,
                children: <Widget>[
                  if (isLoadingSetting)
                    const _SmallLoadingLine()
                  else if (setting == null)
                    const Text(
                      'Availability settings are not loaded.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    _AppointmentSettingDetails(setting: setting!),
                ],
              ),
              const SizedBox(height: 16),
              _ProfileSection(
                title: 'Public Health Updates',
                icon: Icons.campaign_rounded,
                children: <Widget>[
                  if (publicUpdates.isEmpty)
                    const Text(
                      'No public posts, events, or surveys found for this RHU yet.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    ...publicUpdates.take(5).map((_PublicUpdateItem update) {
                      return _PublicUpdatePreviewCard(update: update);
                    }),
                  if (publicUpdates.length > 5) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      '+${publicUpdates.length - 5} more public update(s)',
                      style: const TextStyle(
                        color: Color(0xFF0EA5E9),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                ),
                onPressed: onApplyAppointment,
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Apply Appointment'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_rounded),
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

class _AppointmentSettingDetails extends StatelessWidget {
  const _AppointmentSettingDetails({
    required this.setting,
  });

  final _AppointmentSetting setting;

  @override
  Widget build(BuildContext context) {
    if (!setting.isAcceptingAppointments) {
      return _NoticeBox(
        color: const Color(0xFFDC2626),
        icon: Icons.event_busy_rounded,
        text: setting.unavailableReason.trim().isEmpty
            ? 'This RHU is not accepting appointments right now.'
            : setting.unavailableReason,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _NoticeBox(
          color: Color(0xFF16A34A),
          icon: Icons.check_circle_rounded,
          text: 'This RHU is accepting appointments.',
        ),
        const SizedBox(height: 10),
        if (setting.allowWalkIn)
          _InfoLine(
            label: 'Walk-in',
            value:
                '${_formatTimeLabel(setting.walkInStartTime)} - ${_formatTimeLabel(setting.walkInEndTime)}',
          ),
        if (setting.allowOnline)
          _InfoLine(
            label: 'Online',
            value:
                '${_formatTimeLabel(setting.onlineStartTime)} - ${_formatTimeLabel(setting.onlineEndTime)}',
          ),
        if (!setting.allowWalkIn && !setting.allowOnline)
          const _InfoLine(
            label: 'Types',
            value: 'No appointment type is currently open.',
          ),
        if (setting.instructionsForPatients.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            setting.instructionsForPatients,
            style: const TextStyle(
              color: Color(0xFF475569),
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                height: 1.35,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: const Color(0xFF0EA5E9)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
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
            width: 94,
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

class _SmallLoadingLine extends StatelessWidget {
  const _SmallLoadingLine();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Checking appointment availability...',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 14),
            Expanded(
              child: Text('Loading RHU profiles...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.local_hospital_outlined,
              color: Color(0xFF0EA5E9),
              size: 54,
            ),
            SizedBox(height: 16),
            Text(
              'No RHUs found',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'RHU profiles will appear here after they are added by IPHO Admin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
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
      color: Colors.white,
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
              'Unable to load RHUs',
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

String _readRhuId(Map<String, dynamic> json) {
  final dynamic rhu = json['rhu'];

  if (rhu is Map<String, dynamic>) {
    final String id = _readString(rhu, <String>['_id', 'id']);

    if (id.trim().isNotEmpty) {
      return id;
    }
  }

  return _readString(json, <String>['rhuId', 'rhu']);
}

String _readRhuName(Map<String, dynamic> json) {
  final dynamic rhu = json['rhu'];

  if (rhu is Map<String, dynamic>) {
    final String name = _readString(
      rhu,
      <String>['name', 'rhuName', 'officeName', 'municipality'],
    );

    if (name.trim().isNotEmpty) {
      return name;
    }
  }

  return _readString(
    json,
    <String>['rhuName', 'officeName', 'municipality'],
    fallback: 'RHU Tawi-Tawi',
  );
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

String _formatDate(DateTime date) {
  if (date.year <= 1971) {
    return 'N/A';
  }

  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
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

bool _readBool(
  Map<String, dynamic> json,
  String key, {
  required bool fallback,
}) {
  final dynamic value = json[key];

  if (value is bool) {
    return value;
  }

  if (value is String) {
    return value.toLowerCase() == 'true';
  }

  return fallback;
}

String _fallback(String value) {
  if (value.trim().isEmpty || value.trim() == 'null') {
    return 'Not listed';
  }

  return value.trim();
}

String _formatTimeLabel(String value) {
  final List<String> parts = value.split(':');

  if (parts.length != 2) {
    return value;
  }

  final int hour = int.tryParse(parts[0]) ?? 0;
  final int minute = int.tryParse(parts[1]) ?? 0;

  final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final String period = hour >= 12 ? 'PM' : 'AM';

  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}
