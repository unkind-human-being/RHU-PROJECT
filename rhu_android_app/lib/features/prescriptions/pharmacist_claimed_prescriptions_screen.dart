import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class PharmacistClaimedPrescriptionsScreen extends StatefulWidget {
  const PharmacistClaimedPrescriptionsScreen({super.key});

  static const String routeName = '/pharmacist-claimed-prescriptions';

  @override
  State<PharmacistClaimedPrescriptionsScreen> createState() =>
      _PharmacistClaimedPrescriptionsScreenState();
}

class _PharmacistClaimedPrescriptionsScreenState
    extends State<PharmacistClaimedPrescriptionsScreen> {
  late final ApiClient _apiClient;

  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isClaiming = false;
  bool _isLoadingScannedPrescription = false;

  String? _errorMessage;

  List<Map<String, dynamic>> _claimedPrescriptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _pendingClaims = <Map<String, dynamic>>[];

  static const String _pendingClaimsKey = 'pending_prescription_claims_v1';

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecords(syncFirst: true);
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadRecords({
    bool syncFirst = false,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _pendingClaims = await _readPendingClaims();

      if (syncFirst && _pendingClaims.isNotEmpty) {
        await _syncPendingClaims(showMessage: false);
      }

      final Map<String, dynamic> response = await _apiClient.get(
        '/api/prescriptions',
        requiresAuth: true,
        queryParameters: <String, dynamic>{
          'status': 'claimed',
          'limit': 100,
        },
      );

      final List<dynamic> rawRecords = _extractList(response);

      final List<Map<String, dynamic>> claimedPrescriptions = rawRecords
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();

      final List<Map<String, dynamic>> pendingClaims =
          await _readPendingClaims();

      if (!mounted) {
        return;
      }

      setState(() {
        _claimedPrescriptions = claimedPrescriptions;
        _pendingClaims = pendingClaims;
      });
    } on ApiException catch (error) {
      final List<Map<String, dynamic>> pendingClaims =
          await _readPendingClaims();

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingClaims = pendingClaims;
        _errorMessage = error.message;
      });
    } catch (_) {
      final List<Map<String, dynamic>> pendingClaims =
          await _readPendingClaims();

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingClaims = pendingClaims;
        _errorMessage =
            'Unable to load claimed prescription records. Pending offline claims are still shown.';
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

  Map<String, dynamic> _extractMap(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      final dynamic prescription = data['prescription'];
      final dynamic record = data['record'];
      final dynamic result = data['result'];
      final dynamic item = data['item'];

      if (prescription is Map<String, dynamic>) {
        return Map<String, dynamic>.from(prescription);
      }

      if (record is Map<String, dynamic>) {
        return Map<String, dynamic>.from(record);
      }

      if (result is Map<String, dynamic>) {
        return Map<String, dynamic>.from(result);
      }

      if (item is Map<String, dynamic>) {
        return Map<String, dynamic>.from(item);
      }

      return Map<String, dynamic>.from(data);
    }

    final dynamic prescription = response['prescription'];
    final dynamic record = response['record'];
    final dynamic result = response['result'];
    final dynamic item = response['item'];

    if (prescription is Map<String, dynamic>) {
      return Map<String, dynamic>.from(prescription);
    }

    if (record is Map<String, dynamic>) {
      return Map<String, dynamic>.from(record);
    }

    if (result is Map<String, dynamic>) {
      return Map<String, dynamic>.from(result);
    }

    if (item is Map<String, dynamic>) {
      return Map<String, dynamic>.from(item);
    }

    return response;
  }

  bool _isOfflineError(Object error) {
    if (error is SocketException) {
      return true;
    }

    if (error is TimeoutException) {
      return true;
    }

    final String errorText = error.toString().toLowerCase();

    return errorText.contains('socketexception') ||
        errorText.contains('failed host lookup') ||
        errorText.contains('connection refused') ||
        errorText.contains('connection timed out') ||
        errorText.contains('network is unreachable') ||
        errorText.contains('networkerror') ||
        errorText.contains('clientexception') ||
        errorText.contains('xmlhttprequest error');
  }

  bool _isAlreadyClaimedError(Object error) {
    final String text = error.toString().toLowerCase();

    return text.contains('already claimed') ||
        text.contains('already been claimed') ||
        text.contains('prescription already claimed');
  }

  Future<List<Map<String, dynamic>>> _readPendingClaims() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String? rawText = preferences.getString(_pendingClaimsKey);

    if (rawText == null || rawText.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final dynamic decoded = jsonDecode(rawText);

      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _savePendingClaims(
    List<Map<String, dynamic>> pendingClaims,
  ) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _pendingClaimsKey,
      jsonEncode(pendingClaims),
    );
  }

  Future<Map<String, dynamic>> _sendClaimToServer(
    Map<String, dynamic> claimData,
  ) async {
    String prescriptionId = (claimData['prescriptionId'] ?? '').toString();
    final String token = (claimData['token'] ?? '').toString();

    if (prescriptionId.trim().isEmpty && token.trim().isNotEmpty) {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/prescriptions/qr/${Uri.encodeComponent(token)}',
        requiresAuth: true,
      );

      final Map<String, dynamic> prescription = _extractMap(response);

      prescriptionId = _readString(
        prescription,
        <String>['_id', 'id'],
      );
    }

    if (prescriptionId.trim().isEmpty) {
      throw Exception('Prescription ID missing.');
    }

    final Map<String, dynamic> response = await _apiClient.patch(
      '/api/prescriptions/$prescriptionId/claim',
      requiresAuth: true,
      body: <String, dynamic>{
        'pharmacyName': claimData['pharmacyName'],
        'pharmacyLocation': claimData['pharmacyLocation'],
        'claimRemarks': claimData['claimRemarks'],
      },
    );

    return _extractMap(response);
  }

  Future<void> _syncPendingClaims({
    bool showMessage = true,
  }) async {
    if (_isSyncing) {
      return;
    }

    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final List<Map<String, dynamic>> pendingClaims =
          await _readPendingClaims();

      if (pendingClaims.isEmpty) {
        if (!mounted) {
          return;
        }

        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pending prescription claims to sync.'),
            ),
          );
        }

        return;
      }

      final List<Map<String, dynamic>> stillPending = <Map<String, dynamic>>[];
      int syncedCount = 0;

      for (final Map<String, dynamic> pendingClaim in pendingClaims) {
        try {
          await _sendClaimToServer(pendingClaim);
          syncedCount++;
        } catch (error) {
          if (_isAlreadyClaimedError(error)) {
            syncedCount++;
          } else {
            stillPending.add(pendingClaim);
          }
        }
      }

      await _savePendingClaims(stillPending);

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingClaims = stillPending;
      });

      if (showMessage && syncedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$syncedCount pending prescription claim(s) synced successfully.',
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }

      if (showMessage && syncedCount == 0 && stillPending.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still offline. Pending claims were not synced.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _syncPendingClaims(showMessage: true);

    if (!mounted) {
      return;
    }

    await _loadRecords(syncFirst: false);
  }

  Future<void> _scanPrescriptionQr() async {
    final String? token = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return const _PrescriptionQrScannerSheet();
      },
    );

    if (!mounted || token == null || token.trim().isEmpty) {
      return;
    }

    await _loadPrescriptionForClaim(token.trim());
  }

  Future<void> _enterTokenManually() async {
    final TextEditingController tokenController = TextEditingController();

    final String? token = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Enter Prescription Token',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: tokenController,
            decoration: const InputDecoration(
              labelText: 'QR token',
              prefixIcon: Icon(Icons.key_rounded),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop(tokenController.text.trim());
              },
              icon: const Icon(Icons.search_rounded),
              label: const Text('Check'),
            ),
          ],
        );
      },
    );

    tokenController.dispose();

    if (!mounted || token == null || token.trim().isEmpty) {
      return;
    }

    await _loadPrescriptionForClaim(token.trim());
  }

  Future<void> _loadPrescriptionForClaim(String token) async {
    setState(() {
      _isLoadingScannedPrescription = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/prescriptions/qr/${Uri.encodeComponent(token)}',
        requiresAuth: true,
      );

      final Map<String, dynamic> prescription = _extractMap(response);

      if (!mounted) {
        return;
      }

      await _showClaimSheet(
        token: token,
        prescription: prescription,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to load prescription QR.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingScannedPrescription = false;
        });
      }
    }
  }

  Future<void> _showClaimSheet({
    required String token,
    required Map<String, dynamic> prescription,
  }) async {
    final _PrescriptionClaimInput? input =
        await showModalBottomSheet<_PrescriptionClaimInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _PrescriptionClaimSheet(
          token: token,
          prescription: prescription,
        );
      },
    );

    if (!mounted || input == null) {
      return;
    }

    await _claimPrescription(
      token: token,
      prescription: prescription,
      input: input,
    );
  }

  Future<void> _claimPrescription({
    required String token,
    required Map<String, dynamic> prescription,
    required _PrescriptionClaimInput input,
  }) async {
    final String prescriptionId = _readString(
      prescription,
      <String>['_id', 'id'],
    );

    if (prescriptionId.trim().isEmpty) {
      _showError('Prescription ID was not found.');
      return;
    }

    final Map<String, dynamic> claimData = <String, dynamic>{
      'prescriptionId': prescriptionId,
      'token': token,
      'pharmacyName': input.pharmacyName,
      'pharmacyLocation': input.pharmacyLocation,
      'claimRemarks': input.claimRemarks,
      'claimedAtLocal': DateTime.now().toIso8601String(),
      'prescriptionSnapshot': prescription,
    };

    setState(() {
      _isClaiming = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> claimedPrescription =
          await _sendClaimToServer(claimData);

      if (!mounted) {
        return;
      }

      setState(() {
        _claimedPrescriptions.insert(0, claimedPrescription);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription QR claimed successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      await _loadRecords(syncFirst: false);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (error) {
      if (!_isOfflineError(error)) {
        if (!mounted) {
          return;
        }

        _showError(
          'Unable to claim prescription. Server returned an unexpected response. Please refresh and try again.',
        );
        return;
      }

      final List<Map<String, dynamic>> pendingClaims =
          await _readPendingClaims();

      final bool alreadyPending = pendingClaims.any(
        (Map<String, dynamic> pendingClaim) {
          return (pendingClaim['prescriptionId'] ?? '').toString() ==
                  prescriptionId ||
              (pendingClaim['token'] ?? '').toString() == token;
        },
      );

      if (!alreadyPending) {
        pendingClaims.insert(0, claimData);
        await _savePendingClaims(pendingClaims);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingClaims = pendingClaims;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No internet connection. Claim saved as pending and will sync when connection returns.',
          ),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isClaiming = false;
        });
      }
    }
  }

  void _showClaimedPrescriptionDetails(Map<String, dynamic> prescription) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _ClaimedPrescriptionDetailsSheet(
          prescription: prescription,
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalDisplayed =
        _pendingClaims.length + _claimedPrescriptions.length;

    final bool busy =
        _isLoading || _isSyncing || _isClaiming || _isLoadingScannedPrescription;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Prescription Claims',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          if (busy)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh and sync',
            onPressed: busy ? null : _handleRefresh,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : _scanPrescriptionQr,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan QR'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _HeaderCard(
                pendingCount: _pendingClaims.length,
                claimedCount: _claimedPrescriptions.length,
                isBusy: busy,
                onScan: _scanPrescriptionQr,
                onManualEntry: _enterTokenManually,
              ),
              const SizedBox(height: 18),
              if (_errorMessage != null)
                _ErrorNotice(
                  message: _errorMessage!,
                ),
              if (_pendingClaims.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _SectionTitle(
                  title: 'Pending Offline Claims',
                  subtitle:
                      '${_pendingClaims.length} claim(s) saved locally. They will sync when internet returns.',
                ),
                const SizedBox(height: 12),
                ..._pendingClaims.map(
                  (Map<String, dynamic> claim) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PendingClaimCard(
                        claim: claim,
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              const _SectionTitle(
                title: 'Synced Claimed Records',
                subtitle:
                    'Prescription QR records already confirmed by the backend.',
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const _LoadingBox()
              else if (totalDisplayed == 0)
                const _EmptyState()
              else if (_claimedPrescriptions.isEmpty)
                const _SmallNotice(
                  message:
                      'No synced claimed records yet. Pending offline claims are shown above.',
                )
              else
                ..._claimedPrescriptions.map(
                  (Map<String, dynamic> prescription) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ClaimedPrescriptionCard(
                        prescription: prescription,
                        onTap: () {
                          _showClaimedPrescriptionDetails(prescription);
                        },
                      ),
                    );
                  },
                ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrescriptionQrScannerSheet extends StatefulWidget {
  const _PrescriptionQrScannerSheet();

  @override
  State<_PrescriptionQrScannerSheet> createState() =>
      _PrescriptionQrScannerSheetState();
}

class _PrescriptionQrScannerSheetState
    extends State<_PrescriptionQrScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: <BarcodeFormat>[
      BarcodeFormat.qrCode,
    ],
  );

  bool _handled = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeCapture(BarcodeCapture capture) async {
    if (_handled) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }

    final String? rawValue = capture.barcodes.first.rawValue;

    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    final String token = _parsePrescriptionToken(rawValue);

    if (token.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Invalid prescription QR.';
      });
      return;
    }

    _handled = true;

    await _scannerController.stop();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(token);
  }

  String _parsePrescriptionToken(String rawValue) {
    final String text = rawValue.trim();

    try {
      final dynamic decoded = jsonDecode(text);

      if (decoded is Map<String, dynamic>) {
        final String type = (decoded['type'] ?? '').toString();
        final dynamic token = decoded['token'] ?? decoded['qrToken'];

        if (type.isNotEmpty && type != 'rhu_prescription_qr') {
          return '';
        }

        if (token != null && token.toString().trim().isNotEmpty) {
          return token.toString().trim();
        }
      }
    } catch (_) {
      // Not JSON. Continue checking URI/raw token.
    }

    try {
      final Uri uri = Uri.parse(text);

      final String? tokenFromQuery =
          uri.queryParameters['token'] ?? uri.queryParameters['qrToken'];

      if (tokenFromQuery != null && tokenFromQuery.trim().isNotEmpty) {
        return tokenFromQuery.trim();
      }

      if (uri.pathSegments.isNotEmpty) {
        final String lastSegment = uri.pathSegments.last.trim();

        if (lastSegment.length >= 20) {
          return lastSegment;
        }
      }
    } catch (_) {
      // Not URI. Treat as raw token.
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.50,
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
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Scan Prescription QR',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Torch',
                    onPressed: () {
                      _scannerController.toggleTorch();
                    },
                    icon: const Icon(Icons.flash_on_rounded),
                  ),
                  IconButton(
                    tooltip: 'Switch camera',
                    onPressed: () {
                      _scannerController.switchCamera();
                    },
                    icon: const Icon(Icons.cameraswitch_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Place the patient prescription QR inside the frame.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    children: <Widget>[
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _handleBarcodeCapture,
                      ),
                      const _ScannerOverlay(),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                _ErrorNotice(message: _errorMessage!),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 230,
          height: 230,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrescriptionClaimInput {
  const _PrescriptionClaimInput({
    required this.pharmacyName,
    required this.pharmacyLocation,
    required this.claimRemarks,
  });

  final String pharmacyName;
  final String pharmacyLocation;
  final String claimRemarks;
}

class _PrescriptionClaimSheet extends StatefulWidget {
  const _PrescriptionClaimSheet({
    required this.token,
    required this.prescription,
  });

  final String token;
  final Map<String, dynamic> prescription;

  @override
  State<_PrescriptionClaimSheet> createState() =>
      _PrescriptionClaimSheetState();
}

class _PrescriptionClaimSheetState extends State<_PrescriptionClaimSheet> {
  final TextEditingController _pharmacyNameController =
      TextEditingController(text: 'RHU Pharmacy');
  final TextEditingController _pharmacyLocationController =
      TextEditingController();
  final TextEditingController _claimRemarksController = TextEditingController();

  @override
  void dispose() {
    _pharmacyNameController.dispose();
    _pharmacyLocationController.dispose();
    _claimRemarksController.dispose();
    super.dispose();
  }

  bool get _canClaim {
    final String status = _readString(widget.prescription, <String>['status']);

    return status == 'issued';
  }

  void _submit() {
    final String pharmacyName = _pharmacyNameController.text.trim();

    if (pharmacyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pharmacy name is required.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _PrescriptionClaimInput(
        pharmacyName: pharmacyName,
        pharmacyLocation: _pharmacyLocationController.text.trim(),
        claimRemarks: _claimRemarksController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String status = _readString(widget.prescription, <String>['status']);

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
              _PrescriptionDetailsCard(
                prescription: widget.prescription,
                token: widget.token,
              ),
              const SizedBox(height: 16),
              _ClaimStatusInstructionBox(
                status: status,
              ),
              if (_canClaim) ...<Widget>[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Icon(
                              Icons.local_pharmacy_rounded,
                              color: Color(0xFF7C3AED),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Claim Information',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _pharmacyNameController,
                          decoration: const InputDecoration(
                            labelText: 'Pharmacy name',
                            prefixIcon: Icon(Icons.local_pharmacy_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pharmacyLocationController,
                          decoration: const InputDecoration(
                            labelText: 'Pharmacy location optional',
                            prefixIcon: Icon(Icons.location_on_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _claimRemarksController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Claim remarks optional',
                            hintText: 'Example: Medicines released completely.',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                  onPressed: _submit,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Claim Prescription'),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClaimStatusInstructionBox extends StatelessWidget {
  const _ClaimStatusInstructionBox({
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
          'Valid prescription QR. Review the patient and medicine details before claiming.';
      color = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
    } else if (status == 'claimed') {
      message = 'This prescription QR was already claimed.';
      color = const Color(0xFF2563EB);
      icon = Icons.fact_check_rounded;
    } else if (status == 'expired') {
      message = 'This prescription QR is already expired.';
      color = const Color(0xFFDC2626);
      icon = Icons.timer_off_rounded;
    } else if (status == 'cancelled') {
      message = 'This prescription QR was cancelled by the RHU.';
      color = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
    } else {
      message = 'Prescription status: ${_prettyEnum(status)}.';
      color = const Color(0xFFF59E0B);
      icon = Icons.info_outline_rounded;
    }

    return _ColoredNotice(
      message: message,
      color: color,
      icon: icon,
    );
  }
}

class _PrescriptionDetailsCard extends StatelessWidget {
  const _PrescriptionDetailsCard({
    required this.prescription,
    required this.token,
  });

  final Map<String, dynamic> prescription;
  final String token;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> medicines = prescription['medicines'] is List
        ? prescription['medicines'] as List<dynamic>
        : <dynamic>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.medication_rounded,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prescription Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _StatusChip.fromStatus(
                  status: _readString(prescription, <String>['status']),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoLine(
              label: 'Patient',
              value: _patientName(prescription),
            ),
            _InfoLine(
              label: 'Doctor',
              value: _fallback(
                _readString(prescription, <String>['doctorName']),
              ),
            ),
            _InfoLine(
              label: 'Diagnosis',
              value: _fallback(
                _readString(prescription, <String>['diagnosis']),
              ),
            ),
            _InfoLine(
              label: 'Issued',
              value: _formatDateTimeText(
                _readString(prescription, <String>['issuedAt', 'createdAt']),
              ),
            ),
            _InfoLine(
              label: 'Expires',
              value: _formatDateTimeText(
                _readString(prescription, <String>['expiresAt']),
              ),
            ),
            _InfoLine(
              label: 'Token',
              value: _fallback(token),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Medicines',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            if (medicines.isEmpty)
              const _SmallNotice(
                message: 'No medicine items found.',
              )
            else
              ...medicines.map(
                (dynamic rawMedicine) {
                  if (rawMedicine is! Map<String, dynamic>) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MedicineLine(
                      medicine: rawMedicine,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ClaimedPrescriptionDetailsSheet extends StatelessWidget {
  const _ClaimedPrescriptionDetailsSheet({
    required this.prescription,
  });

  final Map<String, dynamic> prescription;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.84,
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
              _PrescriptionDetailsCard(
                prescription: prescription,
                token: _readString(prescription, <String>['qrToken']),
              ),
              const SizedBox(height: 16),
              _ClaimedSummaryCard(
                prescription: prescription,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
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

class _ClaimedSummaryCard extends StatelessWidget {
  const _ClaimedSummaryCard({
    required this.prescription,
  });

  final Map<String, dynamic> prescription;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFDCFCE7),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Claim Summary',
                    style: TextStyle(
                      color: Color(0xFF14532D),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
              label: 'Claimed at',
              value: _formatDateTimeText(
                _readString(prescription, <String>['claimedAt']),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.pendingCount,
    required this.claimedCount,
    required this.isBusy,
    required this.onScan,
    required this.onManualEntry,
  });

  final int pendingCount;
  final int claimedCount;
  final bool isBusy;
  final VoidCallback onScan;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF7C3AED),
            Color(0xFF5B21B6),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
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
                Icons.local_pharmacy_rounded,
                color: Colors.white,
                size: 32,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pharmacy Claim Center',
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
            'Scan prescription QR codes, verify medicine details, claim prescriptions, and sync offline claim records.',
            style: TextStyle(
              color: Color(0xFFEDE9FE),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderMetric(
                  label: 'Pending',
                  value: pendingCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Claimed',
                  value: claimedCount.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF5B21B6),
            ),
            onPressed: isBusy ? null : onScan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan Prescription QR'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(
                color: Colors.white,
              ),
            ),
            onPressed: isBusy ? null : onManualEntry,
            icon: const Icon(Icons.key_rounded),
            label: const Text('Enter Token Manually'),
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
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFEDE9FE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PendingClaimCard extends StatelessWidget {
  const _PendingClaimCard({
    required this.claim,
  });

  final Map<String, dynamic> claim;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> snapshot =
        claim['prescriptionSnapshot'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(claim['prescriptionSnapshot'])
            : <String, dynamic>{};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFF59E0B),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pending Offline Claim',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusChip(
                  label: 'Pending',
                  foreground: Color(0xFFF59E0B),
                  background: Color(0xFFFFFBEB),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoLine(
              label: 'Patient',
              value: _patientName(snapshot),
            ),
            _InfoLine(
              label: 'Pharmacy',
              value: _fallback((claim['pharmacyName'] ?? '').toString()),
            ),
            _InfoLine(
              label: 'Location',
              value: _fallback((claim['pharmacyLocation'] ?? '').toString()),
            ),
            _InfoLine(
              label: 'Claimed at',
              value: _formatDateTimeText(
                (claim['claimedAtLocal'] ?? '').toString(),
              ),
            ),
            _InfoLine(
              label: 'Token',
              value: _fallback((claim['token'] ?? '').toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimedPrescriptionCard extends StatelessWidget {
  const _ClaimedPrescriptionCard({
    required this.prescription,
    required this.onTap,
  });

  final Map<String, dynamic> prescription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> medicines = prescription['medicines'] is List
        ? prescription['medicines'] as List<dynamic>
        : <dynamic>[];

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
              color: const Color(0xFFDCFCE7),
            ),
          ),
          child: Column(
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Claimed Prescription',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusChip(
                    label: 'Claimed',
                    foreground: Color(0xFF16A34A),
                    background: Color(0xFFDCFCE7),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoLine(
                label: 'Patient',
                value: _patientName(prescription),
              ),
              _InfoLine(
                label: 'Doctor',
                value: _fallback(
                  _readString(
                    prescription,
                    <String>['doctorName'],
                  ),
                ),
              ),
              _InfoLine(
                label: 'Pharmacy',
                value: _fallback(
                  _readString(
                    prescription,
                    <String>['pharmacyName'],
                  ),
                ),
              ),
              _InfoLine(
                label: 'Claimed at',
                value: _formatDateTimeText(
                  _readString(
                    prescription,
                    <String>['claimedAt'],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Medicines',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              if (medicines.isEmpty)
                const _SmallNotice(
                  message: 'No medicine items found.',
                )
              else
                ...medicines.take(2).map(
                  (dynamic rawMedicine) {
                    if (rawMedicine is! Map<String, dynamic>) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MedicineLine(
                        medicine: rawMedicine,
                      ),
                    );
                  },
                ),
              if (medicines.length > 2)
                Text(
                  '+${medicines.length - 2} more medicine item(s)',
                  style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicineLine extends StatelessWidget {
  const _MedicineLine({
    required this.medicine,
  });

  final Map<String, dynamic> medicine;

  @override
  Widget build(BuildContext context) {
    final String medicineName = _readString(
      medicine,
      <String>['medicineName', 'name'],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
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
          const SizedBox(height: 4),
          Text(
            'Qty: ${_fallback(quantity)} ${_fallback(unit)}',
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (instructions.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              instructions,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
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
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  factory _StatusChip.fromStatus({
    required String status,
  }) {
    switch (status) {
      case 'issued':
        return const _StatusChip(
          label: 'Issued',
          foreground: Color(0xFF2563EB),
          background: Color(0xFFDBEAFE),
        );
      case 'claimed':
        return const _StatusChip(
          label: 'Claimed',
          foreground: Color(0xFF16A34A),
          background: Color(0xFFDCFCE7),
        );
      case 'expired':
        return const _StatusChip(
          label: 'Expired',
          foreground: Color(0xFFDC2626),
          background: Color(0xFFFEF2F2),
        );
      case 'cancelled':
        return const _StatusChip(
          label: 'Cancelled',
          foreground: Color(0xFFDC2626),
          background: Color(0xFFFEF2F2),
        );
      default:
        return _StatusChip(
          label: _prettyEnum(status),
          foreground: const Color(0xFFF59E0B),
          background: const Color(0xFFFFFBEB),
        );
    }
  }

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
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return _ColoredNotice(
      message: message,
      color: const Color(0xFFDC2626),
      icon: Icons.error_outline_rounded,
    );
  }
}

class _SmallNotice extends StatelessWidget {
  const _SmallNotice({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return _ColoredNotice(
      message: message,
      color: const Color(0xFFF59E0B),
      icon: Icons.info_outline_rounded,
    );
  }
}

class _ColoredNotice extends StatelessWidget {
  const _ColoredNotice({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
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
              child: Text('Loading claimed prescription records...'),
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
              'No claimed records yet',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Scan a patient prescription QR to claim medicines. Claimed records will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                height: 1.4,
                fontWeight: FontWeight.w600,
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
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(
        Icons.local_pharmacy_outlined,
        color: Color(0xFF7C3AED),
        size: 36,
      ),
    );
  }
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
    return 'Unknown patient';
  }

  return parts.join(' ');
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

String _formatDateTimeText(String value) {
  if (value.trim().isEmpty) {
    return 'N/A';
  }

  try {
    final DateTime parsed = DateTime.parse(value).toLocal();

    final String year = parsed.year.toString().padLeft(4, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    final String day = parsed.day.toString().padLeft(2, '0');

    final int hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final String minute = parsed.minute.toString().padLeft(2, '0');
    final String period = parsed.hour >= 12 ? 'PM' : 'AM';

    return '$year-$month-$day $hour12:$minute $period';
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
      final String nestedName = _readString(
        value,
        <String>[
          'name',
          'fullName',
          'email',
          '_id',
          'id',
        ],
      );

      if (nestedName.trim().isNotEmpty) {
        return nestedName;
      }
    }

    final String text = value.toString().trim();

    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }

  return '';
}