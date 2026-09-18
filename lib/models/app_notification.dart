class AppNotification {
  final int? id;
  final String recipient; // username who should see this
  final String qrCode; // links back to the document
  final String message;
  final bool isRead;
  final String createdAt;

  AppNotification({
    this.id,
    required this.recipient,
    required this.qrCode,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as int?,
      recipient: map['recipient'] as String,
      qrCode: map['qr_code'] as String,
      message: map['message'] as String,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: map['created_at'] as String,
    );
  }
}
