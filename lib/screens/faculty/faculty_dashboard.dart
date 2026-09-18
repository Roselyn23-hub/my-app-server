import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/document.dart';
import '../../services/database_helper.dart';
import '../login_screen.dart';
import '../shared/qr_scanner_screen.dart';
import '../shared/document_detail_screen.dart';
import '../shared/notifications_screen.dart';
import '../../models/app_notification.dart';

class FacultyDashboard extends StatefulWidget {
  final AppUser user;
  const FacultyDashboard({super.key, required this.user});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  List<TrackedDocument> _inbox = [];
  List<TrackedDocument> _history = [];
  bool _loading = true;

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
    // Take the user straight into the scanner right after login. They land
    // back here (with the lists underneath) if they cancel the scan or after
    // viewing a scanned document.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final inbox = await DatabaseHelper.instance.getDocumentsForUser(widget.user.username);
    final history = await DatabaseHelper.instance.getHandledDocumentsForUser(widget.user.username);
    setState(() {
      _inbox = inbox;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _scan() async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => QrScannerScreen(user: widget.user)));
    if (!mounted) return;
    _load();
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _docCard(TrackedDocument doc) {
    final color = _statusColors[doc.status] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(Icons.description_outlined, color: color),
        ),
        title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(doc.documentType),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(doc.status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => DocumentDetailScreen(user: widget.user, qrCode: doc.qrCode)));
          _load();
        },
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 60, color: AppColors.maroon.withOpacity(0.35)),
        const SizedBox(height: 12),
        Center(child: Text(title, style: const TextStyle(color: Colors.grey))),
        Center(child: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: Text('Welcome, ${widget.user.fullName.split(' ').first}'),
          backgroundColor: AppColors.maroon,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            StreamBuilder<List<AppNotification>>(
              stream: DatabaseHelper.instance.notificationsStreamForUser(widget.user.username),
              builder: (context, snapshot) {
                final unread = (snapshot.data ?? []).where((n) => !n.isRead).length;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NotificationsScreen(user: widget.user)),
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(color: AppColors.maroonDark, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Inbox'),
              Tab(text: 'History'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _scan,
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.maroonDark,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan Document', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.maroon))
            : TabBarView(
                children: [
                  // Inbox — documents currently sitting with this user.
                  RefreshIndicator(
                    color: AppColors.maroon,
                    onRefresh: _load,
                    child: _inbox.isEmpty
                        ? _emptyState(
                            Icons.inbox_outlined,
                            'No documents assigned to you yet.',
                            'Scan a QR code to receive a document.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                            itemCount: _inbox.length,
                            itemBuilder: (context, i) => _docCard(_inbox[i]),
                          ),
                  ),
                  // History — documents this user has already handled,
                  // even after they've moved on to the next office.
                  RefreshIndicator(
                    color: AppColors.maroon,
                    onRefresh: _load,
                    child: _history.isEmpty
                        ? _emptyState(
                            Icons.history,
                            'Nothing handled yet.',
                            'Documents you\'ve received will show up here.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                            itemCount: _history.length,
                            itemBuilder: (context, i) => _docCard(_history[i]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
