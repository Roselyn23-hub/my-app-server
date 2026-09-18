import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/app_notification.dart';
import '../../services/database_helper.dart';
import 'document_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  final AppUser user;
  const NotificationsScreen({super.key, required this.user});

  String _formatDate(String iso) {
    try {
      return DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () => DatabaseHelper.instance.markAllNotificationsRead(user.username),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: DatabaseHelper.instance.notificationsStreamForUser(user.username),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.notifications_none, size: 60, color: Colors.grey),
                SizedBox(height: 12),
                Center(child: Text('No notifications yet.', style: TextStyle(color: Colors.grey))),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, i) {
              final n = notifications[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: n.isRead ? Colors.grey.shade200 : Colors.blue.withOpacity(0.15),
                  child: Icon(
                    n.isRead ? Icons.notifications_none : Icons.notifications_active,
                    color: n.isRead ? Colors.grey : Colors.blue,
                  ),
                ),
                title: Text(
                  n.message,
                  style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold),
                ),
                subtitle: Text(_formatDate(n.createdAt)),
                onTap: () async {
                  if (!n.isRead) {
                    await DatabaseHelper.instance.markNotificationRead(n.id!);
                  }
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentDetailScreen(user: user, qrCode: n.qrCode),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
