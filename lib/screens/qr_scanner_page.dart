import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

/// Standalone QR scanner screen — its own route/page (`/scan`), meant to be
/// opened in its own browser tab so it can sit on a second monitor while
/// the Attendance page stays usable elsewhere.
///
/// Flow:
///   1. Camera detects a QR code.
///   2. The page pops and returns the scanned value to the previous screen
///      (AttendancePage).
///   3. The AttendancePage handles the member lookup and confirmation.
///
/// The camera preview is intentionally small (just big enough for a QR
/// code to fill it) so a background image/design can show around it.
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  // Camera preview size — just big enough for a QR code to fit comfortably.
  static const double scanBoxSize = 260;

  // Same near-black navy as the sidebar rail, so the scanner matches the app.
  static const Color _rail = Color(0xFF111827);

  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

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

    // Set processing to true to prevent multiple scans.
    _isProcessing = true;

    // Pop the screen and return the scanned value.
    // Check if the widget is still mounted before navigating.
    if (mounted) Navigator.of(context).pop(value);
  }

  /// Round, softly tinted icon button used for the flash / camera actions.
  ButtonStyle get _actionStyle => IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _rail,
      appBar: AppBar(
        backgroundColor: _rail,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Scan Member QR ID',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle flash',
            style: _actionStyle,
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_outlined, size: 20),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Switch camera',
            style: _actionStyle,
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.flip_camera_ios_outlined, size: 20),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // Swap this for your own background image:
          // image: DecorationImage(
          //   image: AssetImage('assets/scanner_background.png'),
          //   fit: BoxFit.cover,
          // ),
          color: _rail,
        ),
        child: Center(
          child: _buildScannerPanel(),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.only(bottom: 24, top: 8),
        child: Text(
          'Point the camera at a member\'s QR ID',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xA6FFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Soft dark panel around the camera box (card-like, hairline border).
  Widget _buildScannerPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: _buildCameraBox(),
    );
  }

  Widget _buildCameraBox() {
    return SizedBox(
      width: scanBoxSize,
      height: scanBoxSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, _) { // Changed 'child' to '_' as it's unused
                return Center(
                  child: Text(
                    'Error: ${error.toString()}\nPlease grant camera permission.',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.cyan, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
