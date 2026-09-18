import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/database_helper.dart';
import '../login_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await DatabaseHelper.instance.getAllUsers();
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  void _showAddUserDialog() {
    final usernameC = TextEditingController();
    final passwordC = TextEditingController();
    final nameC = TextEditingController();
    final deptC = TextEditingController();
    String role = 'staff';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add New User', style: TextStyle(color: AppColors.maroonDark, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  decoration: _dialogFieldDecoration('Full Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: usernameC,
                  decoration: _dialogFieldDecoration('Username'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordC,
                  decoration: _dialogFieldDecoration('Password'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: deptC,
                  decoration: _dialogFieldDecoration('Department'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: _dialogFieldDecoration('Role'),
                  items: const [
                    DropdownMenuItem(value: 'faculty', child: Text('Faculty')),
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.maroonDark),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (usernameC.text.trim().isEmpty || passwordC.text.trim().isEmpty || nameC.text.trim().isEmpty) {
                  return;
                }
                await DatabaseHelper.instance.addUser(AppUser(
                  username: usernameC.text.trim(),
                  password: passwordC.text.trim(),
                  fullName: nameC.text.trim(),
                  role: role,
                  department: deptC.text.trim(),
                ));
                if (!mounted) return;
                Navigator.pop(context);
                _load();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dialogFieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
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

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'faculty':
        return Icons.school;
      default:
        return Icons.badge;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.maroon;
      case 'faculty':
        return Colors.indigo;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.maroonDark,
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.maroon))
          : RefreshIndicator(
              color: AppColors.maroon,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _users.length,
                itemBuilder: (context, i) {
                  final u = _users[i];
                  final color = _roleColor(u.role);
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
                        child: Icon(_roleIcon(u.role), color: color),
                      ),
                      title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('@${u.username} • ${u.role.toUpperCase()}${u.department.isNotEmpty ? " • ${u.department}" : ""}'),
                      trailing: u.role == 'admin' && u.username == 'admin'
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                await DatabaseHelper.instance.deleteUser(u.id!);
                                _load();
                              },
                            ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
