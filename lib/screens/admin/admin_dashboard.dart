import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/document.dart';
import '../../services/database_helper.dart';
import '../login_screen.dart';
import '../shared/qr_scanner_screen.dart';
import '../shared/document_detail_screen.dart';
import 'add_document_screen.dart';
import 'manage_users_screen.dart';

class AdminDashboard extends StatefulWidget {
  final AppUser user;
  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<TrackedDocument> _docs = [];
  bool _loading = true;
  String _filter = 'All';

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
    final docs = await DatabaseHelper.instance.getAllDocuments();
    setState(() {
      _docs = docs;
      _loading = false;
    });
  }

  List<TrackedDocument> get _filteredDocs =>
      _filter == 'All' ? _docs : _docs.where((d) => d.status == _filter).toList();

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ['All', 'Pending', 'In-Transit', 'Received', 'Approved', 'Completed', 'Rejected'];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.people_outline), tooltip: 'Manage Users', onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()));
            _load();
          }),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _logout),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'scan',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrScannerScreen(user: widget.user))).then((_) => _load()),
            backgroundColor: AppColors.maroonDark,
            foregroundColor: Colors.white,
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AddDocumentScreen(user: widget.user)));
              _load();
            },
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.maroonDark,
            icon: const Icon(Icons.add),
            label: const Text('New Document', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.maroon))
          : RefreshIndicator(
              color: AppColors.maroon,
              onRefresh: _load,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(child: _statCard('Total', _docs.length.toString(), AppColors.maroon)),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard('Pending', _docs.where((d) => d.status == 'Pending').length.toString(), Colors.orange.shade800)),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard('Completed', _docs.where((d) => d.status == 'Completed').length.toString(), Colors.green.shade700)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: statuses.map((s) {
                        final selected = _filter == s;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: selected,
                            selectedColor: AppColors.maroon,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : AppColors.maroonDark,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: AppColors.maroon.withOpacity(0.3)),
                            onSelected: (_) => setState(() => _filter = s),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _filteredDocs.isEmpty
                        ? const Center(child: Text('No documents found.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                            itemCount: _filteredDocs.length,
                            itemBuilder: (context, i) {
                              final doc = _filteredDocs[i];
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
                                  subtitle: Text('${doc.documentType} • Held by ${doc.currentHolder}'),
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
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
