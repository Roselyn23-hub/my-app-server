import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/user.dart';
import '../../models/document.dart';
import '../../services/database_helper.dart';

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
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  String _docType = 'Memo';
  bool _saving = false;
  String? _errorMessage;

  // Ordered list of office/username text controllers.
  // Office 1 receives it first, then Office 2, etc. The LAST one is the
  // final destination/receiver.
  final List<TextEditingController> _officeControllers = [
    TextEditingController(),
  ];

  final _docTypes = ['Memo', 'Request Letter', 'Purchase Order', 'Contract', 'Report', 'Other'];

  void _addOfficeField() {
    setState(() => _officeControllers.add(TextEditingController()));
  }

  void _removeOfficeField(int index) {
    if (_officeControllers.length == 1) return; // always keep at least one
    setState(() {
      _officeControllers[index].dispose();
      _officeControllers.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final officeOrder = _officeControllers
        .map((c) => c.text.trim())
        .where((v) => v.isNotEmpty)
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
      senderName: _senderNameController.text.trim(),
      senderPhone: _senderPhoneController.text.trim(),
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
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    for (final c in _officeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Document')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _senderNameController,
              decoration: const InputDecoration(
                labelText: 'Sender name (external, optional)',
                helperText: 'For documents submitted by someone outside the school, e.g. an applicant or vendor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _senderPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Sender phone (optional, for SMS updates)',
                hintText: '+639171234567',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Document Title', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _docType,
              decoration: const InputDecoration(labelText: 'Document Type', border: OutlineInputBorder()),
              items: _docTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _docType = v ?? _docType),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            const Text('Routing Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text(
              'Add offices in the order they must receive and sign this document. '
              'The last office listed is the final destination/receiver.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),

            ..._officeControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              final isLast = index == _officeControllers.length - 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(radius: 14, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        textCapitalization: TextCapitalization.none,
                        decoration: InputDecoration(
                          labelText: isLast ? 'Office ${index + 1} username (final receiver)' : 'Office ${index + 1} username',
                          hintText: 'e.g. office1',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_officeControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeOfficeField(index),
                      ),
                  ],
                ),
              );
            }),

            TextButton.icon(
              onPressed: _addOfficeField,
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
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.qr_code),
                label: Text(_saving ? 'Saving...' : 'Create Document & Generate QR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
