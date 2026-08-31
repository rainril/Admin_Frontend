import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';

class ScanCheckInPage extends StatefulWidget {
  const ScanCheckInPage({super.key});

  @override
  State<ScanCheckInPage> createState() => _ScanCheckInPageState();
}

class _ScanCheckInPageState extends State<ScanCheckInPage> {
  // Preferred camera-preview edge length; clamped down on smaller cards so it
  // never overflows or has to stretch out of square.
  static const double scanBoxSize = 340;

  // PrimeFit brand palette.
  static const Color gold = Color(0xFFF4CD4A); // primary
  static const Color cyan = Color(0xFF12F5F4); // scanner frame
  static const Color mutedText = Color(0xFFAEB6BB); // fallback for status pills

  static const Map<String, List<Color>> _subscriptionColors = {
    'active': [Color(0xFFE6F7ED), Color(0xFF16A34A)],
    'expiring_soon': [Color(0xFFFEF3E2), Color(0xFFCA8A04)],
    'expired': [Color(0xFFFDEBEC), Color(0xFFDC2626)],
  };

  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _lastCheckedInName;
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final value = barcode?.rawValue;
    if (value == null || value.isEmpty) return;

    setState(() => _isProcessing = true);
    _handleScannedId(value);
  }

  Future<void> _handleScannedId(String scannedToken) async {
    final result = await AttendanceService.verifyQrToken(scannedToken);

    if (result == null || result['error'] == true) {
      final message = result?['message'] ?? 'Invalid or unrecognized QR code';
      _showSnack(message, isError: true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isProcessing = false);
      });
      return;
    }

    if (!mounted) return;
    _showMemberScanResult(result);
  }

  void _showSnack(String message, {bool isError = false}) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMemberScanResult(Map<String, dynamic> member) {
    final subscriptionStatus = (member['subscriptionStatus'] ?? 'expired').toString();
    final colors = _subscriptionColors[subscriptionStatus] ??
        [const Color(0xFFF1F1F3), mutedText];
    final isExpired = subscriptionStatus == 'expired';
    final name = member['name'] ?? '';
    final email = member['email'] ?? '';
    final qrId = member['id'] ?? '';
    final plan = member['plan'] ?? '';
    final expiryDate = member['expiryDate']?.toString() ?? '—';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: gold.withValues(alpha: 0.25),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Color(0xFFB8892E), fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Member ID', qrId),
              _detailRow('Plan', plan),
              _detailRow('Expires', expiryDate),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: colors[0], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isExpired ? Icons.error_outline : Icons.verified_outlined, size: 16, color: colors[1]),
                    const SizedBox(width: 6),
                    Text('Subscription: $subscriptionStatus',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors[1])),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _isProcessing = false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isExpired ? Colors.red.shade600 : gold,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              final result = await AttendanceService.recordCheckIn(
                qrCode: qrId,
                status: isExpired ? 'Late' : 'Present',
              );

              if (!mounted) return;

              if (result['success'] == true) {
                setState(() {
                  _lastCheckedInName = name;
                  _isProcessing = false;
                });
                _showSnack('$name checked in via QR');
              } else {
                setState(() => _isProcessing = false);
                _showSnack(result['message'] ?? 'Check-in failed', isError: true);
              }
            },
            child: Text(
              isExpired ? 'Check In Anyway' : 'Confirm Check-In',
              style: TextStyle(color: isExpired ? Colors.white : Colors.black87, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: AppTheme.cardDecoration(context, accent: AppColors.gold),
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.goldBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.qr_code_scanner, color: AppColors.gold, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Scan Member QR ID', style: AppTheme.sectionTitle(context)),
                      ),
                      IconButton(
                        tooltip: 'Toggle flash',
                        onPressed: () => _controller.toggleTorch(),
                        icon: Icon(Icons.flash_on_outlined, color: AppTheme.textMuted(context)),
                      ),
                      IconButton(
                        tooltip: 'Switch camera',
                        onPressed: () => _controller.switchCamera(),
                        icon: Icon(Icons.flip_camera_ios_outlined, color: AppTheme.textMuted(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Point the camera at a member's QR ID to check them in",
                      style: AppTheme.cardSubtitle(context)),
                  Expanded(
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Keep the preview square and never larger than the
                          // space the card gives it.
                          final side = scanBoxSize
                              .clamp(0.0, constraints.maxWidth)
                              .clamp(0.0, constraints.maxHeight);
                          return _buildCameraBox(side);
                        },
                      ),
                    ),
                  ),
                  if (_lastCheckedInName != null) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text('Last checked in: $_lastCheckedInName',
                          style: AppTheme.cardSubtitle(context)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraBox([double size = scanBoxSize]) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, _) => Center(
                child: Text(
                  'Error: ${error.toString()}\nPlease grant camera permission.',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: cyan, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
