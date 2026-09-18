import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/user.dart';
import '../../services/database_helper.dart';
import '../../utils/qr_payload.dart';
import '../login_screen.dart';
import 'document_detail_screen.dart';

class QrScannerScreen extends StatefulWidget {
  final AppUser user;
  const QrScannerScreen({super.key, required this.user});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _handled = false;
  final MobileScannerController _controller = MobileScannerController();
  bool _torchOn = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final barcode = capture.barcodes.firstOrNull;
    final scanned = barcode?.rawValue;
    if (scanned == null) return;

    _handled = true;

    // The QR now holds a JSON payload (title, type, route, etc.), but the
    // database lookup still only needs the document's ID — this also
    // transparently supports older QR codes that are just a bare ID.
    final code = QrPayload.decodeId(scanned);

    final doc = await DatabaseHelper.instance.getDocumentByQr(code);

    if (!mounted) return;

    if (doc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No document found for this QR code.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      setState(() => _handled = false);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(user: widget.user, qrCode: doc.qrCode),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Document QR Code'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Toggle flash',
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Dim overlay outside the scan box
          Container(color: Colors.black.withOpacity(0.35)),

          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold, width: 3),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Corner accents for a more "branded" scan frame
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  _corner(Alignment.topLeft),
                  _corner(Alignment.topRight),
                  _corner(Alignment.bottomLeft),
                  _corner(Alignment.bottomRight),
                ],
              ),
            ),
          ),

          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.maroonDark.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Point the camera at a document QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_handled)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.maroon,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text('Looking up document...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _corner(Alignment alignment) {
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    return Align(
      alignment: alignment,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: AppColors.gold, width: 5) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: AppColors.gold, width: 5) : BorderSide.none,
            left: isLeft ? const BorderSide(color: AppColors.gold, width: 5) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: AppColors.gold, width: 5) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
