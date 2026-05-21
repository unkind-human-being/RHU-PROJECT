import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class PrescriptionClaimMonitorScreen extends StatefulWidget {
  const PrescriptionClaimMonitorScreen({super.key});

  static const String routeName = '/prescription-claim-monitor';

  @override
  State<PrescriptionClaimMonitorScreen> createState() =>
      _PrescriptionClaimMonitorScreenState();
}

class _PrescriptionClaimMonitorScreenState
    extends State<PrescriptionClaimMonitorScreen> {
  late final ApiClient _apiClient;

  bool _isLoading = false;
  String? _errorMessage;

  String _selectedStatus = 'all';
  String _searchText = '';

  List<Map<String, dynamic>> _prescriptions = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrescriptions();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPrescriptions {
    final String query = _searchText.trim().toLowerCase();

    return _prescriptions.where((Map<String, dynamic> prescription) {
      final String status = _readString(prescription, <String>['status']);

      final bool matchesStatus =
          _selectedStatus == 'all' || status == _selectedStatus;

      final bool matchesSearch = query.isEmpty ||
          _patientName(prescription).toLowerCase().contains(query) ||
          _readString(prescription, <String>['diagnosis'])
              .toLowerCase()
              .contains(query) ||
          _readString(prescription, <String>['doctorName'])
              .toLowerCase()
              .contains(query) ||
          _readString(prescription, <String>['pharmacyName'])
              .toLowerCase()
              .contains(query) ||
          _readString(prescription, <String>['pharmacyLocation'])
              .toLowerCase()
              .contains(query) ||
          _readString(prescription, <String>['contactNumber'])
              .toLowerCase()
              .contains(query) ||
          _medicineSummary(prescription).toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> _loadPrescriptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/prescriptions',
        requiresAuth: true,
        queryParameters: <String, dynamic>{
          'limit': 100,
        },
      );

      final List<dynamic> rawPrescriptions = _extractList(response);

      final List<Map<String, dynamic>> prescriptions = rawPrescriptions
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      prescriptions.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime bDate = _readDateTime(
          b,
          <String>['claimedAt', 'issuedAt', 'createdAt'],
        );
        final DateTime aDate = _readDateTime(
          a,
          <String>['claimedAt', 'issuedAt', 'createdAt'],
        );

        return bDate.compareTo(aDate);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _prescriptions = prescriptions;
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
        _errorMessage = 'Unable to load prescription claim records.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
      final dynamic prescriptions = data['prescriptions'];
      final dynamic records = data['records'];
      final dynamic results = data['results'];
      final dynamic docs = data['docs'];
      final dynamic items = data['items'];

      if (prescriptions is List) return prescriptions;
      if (records is List) return records;
      if (results is List) return results;
      if (docs is List) return docs;
      if (items is List) return items;
    }

    final dynamic prescriptions = response['prescriptions'];

    if (prescriptions is List) {
      return prescriptions;
    }

    return <dynamic>[];
  }

  int _countByStatus(String status) {
    return _prescriptions.where((Map<String, dynamic> prescription) {
      return _readString(prescription, <String>['status']) == status;
    }).length;
  }

  int get _issuedCount {
    return _countByStatus('issued');
  }

  int get _claimedCount {
    return _countByStatus('claimed');
  }

  int get _expiredCount {
    return _countByStatus('expired');
  }

  int get _cancelledCount {
    return _countByStatus('cancelled');
  }

  void _setStatusFilter(String status) {
    setState(() {
      _selectedStatus = status;
    });
  }

  void _showPrescriptionDetails(Map<String, dynamic> prescription) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _PrescriptionDetailsSheet(
          prescription: prescription,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filteredPrescriptions =
        _filteredPrescriptions;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF9),
      appBar: AppBar(
        title: const Text(
          'Prescription Claims',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadPrescriptions,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPrescriptions,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _HeaderCard(
                    total: _prescriptions.length,
                    issued: _issuedCount,
                    claimed: _claimedCount,
                    expired: _expiredCount,
                    cancelled: _cancelledCount,
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
              SliverPersistentHeader(
                pinned: true,
                delegate: _StatusFilterHeaderDelegate(
                  selectedStatus: _selectedStatus,
                  onChanged: _setStatusFilter,
                ),
              ),
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _ErrorCard(
                      message: _errorMessage!,
                      onRetry: _loadPrescriptions,
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
              else if (filteredPrescriptions.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyState(),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: filteredPrescriptions.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> prescription =
                        filteredPrescriptions[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: index == 0 ? 12 : 0,
                        bottom: 12,
                      ),
                      child: _PrescriptionCard(
                        prescription: prescription,
                        onTap: () {
                          _showPrescriptionDetails(prescription);
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
    required this.total,
    required this.issued,
    required this.claimed,
    required this.expired,
    required this.cancelled,
  });

  final int total;
  final int issued;
  final int claimed;
  final int expired;
  final int cancelled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF16A34A),
            Color(0xFF15803D),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Prescription Claim Tracking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'RHU Admin monitoring',
                      style: TextStyle(
                        color: Color(0xFFDCFCE7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Track prescription QR codes sent to patients, verify which ones were claimed, and review pharmacy claim details.',
            style: TextStyle(
              color: Color(0xFFDCFCE7),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Total',
                  value: total.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Issued',
                  value: issued.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Claimed',
                  value: claimed.toString(),
                ),
              ),
            ],
          ),
          if (expired > 0 || cancelled > 0) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _HeaderMetric(
                    label: 'Expired',
                    value: expired.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeaderMetric(
                    label: 'Cancelled',
                    value: cancelled.toString(),
                  ),
                ),
              ],
            ),
          ],
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFDCFCE7),
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
        hintText: 'Search patient, medicine, diagnosis, pharmacy...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
    );
  }
}

class _StatusFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StatusFilterHeaderDelegate({
    required this.selectedStatus,
    required this.onChanged,
  });

  final String selectedStatus;
  final ValueChanged<String> onChanged;

  @override
  double get minExtent => 74;

  @override
  double get maxExtent => 74;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF6FAF9),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _FilterChipButton(
            label: 'All',
            value: 'all',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Issued',
            value: 'issued',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Claimed',
            value: 'claimed',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Expired',
            value: 'expired',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
          _FilterChipButton(
            label: 'Cancelled',
            value: 'cancelled',
            selectedValue: selectedStatus,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StatusFilterHeaderDelegate oldDelegate) {
    return oldDelegate.selectedStatus != selectedStatus;
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool selected = value == selectedValue;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        selectedColor: const Color(0xFF16A34A),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF166534),
          fontWeight: FontWeight.w900,
        ),
        side: BorderSide(
          color: selected ? const Color(0xFF16A34A) : const Color(0xFFBBF7D0),
        ),
        onSelected: (_) {
          onChanged(value);
        },
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.prescription,
    required this.onTap,
  });

  final Map<String, dynamic> prescription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String status = _readString(prescription, <String>['status']);
    final bool isClaimed = status == 'claimed';
    final bool isIssued = status == 'issued';
    final List<dynamic> medicines = _medicineList(prescription);
    final Color accentColor = _statusColor(status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.18),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(
                      isClaimed
                          ? Icons.check_circle_rounded
                          : isIssued
                              ? Icons.qr_code_2_rounded
                              : Icons.medication_rounded,
                      color: accentColor,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _patientName(prescription),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${medicines.length} medicine item(s) • ${_formatDateTimeText(_readString(prescription, <String>['issuedAt', 'createdAt']))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 14),
              _InfoLine(
                label: 'Medicine',
                value: _medicineSummary(prescription),
              ),
              _InfoLine(
                label: 'Diagnosis',
                value: _fallback(
                  _readString(prescription, <String>['diagnosis']),
                ),
              ),
              _InfoLine(
                label: 'Doctor',
                value: _fallback(
                  _readString(prescription, <String>['doctorName']),
                ),
              ),
              _InfoLine(
                label: 'Claimed',
                value: isClaimed
                    ? _formatDateTimeText(
                        _readString(prescription, <String>['claimedAt']),
                      )
                    : 'Not yet claimed',
              ),
              if (isClaimed)
                _InfoLine(
                  label: 'Pharmacy',
                  value: _fallback(
                    _readString(prescription, <String>['pharmacyName']),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('View Tracking Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrescriptionDetailsSheet extends StatelessWidget {
  const _PrescriptionDetailsSheet({
    required this.prescription,
  });

  final Map<String, dynamic> prescription;

  @override
  Widget build(BuildContext context) {
    final String status = _readString(prescription, <String>['status']);
    final String qrPayload = _readString(
      prescription,
      <String>['qrPayload', 'prescriptionQrPayload'],
    );

    final List<dynamic> medicines = _medicineList(prescription);
    final Color accentColor = _statusColor(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.96,
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
              _DetailsHero(
                prescription: prescription,
                accentColor: accentColor,
              ),
              const SizedBox(height: 16),
              _ClaimStatusNotice(
                status: status,
              ),
              const SizedBox(height: 16),
              _DetailsSection(
                title: 'Patient & Prescription',
                icon: Icons.assignment_ind_rounded,
                color: const Color(0xFF0EA5E9),
                children: <Widget>[
                  _InfoLine(
                    label: 'Patient',
                    value: _patientName(prescription),
                  ),
                  _InfoLine(
                    label: 'Contact',
                    value: _fallback(
                      _readString(prescription, <String>['contactNumber']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Diagnosis',
                    value: _fallback(
                      _readString(prescription, <String>['diagnosis']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Doctor',
                    value: _fallback(
                      _readString(prescription, <String>['doctorName']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Issued',
                    value: _formatDateTimeText(
                      _readString(
                        prescription,
                        <String>['issuedAt', 'createdAt'],
                      ),
                    ),
                  ),
                  _InfoLine(
                    label: 'Expires',
                    value: _formatDateTimeText(
                      _readString(prescription, <String>['expiresAt']),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsSection(
                title: 'Claim Information',
                icon: Icons.local_pharmacy_rounded,
                color: const Color(0xFF16A34A),
                children: <Widget>[
                  _InfoLine(
                    label: 'Claimed At',
                    value: _formatDateTimeText(
                      _readString(prescription, <String>['claimedAt']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Pharmacy',
                    value: _fallback(
                      _readString(prescription, <String>['pharmacyName']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Location',
                    value: _fallback(
                      _readString(prescription, <String>['pharmacyLocation']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Remarks',
                    value: _fallback(
                      _readString(prescription, <String>['claimRemarks']),
                    ),
                  ),
                  _InfoLine(
                    label: 'Claimed By',
                    value: _personLabel(prescription['claimedBy']),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsSection(
                title: 'Medicine Items',
                icon: Icons.medication_liquid_rounded,
                color: const Color(0xFF7C3AED),
                children: <Widget>[
                  if (medicines.isEmpty)
                    const Text(
                      'No medicine items found.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    ...medicines.map((dynamic rawMedicine) {
                      if (rawMedicine is! Map<String, dynamic>) {
                        return const SizedBox.shrink();
                      }

                      return _MedicineItemBox(
                        medicine: rawMedicine,
                      );
                    }),
                ],
              ),
              if (qrPayload.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _QrPayloadBox(
                  qrPayload: qrPayload,
                  qrToken: _readString(prescription, <String>['qrToken']),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                ),
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

class _DetailsHero extends StatelessWidget {
  const _DetailsHero({
    required this.prescription,
    required this.accentColor,
  });

  final Map<String, dynamic> prescription;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final String status = _readString(prescription, <String>['status']);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Icon(
              status == 'claimed'
                  ? Icons.fact_check_rounded
                  : Icons.qr_code_2_rounded,
              color: accentColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _patientName(prescription),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _medicineSummary(prescription),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(status: status),
        ],
      ),
    );
  }
}

class _ClaimStatusNotice extends StatelessWidget {
  const _ClaimStatusNotice({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final String message;
    final Color color;
    final IconData icon;

    if (status == 'issued') {
      message =
          'This prescription QR has been issued to the patient but has not yet been claimed by the pharmacy.';
      color = const Color(0xFFF59E0B);
      icon = Icons.qr_code_2_rounded;
    } else if (status == 'claimed') {
      message =
          'This prescription QR has been claimed. Pharmacy details are shown below.';
      color = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
    } else if (status == 'expired') {
      message = 'This prescription QR has expired and can no longer be claimed.';
      color = const Color(0xFFDC2626);
      icon = Icons.timer_off_rounded;
    } else if (status == 'cancelled') {
      message = 'This prescription QR was cancelled by the RHU.';
      color = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
    } else {
      message = 'Prescription status: ${_prettyEnum(status)}.';
      color = const Color(0xFF64748B);
      icon = Icons.info_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _MedicineItemBox extends StatelessWidget {
  const _MedicineItemBox({
    required this.medicine,
  });

  final Map<String, dynamic> medicine;

  @override
  Widget build(BuildContext context) {
    final String medicineName = _readString(
      medicine,
      <String>['medicineName', 'name'],
    );
    final String genericName = _readString(
      medicine,
      <String>['genericName'],
    );
    final String strength = _readString(
      medicine,
      <String>['strength'],
    );
    final String dosageForm = _readString(
      medicine,
      <String>['dosageForm'],
    );
    final String quantity = _readString(
      medicine,
      <String>['quantity'],
    );
    final String unit = _readString(
      medicine,
      <String>['unit'],
    );
    final String instructions = _readString(
      medicine,
      <String>['instructions'],
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _fallback(medicineName),
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (genericName.trim().isNotEmpty ||
              strength.trim().isNotEmpty ||
              dosageForm.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              <String>[
                genericName,
                strength,
                dosageForm,
              ].where((String item) => item.trim().isNotEmpty).join(' • '),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Qty: ${_fallback(quantity)} ${_fallback(unit)}',
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (instructions.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              instructions,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QrPayloadBox extends StatelessWidget {
  const _QrPayloadBox({
    required this.qrPayload,
    required this.qrToken,
  });

  final String qrPayload;
  final String qrToken;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'Prescription QR',
            style: TextStyle(
              color: Color(0xFF14532D),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This is the QR sent to the patient.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: QrImageView(
              data: qrPayload,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          if (qrToken.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            SelectableText(
              qrToken,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color foreground = _statusColor(status);
    final Color background = foreground.withValues(alpha: 0.12);

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
        _prettyEnum(status),
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w900,
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
            width: 110,
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
              child: Text('Loading prescription claim records...'),
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
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            _EmptyIcon(),
            SizedBox(height: 16),
            Text(
              'No prescription records found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Prescription QR records will appear here after RHU Admin sends prescriptions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyIcon extends StatelessWidget {
  const _EmptyIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Icon(
        Icons.medication_liquid_rounded,
        color: Color(0xFF16A34A),
        size: 38,
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
              'Unable to load records',
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

Color _statusColor(String status) {
  switch (status) {
    case 'claimed':
      return const Color(0xFF16A34A);
    case 'expired':
    case 'cancelled':
      return const Color(0xFFDC2626);
    case 'issued':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF64748B);
  }
}

List<dynamic> _medicineList(Map<String, dynamic> prescription) {
  final dynamic medicines = prescription['medicines'];

  if (medicines is List) {
    return medicines;
  }

  return <dynamic>[];
}

String _medicineSummary(Map<String, dynamic> prescription) {
  final List<dynamic> medicines = _medicineList(prescription);

  final List<String> names = medicines
      .whereType<Map<String, dynamic>>()
      .map((Map<String, dynamic> item) {
        return _readString(item, <String>['medicineName', 'name']);
      })
      .where((String item) => item.trim().isNotEmpty)
      .toList();

  if (names.isEmpty) {
    return 'No medicine listed';
  }

  if (names.length == 1) {
    return names.first;
  }

  return '${names.first} + ${names.length - 1} more';
}

String _patientName(Map<String, dynamic> prescription) {
  final String firstName = _readString(
    prescription,
    <String>['patientFirstName'],
  );

  final String middleInitial = _readString(
    prescription,
    <String>['patientMiddleInitial'],
  );

  final String lastName = _readString(
    prescription,
    <String>['patientLastName'],
  );

  final List<String> parts = <String>[
    firstName,
    middleInitial,
    lastName,
  ].where((String item) => item.trim().isNotEmpty).toList();

  if (parts.isEmpty) {
    final dynamic patientUser = prescription['patientUser'];

    if (patientUser is Map<String, dynamic>) {
      final String fullName = _readString(
        patientUser,
        <String>['fullName', 'email'],
      );

      if (fullName.trim().isNotEmpty) {
        return fullName;
      }
    }

    return 'Unknown patient';
  }

  return parts.join(' ');
}

String _personLabel(dynamic value) {
  if (value is Map<String, dynamic>) {
    return _fallback(
      _readString(
        value,
        <String>['fullName', 'name', 'email', '_id', 'id'],
      ),
    );
  }

  if (value == null) {
    return 'N/A';
  }

  return _fallback(value.toString());
}

String _prettyEnum(String value) {
  if (value.trim().isEmpty) {
    return 'N/A';
  }

  return value
      .split('_')
      .where((String item) => item.trim().isNotEmpty)
      .map((String item) {
    return item[0].toUpperCase() + item.substring(1);
  }).join(' ');
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
  List<String> keys,
) {
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

  return '';
}