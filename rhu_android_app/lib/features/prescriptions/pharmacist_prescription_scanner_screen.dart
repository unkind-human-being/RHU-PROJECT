import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/token_storage_service.dart';
import '../auth/auth_provider.dart';

class PharmacistPrescriptionScannerScreen extends StatefulWidget {
  const PharmacistPrescriptionScannerScreen({super.key});

  static const String routeName = '/pharmacist-prescription-scanner';

  @override
  State<PharmacistPrescriptionScannerScreen> createState() =>
      _PharmacistPrescriptionScannerScreenState();
}

class _PharmacistPrescriptionScannerScreenState
    extends State<PharmacistPrescriptionScannerScreen> {
  final GlobalKey<FormState> _claimFormKey = GlobalKey<FormState>();

  final TextEditingController _pharmacyNameController =
      TextEditingController();
  final TextEditingController _pharmacyLocationController =
      TextEditingController();
  final TextEditingController _claimRemarksController =
      TextEditingController();

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: <BarcodeFormat>[
      BarcodeFormat.qrCode,
    ],
  );

  late final ApiClient _apiClient;

  bool _isHandlingScan = false;
  bool _isLoadingPrescription = false;
  bool _isClaiming = false;
  bool _isSyncing = false;
  bool _hasInitializedFields = false;
  bool _loadedFromQrPayload = false;

  String _lastScannedToken = '';
  String? _errorMessage;
  String? _offlineNotice;

  Map<String, dynamic>? _prescription;

  static const String _pendingClaimsKey = 'pending_prescription_claims_v1';

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPendingClaims(showSuccessMessage: true);
    });
  }

  @override
  void dispose() {
    _pharmacyNameController.dispose();
    _pharmacyLocationController.dispose();
    _claimRemarksController.dispose();
    _scannerController.dispose();
    _apiClient.close();
    super.dispose();
  }

  void _initializeFieldsFromAuth(AuthProvider authProvider) {
    if (_hasInitializedFields) {
      return;
    }

    _hasInitializedFields = true;

    final String email = authProvider.user?.email ?? '';

    if (_pharmacyNameController.text.trim().isEmpty) {
      _pharmacyNameController.text =
          email.trim().isEmpty ? 'RHU Pharmacy' : email;
    }

    if (_pharmacyLocationController.text.trim().isEmpty) {
      _pharmacyLocationController.text = authProvider.assignedLocation;
    }
  }

  Future<void> _handleBarcodeCapture(BarcodeCapture capture) async {
    if (_isHandlingScan || _isLoadingPrescription || _isClaiming) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }

    final String? rawValue = capture.barcodes.first.rawValue;

    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    final _QrParseResult parsed = _parseQr(rawValue);

    if (parsed.token.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Invalid prescription QR code.';
      });
      return;
    }

    setState(() {
      _isHandlingScan = true;
      _lastScannedToken = parsed.token;
      _errorMessage = null;
      _offlineNotice = null;
      _loadedFromQrPayload = parsed.payload != null;
    });

    await _scannerController.stop();

    if (parsed.payload != null) {
      setState(() {
        _prescription = _normalizeQrPayload(parsed.payload!);
        _offlineNotice =
            'QR details loaded. Checking server if internet is available...';
      });
    }

    await _loadPrescriptionByToken(
      parsed.token,
      fallbackPayload: parsed.payload,
    );
  }

  _QrParseResult _parseQr(String rawValue) {
    final String text = rawValue.trim();

    try {
      final dynamic decoded = jsonDecode(text);

      if (decoded is Map<String, dynamic>) {
        final dynamic token = decoded['token'] ?? decoded['qrToken'];

        if (token != null && token.toString().trim().isNotEmpty) {
          return _QrParseResult(
            token: token.toString().trim(),
            payload: decoded,
          );
        }
      }
    } catch (_) {
      // Not JSON. Continue checking URI / raw token formats.
    }

    try {
      final Uri uri = Uri.parse(text);

      final String? tokenFromQuery =
          uri.queryParameters['token'] ?? uri.queryParameters['qrToken'];

      if (tokenFromQuery != null && tokenFromQuery.trim().isNotEmpty) {
        return _QrParseResult(token: tokenFromQuery.trim());
      }

      if (uri.pathSegments.isNotEmpty) {
        final String lastSegment = uri.pathSegments.last.trim();

        if (lastSegment.length >= 20) {
          return _QrParseResult(token: lastSegment);
        }
      }
    } catch (_) {
      // Not a URI. Treat as raw token below.
    }

    return _QrParseResult(token: text);
  }

  Map<String, dynamic> _normalizeQrPayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> patient =
        payload['patient'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(payload['patient'])
            : <String, dynamic>{};

    final String token = _readString(payload, <String>['token', 'qrToken']);

    return <String, dynamic>{
      '_id': _readString(payload, <String>['prescriptionId', 'id', '_id']),
      'qrToken': token,
      'status': _readString(payload, <String>['status']).isEmpty
          ? 'issued'
          : _readString(payload, <String>['status']),
      'patientFirstName': _readString(
        patient,
        <String>['firstName', 'patientFirstName'],
      ),
      'patientLastName': _readString(
        patient,
        <String>['lastName', 'patientLastName'],
      ),
      'patientMiddleInitial': _readString(
        patient,
        <String>['middleInitial', 'patientMiddleInitial'],
      ),
      'patientAge': _readString(patient, <String>['age', 'patientAge']),
      'patientSex': _readString(patient, <String>['sex', 'patientSex']),
      'contactNumber': _readString(
        patient,
        <String>['contactNumber', 'phoneNumber'],
      ),
      'doctorName': _readString(payload, <String>['doctorName']),
      'diagnosis': _readString(payload, <String>['diagnosis']),
      'issuedAt': _readString(payload, <String>['issuedAt']),
      'expiresAt': _readString(payload, <String>['expiresAt']),
      'medicines':
          payload['medicines'] is List ? payload['medicines'] : <dynamic>[],
      'isLocalQrPayload': true,
    };
  }

  bool _isOfflineError(Object error) {
    final String text = error.toString().toLowerCase();

    return error is TimeoutException ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('connection timed out') ||
        text.contains('network is unreachable') ||
        text.contains('clientexception') ||
        text.contains('xmlhttprequest') ||
        text.contains('handshakeexception');
  }

  Future<void> _loadPrescriptionByToken(
    String token, {
    Map<String, dynamic>? fallbackPayload,
  }) async {
    setState(() {
      _isLoadingPrescription = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/prescriptions/qr/${Uri.encodeComponent(token)}',
        requiresAuth: true,
      );

      final Map<String, dynamic> prescription = _extractMap(response);

      if (!mounted) return;

      setState(() {
        _prescription = prescription;
        _loadedFromQrPayload = false;
        _offlineNotice = null;
      });
    } catch (error) {
      if (!mounted) return;

      if (_isOfflineError(error) && fallbackPayload != null) {
        setState(() {
          _prescription = _normalizeQrPayload(fallbackPayload);
          _loadedFromQrPayload = true;
          _offlineNotice =
              'Offline mode: showing details saved inside the QR. Claim will be saved locally and synced later.';
        });
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPrescription = false;
        });
      }
    }
  }

  Future<void> _claimPrescription() async {
    final Map<String, dynamic>? prescription = _prescription;

    if (prescription == null) {
      return;
    }

    if (!_claimFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isClaiming = true;
      _errorMessage = null;
    });

    final String prescriptionId = _readString(
      prescription,
      <String>['_id', 'id', 'prescriptionId'],
    );

    final String token = _readString(
      prescription,
      <String>['qrToken', 'token'],
    );

    final Map<String, dynamic> claimData = <String, dynamic>{
      'clientClaimId': 'claim-${DateTime.now().millisecondsSinceEpoch}',
      'prescriptionId': prescriptionId,
      'token': token,
      'pharmacyName': _pharmacyNameController.text.trim(),
      'pharmacyLocation': _pharmacyLocationController.text.trim(),
      'claimRemarks': _claimRemarksController.text.trim(),
      'claimedAtLocal': DateTime.now().toIso8601String(),
      'prescriptionSnapshot': prescription,
    };

    try {
      final Map<String, dynamic> updatedPrescription =
          await _sendClaimToServer(claimData);

      if (!mounted) return;

      setState(() {
        _prescription = updatedPrescription;
        _offlineNotice = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription QR claimed successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      if (_isOfflineError(error)) {
        await _savePendingClaim(claimData);

        if (!mounted) return;

        final Map<String, dynamic> localClaimedPrescription =
            Map<String, dynamic>.from(prescription);

        localClaimedPrescription['status'] = 'pending_sync';
        localClaimedPrescription['claimedAt'] = claimData['claimedAtLocal'];
        localClaimedPrescription['pharmacyName'] = claimData['pharmacyName'];
        localClaimedPrescription['pharmacyLocation'] =
            claimData['pharmacyLocation'];
        localClaimedPrescription['claimRemarks'] = claimData['claimRemarks'];

        setState(() {
          _prescription = localClaimedPrescription;
          _offlineNotice =
              'No internet detected. This claim was saved locally and will sync automatically later.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim saved offline. It will sync automatically.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );

        return;
      }

      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isClaiming = false;
        });
      }
    }
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

  Future<void> _savePendingClaim(Map<String, dynamic> claimData) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> pendingClaims = await _readPendingClaims();

    final String clientClaimId = (claimData['clientClaimId'] ?? '').toString();

    final bool alreadySaved = pendingClaims.any((Map<String, dynamic> item) {
      return item['clientClaimId'] == clientClaimId;
    });

    if (!alreadySaved) {
      pendingClaims.add(claimData);
    }

    await preferences.setString(
      _pendingClaimsKey,
      jsonEncode(pendingClaims),
    );
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

  Future<void> _syncPendingClaims({
    required bool showSuccessMessage,
  }) async {
    if (_isSyncing) {
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> pendingClaims =
          await _readPendingClaims();

      if (pendingClaims.isEmpty) {
        return;
      }

      final List<Map<String, dynamic>> stillPending = <Map<String, dynamic>>[];
      int syncedCount = 0;

      for (final Map<String, dynamic> pendingClaim in pendingClaims) {
        try {
          await _sendClaimToServer(pendingClaim);
          syncedCount++;
        } catch (_) {
          stillPending.add(pendingClaim);
        }
      }

      await preferences.setString(
        _pendingClaimsKey,
        jsonEncode(stillPending),
      );

      if (!mounted) {
        return;
      }

      if (syncedCount > 0 && showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$syncedCount medicine prescription claim(s) synced successfully.',
            ),
            backgroundColor: const Color(0xFF16A34A),
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );

    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _scanAnother() async {
    setState(() {
      _isHandlingScan = false;
      _isLoadingPrescription = false;
      _isClaiming = false;
      _loadedFromQrPayload = false;
      _lastScannedToken = '';
      _errorMessage = null;
      _offlineNotice = null;
      _prescription = null;
      _claimRemarksController.clear();
    });

    await _syncPendingClaims(showSuccessMessage: true);
    await _scannerController.start();
  }

  Map<String, dynamic> _extractMap(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return response;
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
    final AuthProvider authProvider = context.watch<AuthProvider>();

    _initializeFieldsFromAuth(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan Prescription QR',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          if (_isSyncing)
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            _HeaderCard(
              assignedLocation: authProvider.assignedLocation,
            ),
            const SizedBox(height: 18),
            if (_prescription == null)
              _ScannerCard(
                scannerController: _scannerController,
                isLoading: _isLoadingPrescription,
                onDetect: _handleBarcodeCapture,
              )
            else
              _PrescriptionDetailsCard(
                prescription: _prescription!,
                claimFormKey: _claimFormKey,
                pharmacyNameController: _pharmacyNameController,
                pharmacyLocationController: _pharmacyLocationController,
                claimRemarksController: _claimRemarksController,
                isClaiming: _isClaiming,
                loadedFromQrPayload: _loadedFromQrPayload,
                onClaim: _claimPrescription,
                onScanAnother: _scanAnother,
                requiredValidator: _requiredValidator,
              ),
            if (_offlineNotice != null) ...<Widget>[
              const SizedBox(height: 12),
              _NoticeCard(
                message: _offlineNotice!,
                color: const Color(0xFFF59E0B),
              ),
            ],
            if (_lastScannedToken.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _TokenCard(token: _lastScannedToken),
            ],
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _ErrorCard(
                message: _errorMessage!,
                onTryAgain: _scanAnother,
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _QrParseResult {
  const _QrParseResult({
    required this.token,
    this.payload,
  });

  final String token;
  final Map<String, dynamic>? payload;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.assignedLocation,
  });

  final String assignedLocation;

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
              Icons.qr_code_scanner_rounded,
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
                  'Prescription Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Scan prescription QR, verify details, then mark medicine as claimed.',
                  style: TextStyle(
                    color: Color(0xFFEDE9FE),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  assignedLocation,
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

class _ScannerCard extends StatelessWidget {
  const _ScannerCard({
    required this.scannerController,
    required this.isLoading,
    required this.onDetect,
  });

  final MobileScannerController scannerController;
  final bool isLoading;
  final void Function(BarcodeCapture capture) onDetect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Text(
              'Scan QR Code',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Place the prescription QR inside the frame.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: <Widget>[
                    MobileScanner(
                      controller: scannerController,
                      onDetect: onDetect,
                    ),
                    const _ScannerOverlay(),
                    if (isLoading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Checking prescription...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

class _PrescriptionDetailsCard extends StatelessWidget {
  const _PrescriptionDetailsCard({
    required this.prescription,
    required this.claimFormKey,
    required this.pharmacyNameController,
    required this.pharmacyLocationController,
    required this.claimRemarksController,
    required this.isClaiming,
    required this.loadedFromQrPayload,
    required this.onClaim,
    required this.onScanAnother,
    required this.requiredValidator,
  });

  final Map<String, dynamic> prescription;
  final GlobalKey<FormState> claimFormKey;
  final TextEditingController pharmacyNameController;
  final TextEditingController pharmacyLocationController;
  final TextEditingController claimRemarksController;
  final bool isClaiming;
  final bool loadedFromQrPayload;
  final VoidCallback onClaim;
  final VoidCallback onScanAnother;
  final String? Function(String? value, String fieldName) requiredValidator;

  bool get _canClaim {
    final String status = _readString(
      prescription,
      <String>['status'],
    );

    return status == 'issued';
  }

  @override
  Widget build(BuildContext context) {
    final String status = _readString(
      prescription,
      <String>['status'],
    );

    final List<dynamic> medicines = _readMedicines(prescription);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _canClaim
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  color: _canClaim
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prescription Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            if (loadedFromQrPayload) ...<Widget>[
              const SizedBox(height: 10),
              const _NoticeCard(
                message:
                    'Loaded from QR data. If internet is unavailable, claim will be saved offline.',
                color: Color(0xFF2563EB),
              ),
            ],
            const SizedBox(height: 14),
            _InfoLine(
              label: 'Patient',
              value: _patientName(prescription),
            ),
            _InfoLine(
              label: 'Age / Sex',
              value:
                  '${_fallback(_readString(prescription, <String>['patientAge']))} • ${_prettySex(_readString(prescription, <String>['patientSex']))}',
            ),
            _InfoLine(
              label: 'Contact',
              value: _fallback(
                _readString(
                  prescription,
                  <String>['contactNumber'],
                ),
              ),
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
              label: 'Diagnosis',
              value: _fallback(
                _readString(
                  prescription,
                  <String>['diagnosis'],
                ),
              ),
            ),
            _InfoLine(
              label: 'Expires',
              value: _formatDateTimeText(
                _readString(
                  prescription,
                  <String>['expiresAt'],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Prescribed Medicines',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            if (medicines.isEmpty)
              const _NoticeCard(
                message: 'No medicine items were found in this prescription.',
                color: Color(0xFFF59E0B),
              )
            else
              ...medicines.map(
                (dynamic rawMedicine) {
                  if (rawMedicine is! Map<String, dynamic>) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MedicineItemCard(
                      medicine: rawMedicine,
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            if (_canClaim)
              Form(
                key: claimFormKey,
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      controller: pharmacyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Pharmacy name',
                        prefixIcon: Icon(Icons.local_pharmacy_rounded),
                      ),
                      validator: (String? value) {
                        return requiredValidator(value, 'Pharmacy name');
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pharmacyLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Pharmacy location',
                        prefixIcon: Icon(Icons.location_on_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: claimRemarksController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Claim remarks optional',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: isClaiming ? null : onClaim,
                      icon: isClaiming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(
                        isClaiming
                            ? 'Claiming Prescription...'
                            : 'Mark as Claimed',
                      ),
                    ),
                  ],
                ),
              )
            else
              _NoticeCard(
                message:
                    'This QR cannot be claimed because its current status is ${_prettyStatus(status)}.',
                color: const Color(0xFFF59E0B),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isClaiming ? null : onScanAnother,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan Another QR'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineItemCard extends StatelessWidget {
  const _MedicineItemCard({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: <Widget>[
          _InfoLine(
            label: 'Medicine',
            value: _fallback(medicineName),
          ),
          _InfoLine(
            label: 'Generic',
            value: _fallback(genericName),
          ),
          _InfoLine(
            label: 'Strength/Form',
            value: '${_fallback(strength)} • ${_fallback(dosageForm)}',
          ),
          _InfoLine(
            label: 'Quantity',
            value: '${_fallback(quantity)} ${_fallback(unit)}',
          ),
          _InfoLine(
            label: 'Instructions',
            value: _fallback(instructions),
          ),
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
    final bool issued = status == 'issued';
    final bool claimed = status == 'claimed';
    final bool pendingSync = status == 'pending_sync';

    final Color foreground = claimed || pendingSync
        ? const Color(0xFF2563EB)
        : issued
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626);

    final Color background = claimed || pendingSync
        ? const Color(0xFFDBEAFE)
        : issued
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEF2F2);

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
        _prettyStatus(status),
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

class _TokenCard extends StatelessWidget {
  const _TokenCard({
    required this.token,
  });

  final String token;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.key_rounded,
              color: Color(0xFF7C3AED),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                token,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

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
            Icons.info_outline_rounded,
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onTryAgain,
  });

  final String message;
  final Future<void> Function() onTryAgain;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              'QR Check Failed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onTryAgain,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan Again'),
            ),
          ],
        ),
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

List<dynamic> _readMedicines(Map<String, dynamic> prescription) {
  final dynamic medicines = prescription['medicines'];

  if (medicines is List) {
    return medicines;
  }

  return <dynamic>[];
}

String _fallback(String value) {
  if (value.trim().isEmpty || value.trim() == 'null') {
    return 'N/A';
  }

  return value.trim();
}

String _prettyStatus(String status) {
  switch (status) {
    case 'issued':
      return 'Issued';
    case 'claimed':
      return 'Claimed';
    case 'pending_sync':
      return 'Pending Sync';
    case 'cancelled':
      return 'Cancelled';
    case 'expired':
      return 'Expired';
    default:
      return status.trim().isEmpty ? 'Unknown' : status;
  }
}

String _prettySex(String sex) {
  switch (sex) {
    case 'male':
      return 'Male';
    case 'female':
      return 'Female';
    case 'prefer_not_to_say':
      return 'Prefer not to say';
    default:
      return 'N/A';
  }
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
    final String hour = parsed.hour.toString().padLeft(2, '0');
    final String minute = parsed.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
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
