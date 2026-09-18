import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'dart:typed_data';
import '../login_screen.dart';

class AdminQRScreen extends StatefulWidget {
  final String qrData; // the content to encode
  const AdminQRScreen({super.key, required this.qrData});

  @override
  State<AdminQRScreen> createState() => _AdminQRScreenState();
}

class _AdminQRScreenState extends State<AdminQRScreen> {
  final ScreenshotController screenshotController = ScreenshotController();
  bool isSaving = false;

  Future<void> _saveQRToGallery() async {
    setState(() => isSaving = true);
    try {
      final Uint8List? imageBytes = await screenshotController.capture();
      if (imageBytes == null) throw Exception("Could not capture QR image");

      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) throw Exception("Gallery permission denied");

      await Gal.putImageBytes(imageBytes, name: "qr_${DateTime.now().millisecondsSinceEpoch}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QR code saved to gallery")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e")),
        );
      }
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text("QR Code"),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Screenshot(
              controller: screenshotController,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withOpacity(0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: widget.qrData,
                  version: QrVersions.auto,
                  size: 250,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: isSaving ? null : _saveQRToGallery,
              icon: const Icon(Icons.download),
              label: Text(isSaving ? "Saving..." : "Save to Gallery", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
