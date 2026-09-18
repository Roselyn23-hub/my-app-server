import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'dart:typed_data';
import '../../models/user.dart';
import '../../models/document.dart';
import '../../services/database_helper.dart';
import '../../utils/qr_payload.dart';
import '../login_screen.dart';
import 'route_timeline.dart';

class DocumentDetailScreen extends StatefulWidget {
  final AppUser user;
  final String qrCode;
  const DocumentDetailScreen({super.key, required this.user, required this.qrCode});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  TrackedDocument? _doc;
  List<TrackingLog> _logs = [];
  List<RouteStep> _route = [];
  bool _loading = true;
  bool _receiving = false;

  // Guards against auto-receiving more than once per screen visit (e.g. on
  // pull-to-refresh after it's already been received).
  bool _autoReceiveAttempted = false;

  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;

  static const _statusColors = {
    'Pending': Colors.orange,
    'In-Transit': Colors.blue,
    'Received': Colors.teal,
    'Approved': Colors.green,
    'Completed': Colors.green,
    'Rejected': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final doc = await DatabaseHelper.instance.getDocumentByQr(widget.qrCode);
    final logs = await DatabaseHelper.instance.getLogsForDocument(widget.qrCode);
    final route = await DatabaseHelper.instance.getRouteForDocument(widget.qrCode);
    setState(() {
      _doc = doc;
      _logs = logs;
      _route = route;
      _loading = false;
    });

    // If it's this user's turn to receive it, store it into their dashboard
    // automatically the moment they view it — no extra tap required.
    final isHolder = doc != null && doc.currentHolder == widget.user.username;
    if (isHolder && !_autoReceiveAttempted) {
      _autoReceiveAttempted = true;
      await _receiveDocument(silent: false);
    }
  }

  Future<void> _receiveDocument({bool silent = false}) async {
    setState(() => _receiving = true);
    final message = await DatabaseHelper.instance.receiveDocument(widget.qrCode, widget.user.username);
    if (!mounted) return;
    setState(() => _receiving = false);
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.maroonDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // Refresh the doc/logs/route in place (without re-triggering auto-receive).
    final doc = await DatabaseHelper.instance.getDocumentByQr(widget.qrCode);
    final logs = await DatabaseHelper.instance.getLogsForDocument(widget.qrCode);
    final route = await DatabaseHelper.instance.getRouteForDocument(widget.qrCode);
    if (!mounted) return;
    setState(() {
      _doc = doc;
      _logs = logs;
      _route = route;
    });
  }

  Future<void> _saveQrToGallery() async {
    setState(() => _isSaving = true);
    try {
      final Uint8List? imageBytes = await _screenshotController.capture();
      if (imageBytes == null) throw Exception('Could not capture QR image');

      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) throw Exception('Gallery permission denied');

      await Gal.putImageBytes(imageBytes, name: 'qr_${DateTime.now().millisecondsSinceEpoch}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('QR code saved to gallery'),
            backgroundColor: AppColors.maroonDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.maroon)),
      );
    }
    final doc = _doc;
    if (doc == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('Document Details'),
          backgroundColor: AppColors.maroon,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: Text('Document not found.', style: TextStyle(color: Colors.grey))),
      );
    }

    final color = _statusColors[doc.status] ?? Colors.grey;
    final hasRoute = _route.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Document Details'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.maroon,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_receiving)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    color: AppColors.maroon,
                    backgroundColor: Color(0xFFEFE2C6),
                  ),
                ),
              ),

            // QR card
            Center(
              child: Screenshot(
                controller: _screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.maroon.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: QrPayload(
                      id: doc.qrCode,
                      title: doc.title,
                      documentType: doc.documentType,
                      createdBy: doc.createdBy,
                      createdAt: doc.createdAt,
                      route: _route.map((r) => r.assignedTo).toList(),
                    ).encode(),
                    size: 180,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.maroonDark),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.maroonDark,
                    ),
                  ),
                ),
              ),
            ),

            if (widget.user.role == 'admin') ...[
              const SizedBox(height: 14),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveQrToGallery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.maroonDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  icon: const Icon(Icons.download),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save QR to Gallery',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Title + status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.maroonDark),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(doc.status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  _infoRow('Type', doc.documentType),
                  if (doc.senderName.isNotEmpty) _infoRow('Submitted by', doc.senderName),
                  _infoRow('Description', doc.description.isEmpty ? '—' : doc.description),
                  _infoRow('Current holder', doc.currentHolder),
                  _infoRow('Created by', doc.createdBy),
                  _infoRow('QR code ID', doc.qrCode),
                ],
              ),
            ),

            if (hasRoute) ...[
              const SizedBox(height: 24),
              _sectionHeader('Signing Route', Icons.alt_route),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withOpacity(0.25)),
                ),
                child: RouteTimeline(doc: doc, route: _route),
              ),
            ],

            const SizedBox(height: 24),
            _sectionHeader('Tracking History', Icons.history),
            const SizedBox(height: 8),
            if (_logs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withOpacity(0.25)),
                ),
                child: const Center(
                  child: Text('No activity yet.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ..._logs.map((log) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.gold.withOpacity(0.25)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.maroon.withOpacity(0.12),
                        child: const Icon(Icons.history, color: AppColors.maroon, size: 20),
                      ),
                      title: Text(
                        '${log.action} by ${log.performedBy}'
                        '${log.forwardedTo != null ? " → ${log.forwardedTo}" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(_formatDate(log.timestamp)),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.maroon),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.maroonDark),
        ),
      ],
    );
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
