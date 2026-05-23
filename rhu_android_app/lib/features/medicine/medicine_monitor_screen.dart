import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';
import '../../data/models/medicine_model.dart';
import '../../data/repositories/medicine_repository.dart';
import '../auth/auth_provider.dart';

class MedicineMonitorScreen extends StatefulWidget {
  const MedicineMonitorScreen({super.key});

  static const String routeName = '/medicine-monitor';

  @override
  State<MedicineMonitorScreen> createState() => _MedicineMonitorScreenState();
}

class _MedicineMonitorScreenState extends State<MedicineMonitorScreen> {
  static const String _locationCacheBoxName =
      'rhu_medicine_monitor_location_cache';

  final TextEditingController _searchController = TextEditingController();
  final MedicineRepository _medicineRepository = MedicineRepository();

  late final ApiClient _apiClient;

  Timer? _searchDebounce;

  bool _isLoading = false;
  bool _isLoadingLocations = false;
  bool _hasSearchText = false;

  String? _errorMessage;
  String? _selectedRhuId;
  String? _selectedBarangayId;
  String? _selectedStockStatus;

  List<MedicineModel> _medicines = <MedicineModel>[];
  List<_RhuOption> _rhus = <_RhuOption>[];
  List<_BarangayOption> _barangays = <_BarangayOption>[];

  List<MedicineModel> get _visibleMedicines {
    final String query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _medicines;
    }

    return _medicines.where((MedicineModel medicine) {
      final String searchableText = <String>[
        medicine.displayName,
        medicine.category,
        medicine.batchNumber,
        medicine.locationName,
        medicine.stockStatusLabel,
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    _searchController.addListener(_handleSearchTextState);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadLocationOptions();

      if (mounted) {
        setState(() {
          _medicines = <MedicineModel>[];
        });
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchTextState);
    _searchController.dispose();
    _apiClient.close();
    super.dispose();
  }

  bool get _isIphoAdmin {
    final String role = context.read<AuthProvider>().user?.role ?? '';
    return role == 'ipho_admin';
  }

  bool get _hasSelectedBarangay {
    return _selectedBarangayId != null &&
        _selectedBarangayId!.trim().isNotEmpty;
  }

  bool get _hasSelectedRhu {
    return _selectedRhuId != null && _selectedRhuId!.trim().isNotEmpty;
  }

  List<_RhuOption> get _visibleRhus {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? assignedRhuId = authProvider.user?.rhuId;

    if (_isIphoAdmin) {
      return _rhus;
    }

    if (assignedRhuId == null || assignedRhuId.trim().isEmpty) {
      return _rhus;
    }

    final List<_RhuOption> assignedOnly = _rhus.where(
      (_RhuOption rhu) {
        return rhu.id == assignedRhuId;
      },
    ).toList();

    if (assignedOnly.isNotEmpty) {
      return assignedOnly;
    }

    return <_RhuOption>[
      _RhuOption(
        id: assignedRhuId,
        name: authProvider.assignedLocation,
      ),
    ];
  }

  List<_BarangayOption> get _barangaysForSelectedRhu {
    if (!_hasSelectedRhu) {
      return <_BarangayOption>[];
    }

    final List<_BarangayOption> filtered = _barangays.where(
      (_BarangayOption barangay) {
        return barangay.rhuId == _selectedRhuId;
      },
    ).toList();

    filtered.sort(
      (_BarangayOption a, _BarangayOption b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      },
    );

    return filtered;
  }

  int get _totalStock {
    return _visibleMedicines.fold<int>(
      0,
      (int sum, MedicineModel item) => sum + item.currentStock,
    );
  }

  int get _alertCount {
    return _visibleMedicines.where((MedicineModel item) {
      return item.isLowStock || item.isOutOfStock || item.isExpired;
    }).length;
  }

  Future<Box<dynamic>> _openLocationCacheBox() async {
    if (Hive.isBoxOpen(_locationCacheBoxName)) {
      return Hive.box<dynamic>(_locationCacheBoxName);
    }

    return Hive.openBox<dynamic>(_locationCacheBoxName);
  }

  String _locationCacheKey(AuthProvider authProvider) {
    final String role = authProvider.user?.role ?? 'user';
    final String rhuId = authProvider.user?.rhuId ?? 'all-rhus';

    return 'medicine_monitor_locations_${role}_$rhuId';
  }

  Future<void> _saveLocationOptionsToCache({
    required List<_RhuOption> rhus,
    required List<_BarangayOption> barangays,
  }) async {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final Box<dynamic> box = await _openLocationCacheBox();

    await box.put(
      _locationCacheKey(authProvider),
      <String, dynamic>{
        'savedAt': DateTime.now().toIso8601String(),
        'rhus': rhus.map((_RhuOption item) => item.toJson()).toList(),
        'barangays':
            barangays.map((_BarangayOption item) => item.toJson()).toList(),
      },
    );
  }

  Future<bool> _loadLocationOptionsFromCache() async {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final Box<dynamic> box = await _openLocationCacheBox();

    final dynamic cachedValue = box.get(_locationCacheKey(authProvider));

    if (cachedValue is! Map) {
      return false;
    }

    final dynamic rawRhus = cachedValue['rhus'];
    final dynamic rawBarangays = cachedValue['barangays'];

    if (rawRhus is! List || rawBarangays is! List) {
      return false;
    }

    final List<_RhuOption> rhus = rawRhus
        .whereType<Map>()
        .map((Map item) {
          return _RhuOption.fromJson(Map<String, dynamic>.from(item));
        })
        .where((_RhuOption rhu) => rhu.id.trim().isNotEmpty)
        .toList();

    final List<_BarangayOption> barangays = rawBarangays
        .whereType<Map>()
        .map((Map item) {
          return _BarangayOption.fromJson(Map<String, dynamic>.from(item));
        })
        .where((_BarangayOption barangay) {
          return barangay.id.trim().isNotEmpty &&
              barangay.rhuId.trim().isNotEmpty;
        })
        .toList();

    if (rhus.isEmpty && barangays.isEmpty) {
      return false;
    }

    String? selectedRhuId = _selectedRhuId;
    final String? assignedRhuId = authProvider.user?.rhuId;

    if (!_isIphoAdmin &&
        assignedRhuId != null &&
        assignedRhuId.trim().isNotEmpty) {
      selectedRhuId = assignedRhuId;
    }

    String? selectedBarangayId = _selectedBarangayId;

    final bool selectedBarangayStillExists = barangays.any(
      (_BarangayOption barangay) {
        return barangay.id == selectedBarangayId &&
            barangay.rhuId == selectedRhuId;
      },
    );

    if (!selectedBarangayStillExists) {
      selectedBarangayId = null;
    }

    if (!mounted) {
      return true;
    }

    setState(() {
      _rhus = rhus;
      _barangays = barangays;
      _selectedRhuId = selectedRhuId;
      _selectedBarangayId = selectedBarangayId;
    });

    return true;
  }

  Future<void> _loadLocationOptions() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingLocations = true;
      _errorMessage = null;
    });

    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? assignedRhuId = authProvider.user?.rhuId;

    String? selectedRhuId = _selectedRhuId;

    if (!_isIphoAdmin &&
        assignedRhuId != null &&
        assignedRhuId.trim().isNotEmpty) {
      selectedRhuId = assignedRhuId;
    }

    try {
      final List<dynamic> rawRhus = _extractList(
        await _apiClient.get(
          '/api/rhus',
          requiresAuth: true,
        ),
      );

      final List<_RhuOption> rhus = rawRhus
          .whereType<Map>()
          .map((Map item) {
            return _RhuOption.fromJson(Map<String, dynamic>.from(item));
          })
          .where((_RhuOption rhu) => rhu.id.trim().isNotEmpty)
          .toList();

      final List<dynamic> rawBarangays =
          await _loadRawBarangaysForRhu(selectedRhuId);

      List<_BarangayOption> barangays = rawBarangays
          .whereType<Map>()
          .map((Map item) {
            return _BarangayOption.fromJson(Map<String, dynamic>.from(item));
          })
          .where((_BarangayOption barangay) {
            return barangay.id.trim().isNotEmpty &&
                barangay.rhuId.trim().isNotEmpty;
          })
          .toList();

      if (selectedRhuId != null && selectedRhuId.trim().isNotEmpty) {
        final List<_BarangayOption> barangaysFromMedicineRecords =
            await _loadBarangaysFromMedicineRecords(selectedRhuId);

        barangays = _mergeBarangays(
          barangays,
          barangaysFromMedicineRecords,
        );
      }

      String? selectedBarangayId = _selectedBarangayId;

      final bool selectedBarangayStillExists = barangays.any(
        (_BarangayOption barangay) {
          return barangay.id == selectedBarangayId &&
              barangay.rhuId == selectedRhuId;
        },
      );

      if (!selectedBarangayStillExists) {
        selectedBarangayId = null;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _rhus = rhus;
        _barangays = barangays;
        _selectedRhuId = selectedRhuId;
        _selectedBarangayId = selectedBarangayId;
      });

      await _saveLocationOptionsToCache(
        rhus: rhus,
        barangays: barangays,
      );
    } on ApiException catch (error) {
      final bool loadedFromCache = await _loadLocationOptionsFromCache();

      if (!mounted) {
        return;
      }

      if (!loadedFromCache) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } catch (_) {
      final bool loadedFromCache = await _loadLocationOptionsFromCache();

      if (!mounted) {
        return;
      }

      if (!loadedFromCache) {
        setState(() {
          _errorMessage = 'Unable to load RHU and barangay filters.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocations = false;
        });
      }
    }
  }

  Future<List<dynamic>> _loadRawBarangaysForRhu(String? rhuId) async {
    final Map<String, dynamic> response = await _apiClient.get(
      '/api/barangays',
      requiresAuth: true,
      queryParameters: <String, dynamic>{
        'rhu': rhuId,
        'rhuId': rhuId,
        'viewScope': 'rhu',
      },
    );

    return _extractList(response);
  }

  Future<List<_BarangayOption>> _loadBarangaysFromMedicineRecords(
    String rhuId,
  ) async {
    try {
      final List<dynamic> rawMedicines = _extractList(
        await _apiClient.get(
          '/api/medicines',
          requiresAuth: true,
          queryParameters: <String, dynamic>{
            'rhu': rhuId,
            'viewScope': 'rhu',
            'page': 1,
            'limit': 500,
          },
        ),
      );

      return rawMedicines
          .whereType<Map>()
          .map((Map item) {
            return _BarangayOption.fromMedicineJson(
              Map<String, dynamic>.from(item),
              fallbackRhuId: rhuId,
            );
          })
          .where((_BarangayOption barangay) {
            return barangay.id.trim().isNotEmpty &&
                barangay.name.trim().isNotEmpty &&
                barangay.rhuId.trim().isNotEmpty;
          })
          .toList();
    } catch (_) {
      return <_BarangayOption>[];
    }
  }

  List<_BarangayOption> _mergeBarangays(
    List<_BarangayOption> first,
    List<_BarangayOption> second,
  ) {
    final Map<String, _BarangayOption> byId = <String, _BarangayOption>{};

    for (final _BarangayOption barangay in first) {
      byId[barangay.id] = barangay;
    }

    for (final _BarangayOption barangay in second) {
      byId[barangay.id] = barangay;
    }

    return byId.values.toList();
  }

  List<dynamic> _extractList(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final dynamic medicines = data['medicines'];
      final dynamic rhus = data['rhus'];
      final dynamic barangays = data['barangays'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (medicines is List) {
        return medicines;
      }

      if (rhus is List) {
        return rhus;
      }

      if (barangays is List) {
        return barangays;
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

    final dynamic medicines = response['medicines'];
    final dynamic rhus = response['rhus'];
    final dynamic barangays = response['barangays'];

    if (medicines is List) {
      return medicines;
    }

    if (rhus is List) {
      return rhus;
    }

    if (barangays is List) {
      return barangays;
    }

    return <dynamic>[];
  }

  void _handleSearchTextState() {
    final bool hasText = _searchController.text.trim().isNotEmpty;

    if (_hasSearchText == hasText) {
      return;
    }

    setState(() {
      _hasSearchText = hasText;
    });
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _hasSearchText = value.trim().isNotEmpty;
    });

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_hasSelectedBarangay) {
        _loadMedicines();
      }
    });
  }

  Future<void> _loadMedicines() async {
    if (_isLoading) {
      return;
    }

    if (!_hasSelectedRhu || !_hasSelectedBarangay) {
      setState(() {
        _medicines = <MedicineModel>[];
        _errorMessage = null;
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<MedicineModel> result =
          await _medicineRepository.getMedicines(
        search: _searchController.text,
        stockStatus: _selectedStockStatus,
        rhuId: _selectedRhuId,
        barangayId: _selectedBarangayId,
        viewScope: 'rhu',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _medicines = result;
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
        _errorMessage = 'Unable to load medicine monitor records.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadLocationOptions();

    if (!mounted) {
      return;
    }

    if (_hasSelectedBarangay) {
      await _loadMedicines();
      return;
    }

    setState(() {
      _medicines = <MedicineModel>[];
    });
  }

  Future<void> _setRhuFilter(String? value) async {
    setState(() {
      _selectedRhuId = value;
      _selectedBarangayId = null;
      _medicines = <MedicineModel>[];
      _errorMessage = null;
    });

    await _loadLocationOptions();
  }

  Future<void> _setBarangayFilter(String? value) async {
    setState(() {
      _selectedBarangayId = value;
      _medicines = <MedicineModel>[];
      _errorMessage = null;
    });

    if (value != null && value.trim().isNotEmpty) {
      await _loadMedicines();
    }
  }

  Future<void> _setStockStatusFilter(String? value) async {
    setState(() {
      _selectedStockStatus = value;
    });

    if (_hasSelectedBarangay) {
      await _loadMedicines();
    }
  }

  Future<void> _clearFilters() async {
    final AuthProvider authProvider = context.read<AuthProvider>();

    _searchController.clear();

    setState(() {
      _selectedStockStatus = null;
      _selectedBarangayId = null;
      _medicines = <MedicineModel>[];
      _errorMessage = null;

      if (_isIphoAdmin) {
        _selectedRhuId = null;
      } else {
        _selectedRhuId = authProvider.user?.rhuId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();
    final List<MedicineModel> visibleMedicines = _visibleMedicines;

    final bool shouldSelectRhu = _isIphoAdmin && !_hasSelectedRhu;
    final bool shouldSelectBarangay = _hasSelectedRhu && !_hasSelectedBarangay;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medicine Monitor',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _handleRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _MonitorHeader(
                assignedLocation: authProvider.assignedLocation,
                itemCount: visibleMedicines.length,
                totalStock: _totalStock,
                alertCount: _alertCount,
              ),
              const SizedBox(height: 18),
              _LocationFilterCard(
                isLoading: _isLoadingLocations,
                isIphoAdmin: _isIphoAdmin,
                selectedRhuId: _selectedRhuId,
                selectedBarangayId: _selectedBarangayId,
                rhus: _visibleRhus,
                barangays: _barangaysForSelectedRhu,
                onRhuChanged: _setRhuFilter,
                onBarangayChanged: _setBarangayFilter,
              ),
              const SizedBox(height: 14),
              _SearchAndFilterBar(
                controller: _searchController,
                isEnabled: _hasSelectedBarangay,
                hasSearchText: _hasSearchText,
                selectedStatus: _selectedStockStatus,
                onChanged: _handleSearchChanged,
                onStatusChanged: _setStockStatusFilter,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              const _ReadOnlyNotice(),
              const SizedBox(height: 18),
              if (shouldSelectRhu)
                const _SelectMonitorLocationState(
                  title: 'Select an RHU first',
                  message:
                      'Choose an RHU, then choose a barangay to view medicine availability.',
                )
              else if (shouldSelectBarangay)
                const _SelectMonitorLocationState(
                  title: 'Select a barangay first',
                  message:
                      'Medicine records will appear only after you choose a specific barangay.',
                )
              else if (_errorMessage != null)
                _ErrorCard(
                  message: _errorMessage!,
                  onRetry: _handleRefresh,
                )
              else if (_isLoading)
                const _MedicineLoadingList()
              else if (visibleMedicines.isEmpty)
                _EmptyMedicineState(
                  hasSearchText: _hasSearchText,
                )
              else
                ...visibleMedicines.map(
                  (MedicineModel medicine) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MedicineMonitorCard(
                        medicine: medicine,
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

class _MonitorHeader extends StatelessWidget {
  const _MonitorHeader({
    required this.assignedLocation,
    required this.itemCount,
    required this.totalStock,
    required this.alertCount,
  });

  final String assignedLocation;
  final int itemCount;
  final int totalStock;
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.18),
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
                Icons.monitor_heart_rounded,
                color: Colors.white,
                size: 30,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'RHU Medicine Monitor',
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
          Text(
            assignedLocation,
            style: const TextStyle(
              color: Color(0xFFDBEAFE),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a barangay first, then check medicine availability. This screen is read-only.',
            style: TextStyle(
              color: Color(0xFFDBEAFE),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Items',
                  value: itemCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Total Stock',
                  value: totalStock.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Alerts',
                  value: alertCount.toString(),
                ),
              ),
            ],
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
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDBEAFE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationFilterCard extends StatelessWidget {
  const _LocationFilterCard({
    required this.isLoading,
    required this.isIphoAdmin,
    required this.selectedRhuId,
    required this.selectedBarangayId,
    required this.rhus,
    required this.barangays,
    required this.onRhuChanged,
    required this.onBarangayChanged,
  });

  final bool isLoading;
  final bool isIphoAdmin;
  final String? selectedRhuId;
  final String? selectedBarangayId;
  final List<_RhuOption> rhus;
  final List<_BarangayOption> barangays;
  final ValueChanged<String?> onRhuChanged;
  final ValueChanged<String?> onBarangayChanged;

  @override
  Widget build(BuildContext context) {
    final bool selectedRhuValid = selectedRhuId == null ||
        rhus.any((_RhuOption rhu) => rhu.id == selectedRhuId);

    final bool selectedBarangayValid = selectedBarangayId == null ||
        barangays.any((_BarangayOption barangay) {
          return barangay.id == selectedBarangayId;
        });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Monitor Location',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedRhuValid ? selectedRhuId : null,
              hint: const Text('Select RHU'),
              decoration: const InputDecoration(
                labelText: 'RHU',
                prefixIcon: Icon(Icons.local_hospital_rounded),
              ),
              items: rhus.map(
                (_RhuOption rhu) {
                  return DropdownMenuItem<String>(
                    value: rhu.id,
                    child: Text(
                      rhu.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ).toList(),
              onChanged: isIphoAdmin ? onRhuChanged : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedBarangayValid ? selectedBarangayId : null,
              hint: const Text('Select barangay'),
              decoration: const InputDecoration(
                labelText: 'Barangay',
                prefixIcon: Icon(Icons.location_city_rounded),
              ),
              items: barangays.map(
                (_BarangayOption barangay) {
                  return DropdownMenuItem<String>(
                    value: barangay.id,
                    child: Text(
                      barangay.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  selectedRhuId == null || barangays.isEmpty ? null : onBarangayChanged,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                barangays.isEmpty && selectedRhuId != null
                    ? 'No barangay options loaded yet. Pull to refresh when online.'
                    : 'Select one barangay to view medicine records.',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.controller,
    required this.isEnabled,
    required this.hasSearchText,
    required this.selectedStatus,
    required this.onChanged,
    required this.onStatusChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool isEnabled;
  final bool hasSearchText;
  final String? selectedStatus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String?> onStatusChanged;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          controller: controller,
          enabled: isEnabled,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: 'Search medicine',
            hintText: isEnabled
                ? 'Search by name, batch, category...'
                : 'Select a barangay first',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: hasSearchText
                ? IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: selectedStatus ?? 'all',
          decoration: const InputDecoration(
            labelText: 'Stock status',
            prefixIcon: Icon(Icons.filter_list_rounded),
          ),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: 'all',
              child: Text('All statuses'),
            ),
            DropdownMenuItem<String>(
              value: 'in_stock',
              child: Text('In Stock'),
            ),
            DropdownMenuItem<String>(
              value: 'low_stock',
              child: Text('Low Stock'),
            ),
            DropdownMenuItem<String>(
              value: 'out_of_stock',
              child: Text('Out of Stock'),
            ),
            DropdownMenuItem<String>(
              value: 'expired',
              child: Text('Expired'),
            ),
          ],
          onChanged: !isEnabled
              ? null
              : (String? value) {
                  if (value == null || value == 'all') {
                    onStatusChanged(null);
                    return;
                  }

                  onStatusChanged(value);
                },
        ),
      ],
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFBFDBFE),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.visibility_rounded,
            color: Color(0xFF2563EB),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Read-only monitor. You can check availability, but you cannot add, edit, or delete medicine records here.',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectMonitorLocationState extends StatelessWidget {
  const _SelectMonitorLocationState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

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
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.location_searching_rounded,
                color: Color(0xFF2563EB),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineMonitorCard extends StatelessWidget {
  const _MedicineMonitorCard({
    required this.medicine,
  });

  final MedicineModel medicine;

  Color get _statusColor {
    if (medicine.isExpired || medicine.isOutOfStock) {
      return const Color(0xFFDC2626);
    }

    if (medicine.isLowStock) {
      return const Color(0xFFF59E0B);
    }

    return const Color(0xFF16A34A);
  }

  Color get _statusBackground {
    if (medicine.isExpired || medicine.isOutOfStock) {
      return const Color(0xFFFEF2F2);
    }

    if (medicine.isLowStock) {
      return const Color(0xFFFFFBEB);
    }

    return const Color(0xFFDCFCE7);
  }

  @override
  Widget build(BuildContext context) {
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
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        medicine.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicine.category.trim().isEmpty
                            ? 'No category'
                            : medicine.category,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(
                  label: medicine.stockStatusLabel,
                  foreground: _statusColor,
                  background: _statusBackground,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: medicine.stockPercentage,
                backgroundColor: const Color(0xFFE5E7EB),
                color: _statusColor,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MedicineInfo(
                    label: 'Current Stock',
                    value: '${medicine.currentStock} ${medicine.unit}',
                  ),
                ),
                Expanded(
                  child: _MedicineInfo(
                    label: 'Minimum',
                    value: '${medicine.minimumStockLevel} ${medicine.unit}',
                  ),
                ),
                Expanded(
                  child: _MedicineInfo(
                    label: 'Batch',
                    value: medicine.batchNumber.trim().isEmpty
                        ? 'N/A'
                        : medicine.batchNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    medicine.locationName,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MedicineInfo extends StatelessWidget {
  const _MedicineInfo({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w800,
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
              'Unable to load monitor records',
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

class _EmptyMedicineState extends StatelessWidget {
  const _EmptyMedicineState({
    this.hasSearchText = false,
  });

  final bool hasSearchText;

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
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.monitor_heart_outlined,
                color: Color(0xFF2563EB),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearchText
                  ? 'No matching medicine found'
                  : 'No medicine records found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearchText
                  ? 'Try another medicine name, batch number, category, or clear the search field.'
                  : 'This barangay has no matching medicine records, or the selected filter has no result.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineLoadingList extends StatelessWidget {
  const _MedicineLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        4,
        (int index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text('Loading medicine monitor records...'),
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

class _RhuOption {
  const _RhuOption({
    required this.id,
    required this.name,
  });

  factory _RhuOption.fromJson(Map<String, dynamic> json) {
    return _RhuOption(
      id: _readString(
        json,
        <String>[
          '_id',
          'id',
        ],
      ),
      name: _readString(
        json,
        <String>[
          'name',
          'rhuName',
          'officeName',
        ],
      ),
    );
  }

  final String id;
  final String name;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
    };
  }
}

class _BarangayOption {
  const _BarangayOption({
    required this.id,
    required this.name,
    required this.rhuId,
  });

  factory _BarangayOption.fromJson(Map<String, dynamic> json) {
    return _BarangayOption(
      id: _readString(
        json,
        <String>[
          '_id',
          'id',
        ],
      ),
      name: _readString(
        json,
        <String>[
          'name',
          'barangayName',
        ],
      ),
      rhuId: _readRelationIdFromKeys(
        json,
        <String>[
          'rhu',
          'rhuId',
          'assignedRhu',
          'assignedRhuId',
        ],
      ),
    );
  }

  factory _BarangayOption.fromMedicineJson(
    Map<String, dynamic> json, {
    required String fallbackRhuId,
  }) {
    final dynamic barangayValue = json['barangay'];

    String id = '';
    String name = '';

    if (barangayValue is Map<String, dynamic>) {
      id = _readString(
        barangayValue,
        <String>[
          '_id',
          'id',
        ],
      );

      name = _readString(
        barangayValue,
        <String>[
          'name',
          'barangayName',
        ],
      );
    } else {
      id = _readRelationIdFromKeys(
        json,
        <String>[
          'barangay',
          'barangayId',
          'assignedBarangay',
          'assignedBarangayId',
        ],
      );

      name = _readString(
        json,
        <String>[
          'barangayName',
          'assignedBarangayName',
          'locationName',
        ],
      );
    }

    final String rhuId = _readRelationIdFromKeys(
      json,
      <String>[
        'rhu',
        'rhuId',
        'assignedRhu',
        'assignedRhuId',
      ],
    );

    return _BarangayOption(
      id: id,
      name: name.isEmpty ? id : name,
      rhuId: rhuId.isEmpty ? fallbackRhuId : rhuId,
    );
  }

  final String id;
  final String name;
  final String rhuId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'rhuId': rhuId,
    };
  }
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    final String text = value.toString().trim();

    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }

  return '';
}

String _readRelationIdFromKeys(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final String key in keys) {
    final dynamic value = json[key];
    final String id = _readRelationId(value);

    if (id.trim().isNotEmpty) {
      return id;
    }
  }

  return '';
}

String _readRelationId(dynamic value) {
  if (value == null) {
    return '';
  }

  if (value is String) {
    return value.trim();
  }

  if (value is Map<String, dynamic>) {
    return _readString(
      value,
      <String>[
        '_id',
        'id',
      ],
    );
  }

  return value.toString().trim();
}