import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan Member QR ID'),
        actions: [
          IconButton(
            tooltip: 'Toggle flash',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_outlined),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.flip_camera_ios_outlined),
          ),
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
          color: Color(0xFF0F172A), // placeholder background color
        ),
        child: Center(
          child: _buildCameraBox(),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.only(bottom: 24, top: 8),
        child: Text(
          'Point the camera at a member\'s QR ID',
           textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
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
                border: Border.all(color: const Color(0xFF14B8C6), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
