import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage_service.dart';

class AppointmentQrCheckInScreen extends StatefulWidget {
  const AppointmentQrCheckInScreen({super.key});

  static const String routeName = '/appointment-qr-check-in';

  @override
  State<AppointmentQrCheckInScreen> createState() =>
      _AppointmentQrCheckInScreenState();
}

class _AppointmentQrCheckInScreenState
    extends State<AppointmentQrCheckInScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: <BarcodeFormat>[
      BarcodeFormat.qrCode,
    ],
  );

  late final ApiClient _apiClient;

  bool _isHandlingScan = false;
  bool _isLoadingAppointment = false;
  bool _isCheckingIn = false;

  String _lastScannedToken = '';
  String? _errorMessage;

  Map<String, dynamic>? _appointment;

  @override
  void initState() {
    super.initState();

    final TokenStorageService tokenStorageService = TokenStorageService();

    _apiClient = ApiClient(
      tokenProvider: tokenStorageService.getToken,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _handleBarcodeCapture(BarcodeCapture capture) async {
    if (_isHandlingScan || _isLoadingAppointment || _isCheckingIn) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }

    final String? rawValue = capture.barcodes.first.rawValue;

    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    final _AppointmentQrParseResult parsed = _parseQr(rawValue);

    if (parsed.token.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Invalid appointment QR ticket.';
      });
      return;
    }

    setState(() {
      _isHandlingScan = true;
      _lastScannedToken = parsed.token;
      _errorMessage = null;
      _appointment = parsed.payload;
    });

    await _scannerController.stop();
    await _loadAppointmentByToken(parsed.token);
  }

  _AppointmentQrParseResult _parseQr(String rawValue) {
    final String text = rawValue.trim();

    try {
      final dynamic decoded = jsonDecode(text);

      if (decoded is Map<String, dynamic>) {
        final dynamic type = decoded['type'];
        final dynamic token = decoded['token'] ?? decoded['qrToken'];

        if (token != null && token.toString().trim().isNotEmpty) {
          return _AppointmentQrParseResult(
            token: token.toString().trim(),
            payload: type == 'rhu_appointment_qr'
                ? _normalizeQrPayload(decoded)
                : null,
          );
        }
      }
    } catch (_) {
      // Not JSON. Continue checking URI / raw token.
    }

    try {
      final Uri uri = Uri.parse(text);

      final String? tokenFromQuery =
          uri.queryParameters['token'] ?? uri.queryParameters['qrToken'];

      if (tokenFromQuery != null && tokenFromQuery.trim().isNotEmpty) {
        return _AppointmentQrParseResult(token: tokenFromQuery.trim());
      }

      if (uri.pathSegments.isNotEmpty) {
        final String lastSegment = uri.pathSegments.last.trim();

        if (lastSegment.length >= 20) {
          return _AppointmentQrParseResult(token: lastSegment);
        }
      }
    } catch (_) {
      // Not URI. Treat as raw token.
    }

    return _AppointmentQrParseResult(token: text);
  }

  Map<String, dynamic> _normalizeQrPayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> patient =
        payload['patient'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(payload['patient'])
            : <String, dynamic>{};

    return <String, dynamic>{
      '_id': _readString(payload, <String>['appointmentId', 'id', '_id']),
      'qrToken': _readString(payload, <String>['token', 'qrToken']),
      'status': _readString(payload, <String>['status']).isEmpty
          ? 'accepted'
          : _readString(payload, <String>['status']),
      'appointmentType': _readString(payload, <String>['appointmentType']),
      'serviceType': _readString(payload, <String>['serviceType']),
      'scheduledAt': _readString(payload, <String>['scheduledAt']),
      'qrExpiresAt': _readString(payload, <String>['qrExpiresAt']),
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
      'isLocalQrPayload': true,
    };
  }

  Future<void> _loadAppointmentByToken(String token) async {
    setState(() {
      _isLoadingAppointment = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.get(
        '/api/appointments/qr/${Uri.encodeComponent(token)}',
        requiresAuth: true,
      );

      final Map<String, dynamic> appointment = _extractMap(response);

      if (!mounted) {
        return;
      }

      setState(() {
        _appointment = appointment;
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
        _errorMessage = 'Unable to load appointment QR ticket.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAppointment = false;
        });
      }
    }
  }

  Future<void> _checkInAppointment() async {
    final Map<String, dynamic>? appointment = _appointment;

    if (appointment == null) {
      return;
    }

    final String appointmentId = _readString(
      appointment,
      <String>['_id', 'id', 'appointmentId'],
    );

    if (appointmentId.trim().isEmpty) {
      _showError('Appointment ID was not found.');
      return;
    }

    setState(() {
      _isCheckingIn = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> response = await _apiClient.patch(
        '/api/appointments/$appointmentId/check-in',
        requiresAuth: true,
        body: <String, dynamic>{},
      );

      final Map<String, dynamic> updatedAppointment = _extractMap(response);

      if (!mounted) {
        return;
      }

      setState(() {
        _appointment = updatedAppointment;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment checked in successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
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

      _showError('Unable to check in appointment.');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  Future<void> _scanAnother() async {
    setState(() {
      _isHandlingScan = false;
      _isLoadingAppointment = false;
      _isCheckingIn = false;
      _lastScannedToken = '';
      _errorMessage = null;
      _appointment = null;
    });

    await _scannerController.start();
  }

  Map<String, dynamic> _extractMap(Map<String, dynamic> response) {
    final dynamic data = response['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return response;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Walk-in QR Check-in',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
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
            const _HeaderCard(),
            const SizedBox(height: 18),
            if (_appointment == null)
              _ScannerCard(
                scannerController: _scannerController,
                isLoading: _isLoadingAppointment,
                onDetect: _handleBarcodeCapture,
              )
            else
              _AppointmentDetailsCard(
                appointment: _appointment!,
                isCheckingIn: _isCheckingIn,
                onCheckIn: _checkInAppointment,
                onScanAnother: _scanAnother,
              ),
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

class _AppointmentQrParseResult {
  const _AppointmentQrParseResult({
    required this.token,
    this.payload,
  });

  final String token;
  final Map<String, dynamic>? payload;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Appointment QR Check-in',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Scan the patient walk-in QR ticket and mark them as arrived at the RHU.',
                  style: TextStyle(
                    color: Color(0xFFE0F2F1),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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
              'Scan Walk-in QR Ticket',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Place the appointment QR inside the frame.',
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
                              'Checking QR ticket...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
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

class _AppointmentDetailsCard extends StatelessWidget {
  const _AppointmentDetailsCard({
    required this.appointment,
    required this.isCheckingIn,
    required this.onCheckIn,
    required this.onScanAnother,
  });

  final Map<String, dynamic> appointment;
  final bool isCheckingIn;
  final VoidCallback onCheckIn;
  final Future<void> Function() onScanAnother;

  bool get _canCheckIn {
    final String status = _readString(appointment, <String>['status']);
    final String appointmentType = _readString(
      appointment,
      <String>['appointmentType'],
    );
    final String checkedInAt = _readString(
      appointment,
      <String>['checkedInAt'],
    );

    return status == 'accepted' &&
        appointmentType == 'walk_in' &&
        checkedInAt.trim().isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final String status = _readString(appointment, <String>['status']);
    final String appointmentType = _readString(
      appointment,
      <String>['appointmentType'],
    );
    final String checkedInAt = _readString(
      appointment,
      <String>['checkedInAt'],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _canCheckIn
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  color: _canCheckIn
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Appointment Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 14),
            _InfoLine(
              label: 'Patient',
              value: _patientName(appointment),
            ),
            _InfoLine(
              label: 'Service',
              value: _prettyService(
                _readString(appointment, <String>['serviceType']),
              ),
            ),
            _InfoLine(
              label: 'Type',
              value: _prettyAppointmentType(appointmentType),
            ),
            _InfoLine(
              label: 'Schedule',
              value: _formatDateTimeText(
                _readString(appointment, <String>['scheduledAt']),
              ),
            ),
            _InfoLine(
              label: 'QR Expires',
              value: _formatDateTimeText(
                _readString(appointment, <String>['qrExpiresAt']),
              ),
            ),
            _InfoLine(
              label: 'Contact',
              value: _fallback(
                _readString(appointment, <String>['contactNumber']),
              ),
            ),
            _InfoLine(
              label: 'Checked-in',
              value: checkedInAt.trim().isEmpty
                  ? 'Not yet checked-in'
                  : _formatDateTimeText(checkedInAt),
            ),
            const SizedBox(height: 14),
            _StatusInstructionBox(
              status: status,
              appointmentType: appointmentType,
              checkedInAt: checkedInAt,
              canCheckIn: _canCheckIn,
            ),
            const SizedBox(height: 18),
            if (_canCheckIn)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                ),
                onPressed: isCheckingIn ? null : onCheckIn,
                icon: isCheckingIn
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(
                  isCheckingIn ? 'Checking In...' : 'Check In Patient',
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isCheckingIn ? null : onScanAnother,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan Another QR'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusInstructionBox extends StatelessWidget {
  const _StatusInstructionBox({
    required this.status,
    required this.appointmentType,
    required this.checkedInAt,
    required this.canCheckIn,
  });

  final String status;
  final String appointmentType;
  final String checkedInAt;
  final bool canCheckIn;

  @override
  Widget build(BuildContext context) {
    final String message;
    final Color color;
    final IconData icon;

    if (checkedInAt.trim().isNotEmpty) {
      message = 'This patient is already checked in.';
      color = const Color(0xFF2563EB);
      icon = Icons.fact_check_rounded;
    } else if (canCheckIn) {
      message =
          'Valid walk-in QR ticket. You can check in this patient now.';
      color = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
    } else if (appointmentType != 'walk_in') {
      message = 'This is not a walk-in appointment QR ticket.';
      color = const Color(0xFFF59E0B);
      icon = Icons.warning_amber_rounded;
    } else if (status != 'accepted') {
      message =
          'Only accepted appointments can be checked in. Current status: ${_prettyEnum(status)}.';
      color = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
    } else {
      message = 'This QR ticket cannot be checked in.';
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
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
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
    final Color foreground;
    final Color background;

    switch (status) {
      case 'accepted':
        foreground = const Color(0xFF2563EB);
        background = const Color(0xFFDBEAFE);
        break;
      case 'completed':
        foreground = const Color(0xFF16A34A);
        background = const Color(0xFFDCFCE7);
        break;
      case 'rejected':
      case 'cancelled':
      case 'expired':
        foreground = const Color(0xFFDC2626);
        background = const Color(0xFFFEF2F2);
        break;
      default:
        foreground = const Color(0xFFD97706);
        background = const Color(0xFFFFFBEB);
    }

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
            width: 104,
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
              color: Color(0xFF0F766E),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                token,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                ),
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

String _patientName(Map<String, dynamic> appointment) {
  final String firstName = _readString(
    appointment,
    <String>['patientFirstName'],
  );

  final String middleInitial = _readString(
    appointment,
    <String>['patientMiddleInitial'],
  );

  final String lastName = _readString(
    appointment,
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

String _prettyService(String value) {
  switch (value) {
    case 'medical_consultation':
      return 'Medical Consultation';
    case 'maternal_care':
      return 'Maternal Care';
    case 'family_planning':
      return 'Family Planning';
    case 'screening_prevention':
      return 'Screening & Prevention';
    case 'dental_services':
      return 'Dental Services';
    case 'immunization':
      return 'Immunization';
    default:
      return _prettyEnum(value);
  }
}

String _prettyAppointmentType(String value) {
  switch (value) {
    case 'walk_in':
      return 'Walk-in';
    case 'online':
      return 'Online Consultation';
    default:
      return _prettyEnum(value);
  }
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

String _formatDateTime(DateTime dateTime) {
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
