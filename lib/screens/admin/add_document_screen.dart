import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/user.dart';
import '../../models/document.dart';
import '../../services/database_helper.dart';
import '../login_screen.dart';

class AddDocumentScreen extends StatefulWidget {
  final AppUser user;
  const AddDocumentScreen({super.key, required this.user});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _docType = 'Memo';
  bool _saving = false;
  bool _loadingUsers = true;
  String? _errorMessage;
  String? _selectedSenderUsername;

  List<AppUser> _allUsers = [];

  // Ordered list of selected office usernames.
  // Office 1 receives it first, then Office 2, etc. The LAST one is the
  // final destination/receiver. Each entry is a username (or null if not
  // yet picked) selected from the registered users dropdown.
  final List<String?> _officeSelections = [null];

  final _docTypes = ['Memo', 'Request Letter', 'Purchase Order', 'Contract', 'Report', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await DatabaseHelper.instance.getAllUsers();
    setState(() {
      _allUsers = users;
      _loadingUsers = false;
    });
  }

  void _addOfficeField() {
    setState(() => _officeSelections.add(null));
  }

  void _removeOfficeField(int index) {
    if (_officeSelections.length == 1) return; // always keep at least one
    setState(() => _officeSelections.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final officeOrder = _officeSelections
        .where((v) => v != null && v.isNotEmpty)
        .map((v) => v!)
        .toList();

    if (officeOrder.isEmpty) {
      setState(() => _errorMessage = 'Add at least one office to route this document to.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final qrCode = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    final doc = TrackedDocument(
      qrCode: qrCode,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      documentType: _docType,
      status: 'Pending',
      currentHolder: officeOrder.first,
      createdBy: widget.user.username,
      senderName: _selectedSenderUsername ?? '',
      createdAt: now,
    );

    try {
      await DatabaseHelper.instance.addDocumentWithRoute(doc, officeOrder);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG addDocumentWithRoute error: $e');
      setState(() => _errorMessage = 'Failed to save document: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      labelStyle: const TextStyle(color: AppColors.maroon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.gold.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.maroon, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Add New Document'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _loadingUsers
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(color: AppColors.maroon),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _selectedSenderUsername,
                    decoration: _fieldDecoration(
                      'Sender (optional)',
                      helperText: 'The account of the person who submitted this document — they\'ll get notified as it moves',
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('— None —')),
                      ..._allUsers.map((u) => DropdownMenuItem<String>(
                            value: u.username,
                            child: Text('${u.fullName} (${u.username})'),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selectedSenderUsername = v),
                  ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              decoration: _fieldDecoration('Document Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _docType,
              decoration: _fieldDecoration('Document Type'),
              items: _docTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _docType = v ?? _docType),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descController,
              decoration: _fieldDecoration('Description (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            const Text('Routing Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.maroonDark)),
            const Text(
              'Add offices in the order they must receive and sign this document. '
              'The last office listed is the final destination/receiver.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),

            if (_loadingUsers)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(color: AppColors.maroon),
              )
            else
              ..._officeSelections.asMap().entries.map((entry) {
                final index = entry.key;
                final selected = entry.value;
                final isLast = index == _officeSelections.length - 1;

                // Usernames already picked in OTHER slots, so the same
                // office can't accidentally be selected twice in the route.
                final takenElsewhere = _officeSelections
                    .asMap()
                    .entries
                    .where((e) => e.key != index && e.value != null)
                    .map((e) => e.value)
                    .toSet();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.maroon,
                        child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selected,
                          isExpanded: true,
                          decoration: _fieldDecoration(
                            isLast ? 'Office ${index + 1} (final receiver)' : 'Office ${index + 1}',
                          ).copyWith(isDense: true),
                          items: _allUsers
                              .where((u) => !takenElsewhere.contains(u.username))
                              .map((u) => DropdownMenuItem<String>(
                                    value: u.username,
                                    child: Text(
                                      '${u.fullName} (${u.username})'
                                      '${u.department.isNotEmpty ? ' — ${u.department}' : ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          validator: (v) {
                            // Only the first office is strictly required;
                            // later empty slots just get dropped in _save().
                            if (index == 0 && (v == null || v.isEmpty)) {
                              return 'Select an office';
                            }
                            return null;
                          },
                          onChanged: (v) => setState(() => _officeSelections[index] = v),
                        ),
                      ),
                      if (_officeSelections.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeOfficeField(index),
                        ),
                    ],
                  ),
                );
              }),

            TextButton.icon(
              onPressed: _loadingUsers ? null : _addOfficeField,
              style: TextButton.styleFrom(foregroundColor: AppColors.maroon),
              icon: const Icon(Icons.add),
              label: const Text('Add another office'),
            ),

            const SizedBox(height: 20),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.qr_code),
                label: Text(_saving ? 'Saving...' : 'Create Document & Generate QR', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
