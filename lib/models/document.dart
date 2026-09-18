class TrackedDocument {
  final int? id;
  final String qrCode; // unique code embedded in the QR image
  final String title;
  final String description;
  final String documentType;
  String status; // Pending, In-Transit, Received, Approved, Completed, Rejected
  String currentHolder; // username of the office/person who needs to act next
  final String createdBy; // app user (usually admin) who registered this document
  final String senderName; // external sender's name — not an app account
  final String senderPhone; // external sender's phone number, for SMS updates (e.g. +639171234567)
  final String createdAt;

  TrackedDocument({
    this.id,
    required this.qrCode,
    required this.title,
    required this.description,
    required this.documentType,
    required this.status,
    required this.currentHolder,
    required this.createdBy,
    this.senderName = '',
    this.senderPhone = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'qrCode': qrCode,
      'title': title,
      'description': description,
      'documentType': documentType,
      'status': status,
      'currentHolder': currentHolder,
      'createdBy': createdBy,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'createdAt': createdAt,
    };
  }

  factory TrackedDocument.fromMap(Map<String, dynamic> map) {
    return TrackedDocument(
      id: map['id'] as int?,
      qrCode: map['qrCode'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      documentType: map['documentType'] as String? ?? 'General',
      status: map['status'] as String,
      currentHolder: map['currentHolder'] as String,
      createdBy: map['createdBy'] as String,
      senderName: map['senderName'] as String? ?? '',
      senderPhone: map['senderPhone'] as String? ?? '',
      createdAt: map['createdAt'] as String,
    );
  }
}

class TrackingLog {
  final int? id;
  final String qrCode; // links back to the document
  final String action; // e.g. Created, Received, Forwarded, Approved, Rejected
  final String performedBy;
  final String? forwardedTo;
  final String notes;
  final String timestamp;

  TrackingLog({
    this.id,
    required this.qrCode,
    required this.action,
    required this.performedBy,
    this.forwardedTo,
    this.notes = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'qrCode': qrCode,
      'action': action,
      'performedBy': performedBy,
      'forwardedTo': forwardedTo,
      'notes': notes,
      'timestamp': timestamp,
    };
  }

  factory TrackingLog.fromMap(Map<String, dynamic> map) {
    return TrackingLog(
      id: map['id'] as int?,
      qrCode: map['qrCode'] as String,
      action: map['action'] as String,
      performedBy: map['performedBy'] as String,
      forwardedTo: map['forwardedTo'] as String?,
      notes: map['notes'] as String? ?? '',
      timestamp: map['timestamp'] as String,
    );
  }
}

/// One required stop in a document's signatory route.
/// e.g. step 1 = office1 (Pending), step 2 = office3 (Pending), step 3 = office5 (Pending)
/// Each step must be completed in order before the next office can act.
class RouteStep {
  final int? id;
  final String qrCode;
  final int stepOrder; // 1, 2, 3...
  final String assignedTo; // username of the office/person for this step
  final String status; // 'Pending' or 'Completed'
  final String? completedAt;

  RouteStep({
    this.id,
    required this.qrCode,
    required this.stepOrder,
    required this.assignedTo,
    required this.status,
    this.completedAt,
  });

  factory RouteStep.fromMap(Map<String, dynamic> map) {
    return RouteStep(
      id: map['id'] as int?,
      qrCode: map['qr_code'] as String,
      stepOrder: map['step_order'] as int,
      assignedTo: map['assigned_to'] as String,
      status: map['status'] as String,
      completedAt: map['completed_at'] as String?,
    );
  }
}
