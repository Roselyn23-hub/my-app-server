import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import '../models/document.dart';
import '../models/app_notification.dart';

// This class keeps the exact same name and method signatures as the old
// sqflite-based DatabaseHelper, so none of your screens need to change —
// only this file and main.dart change.
class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------- USERS ----------------

  Future<AppUser?> login(String username, String password) async {
    final result = await _client
        .from('users')
        .select()
        .eq('username', username)
        .eq('password', password)
        .maybeSingle();

    if (result == null) return null;
    return _userFromRow(result);
  }

  Future<int> addUser(AppUser user) async {
    final result = await _client.from('users').insert({
      'username': user.username,
      'password': user.password,
      'full_name': user.fullName,
      'role': user.role,
      'department': user.department,
    }).select().single();
    return result['id'] as int;
  }

  Future<List<AppUser>> getAllUsers() async {
    final result = await _client
        .from('users')
        .select()
        .order('role', ascending: true)
        .order('full_name', ascending: true);
    return (result as List).map((e) => _userFromRow(e)).toList();
  }

  Future<List<AppUser>> getUsersByRole(String role) async {
    final result = await _client.from('users').select().eq('role', role);
    return (result as List).map((e) => _userFromRow(e)).toList();
  }

  Future<int> deleteUser(int id) async {
    await _client.from('users').delete().eq('id', id);
    return 1;
  }

  /// Saves this device's FCM token against the user's account so the
  /// send-push Edge Function knows which device to notify.
  Future<void> saveFcmToken(String username, String token) async {
    await _client.from('users').update({'fcm_token': token}).eq('username', username);
  }

  AppUser _userFromRow(Map<String, dynamic> row) {
    return AppUser(
      id: row['id'] as int?,
      username: row['username'] as String,
      password: row['password'] as String,
      fullName: row['full_name'] as String,
      role: row['role'] as String,
      department: row['department'] as String? ?? '',
    );
  }

  // ---------------- DOCUMENTS ----------------

  Future<int> addDocument(TrackedDocument doc) async {
    final result = await _client.from('documents').insert({
      'qr_code': doc.qrCode,
      'title': doc.title,
      'description': doc.description,
      'document_type': doc.documentType,
      'status': doc.status,
      'current_holder': doc.currentHolder,
      'created_by': doc.createdBy,
      // sender_name column now stores the sender's USERNAME (a real
      // account), not free text — so we can notify them in-app.
      'sender_name': doc.senderName,
      'created_at': doc.createdAt,
    }).select().single();
    return result['id'] as int;
  }

  /// Creates a document AND its ordered signatory route in one go.
  /// [officeOrder] is the list of usernames in the order they must
  /// receive/sign the document, e.g. ['office1', 'office3', 'office5'].
  /// The last entry is the final destination/receiver.
  ///
  /// Notifies: the first office (needs to act now), the final destination
  /// office (heads-up it's coming), the creator (admin), and — if set —
  /// the sender's own account, since they now have app access too.
  Future<void> addDocumentWithRoute(
    TrackedDocument doc,
    List<String> officeOrder,
  ) async {
    if (officeOrder.isEmpty) {
      throw ArgumentError('officeOrder must have at least one office.');
    }

    final docToInsert = TrackedDocument(
      qrCode: doc.qrCode,
      title: doc.title,
      description: doc.description,
      documentType: doc.documentType,
      status: 'Pending',
      currentHolder: officeOrder.first,
      createdBy: doc.createdBy,
      senderName: doc.senderName,
      createdAt: doc.createdAt,
    );

    await addDocument(docToInsert);

    // Insert one route row per office, in order
    final routeRows = <Map<String, dynamic>>[];
    for (var i = 0; i < officeOrder.length; i++) {
      routeRows.add({
        'qr_code': doc.qrCode,
        'step_order': i + 1,
        'assigned_to': officeOrder[i],
        'status': 'Pending',
      });
    }
    await _client.from('document_routes').insert(routeRows);

    await addLog(TrackingLog(
      qrCode: doc.qrCode,
      action: 'Created',
      performedBy: doc.createdBy,
      forwardedTo: officeOrder.first,
      timestamp: doc.createdAt,
      notes: doc.senderName.isNotEmpty ? 'Submitted by: ${doc.senderName}' : '',
    ));

    // First office in the chain — needs to act now
    await addNotification(
      recipient: officeOrder.first,
      qrCode: doc.qrCode,
      message: 'New document "${doc.title}" needs your action.',
    );

    final finalOffice = officeOrder.last;

    // Let the final receiver know a document is on its way to them
    if (finalOffice != officeOrder.first) {
      await addNotification(
        recipient: finalOffice,
        qrCode: doc.qrCode,
        message: 'Document "${doc.title}" has been created and is being routed to you.',
      );
    }

    // Let the creator (admin) know it's started
    await addNotification(
      recipient: doc.createdBy,
      qrCode: doc.qrCode,
      message: 'Document "${doc.title}" is now with ${officeOrder.first}.',
    );

    // Let the sender (if they have an account) know it's started too
    if (doc.senderName.isNotEmpty &&
        doc.senderName != doc.createdBy &&
        doc.senderName != officeOrder.first) {
      await addNotification(
        recipient: doc.senderName,
        qrCode: doc.qrCode,
        message: 'Your document "${doc.title}" has been submitted and is now with ${officeOrder.first}.',
      );
    }
  }

  Future<List<TrackedDocument>> getAllDocuments() async {
    final result = await _client.from('documents').select().order('created_at', ascending: false);
    return (result as List).map((e) => _docFromRow(e)).toList();
  }

  Future<List<TrackedDocument>> getDocumentsForUser(String username) async {
    final result = await _client
        .from('documents')
        .select()
        .eq('current_holder', username)
        .order('created_at', ascending: false);
    return (result as List).map((e) => _docFromRow(e)).toList();
  }

  Future<TrackedDocument?> getDocumentByQr(String qrCode) async {
    final result = await _client.from('documents').select().eq('qr_code', qrCode).maybeSingle();
    if (result == null) return null;
    return _docFromRow(result);
  }

  /// Documents this user has already acted on (their step in the route is
  /// Completed), most recently handled first — even though the document
  /// may have since moved on to another office and no longer shows up in
  /// getDocumentsForUser. Used for a "History" view on the dashboard.
  Future<List<TrackedDocument>> getHandledDocumentsForUser(String username) async {
    final routeRows = await _client
        .from('document_routes')
        .select()
        .eq('assigned_to', username)
        .eq('status', 'Completed')
        .order('completed_at', ascending: false);

    final qrCodes = <String>[];
    for (final row in (routeRows as List)) {
      final code = row['qr_code'] as String;
      if (!qrCodes.contains(code)) qrCodes.add(code); // de-dupe, keep order
    }

    final docs = <TrackedDocument>[];
    for (final code in qrCodes) {
      final doc = await getDocumentByQr(code);
      if (doc != null) docs.add(doc);
    }
    return docs;
  }

  Future<int> updateDocumentStatus(String qrCode, String status, String newHolder) async {
    await _client
        .from('documents')
        .update({'status': status, 'current_holder': newHolder})
        .eq('qr_code', qrCode);
    return 1;
  }

  TrackedDocument _docFromRow(Map<String, dynamic> row) {
    return TrackedDocument(
      id: row['id'] as int?,
      qrCode: row['qr_code'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      documentType: row['document_type'] as String? ?? 'General',
      status: row['status'] as String,
      currentHolder: row['current_holder'] as String,
      createdBy: row['created_by'] as String,
      senderName: row['sender_name'] as String? ?? '',
      createdAt: row['created_at'] as String,
    );
  }

  // ---------------- TRACKING LOGS ----------------

  Future<int> addLog(TrackingLog log) async {
    final result = await _client.from('tracking_logs').insert({
      'qr_code': log.qrCode,
      'action': log.action,
      'performed_by': log.performedBy,
      'forwarded_to': log.forwardedTo,
      'notes': log.notes,
      'timestamp': log.timestamp,
    }).select().single();
    return result['id'] as int;
  }

  Future<List<TrackingLog>> getLogsForDocument(String qrCode) async {
    final result = await _client
        .from('tracking_logs')
        .select()
        .eq('qr_code', qrCode)
        .order('timestamp', ascending: false);
    return (result as List).map((e) => _logFromRow(e)).toList();
  }

  TrackingLog _logFromRow(Map<String, dynamic> row) {
    return TrackingLog(
      id: row['id'] as int?,
      qrCode: row['qr_code'] as String,
      action: row['action'] as String,
      performedBy: row['performed_by'] as String,
      forwardedTo: row['forwarded_to'] as String?,
      notes: row['notes'] as String? ?? '',
      timestamp: row['timestamp'] as String,
    );
  }

  // ---------------- DOCUMENT ROUTES (signatory chain) ----------------

  Future<List<RouteStep>> getRouteForDocument(String qrCode) async {
    final result = await _client
        .from('document_routes')
        .select()
        .eq('qr_code', qrCode)
        // IMPORTANT: the Supabase Dart client's .order() defaults to
        // ascending: false (descending). Without this explicit flag the
        // route came back as step 3 -> 2 -> 1 instead of 1 -> 2 -> 3,
        // which is what caused offices to appear swapped.
        .order('step_order', ascending: true);
    return (result as List).map((e) => RouteStep.fromMap(e)).toList();
  }

  /// Called when someone scans/opens a document and taps "Receive".
  /// Enforces that only the office whose turn it is can advance the
  /// document. On each step:
  ///   - the acting office's step is marked Completed
  ///   - the NEXT office (if any) gets notified it's their turn
  ///   - the FINAL office (the ultimate receiver) gets a progress update,
  ///     even if it's not their turn yet
  ///   - the document's creator (admin) gets a progress update
  ///   - the SENDER (if they have an account) gets a progress update too
  ///
  /// Returns a message describing what happened — show it to the user.
  Future<String> receiveDocument(String qrCode, String username) async {
    final route = await getRouteForDocument(qrCode);
    final doc = await getDocumentByQr(qrCode);

    if (route.isEmpty) {
      // No route was set up for this document — fall back to the old
      // single-holder behavior so nothing breaks for older documents.
      await updateDocumentStatus(qrCode, 'Received', username);
      await addLog(TrackingLog(
        qrCode: qrCode,
        action: 'Received',
        performedBy: username,
        timestamp: DateTime.now().toIso8601String(),
      ));
      return 'Document marked as received.';
    }

    RouteStep? nextStep;
    for (final step in route) {
      if (step.status == 'Pending') {
        nextStep = step;
        break;
      }
    }

    if (nextStep == null) {
      return 'This document has already completed its full routing.';
    }

    if (nextStep.assignedTo != username) {
      return 'This document is not yet assigned to you. '
          'It is currently waiting for: ${nextStep.assignedTo}.';
    }

    final now = DateTime.now().toIso8601String();
    final title = doc?.title ?? 'Document';
    final finalOffice = route.last.assignedTo;
    final senderUsername = doc?.senderName ?? '';

    // Mark this step complete
    await _client
        .from('document_routes')
        .update({'status': 'Completed', 'completed_at': now})
        .eq('id', nextStep.id as Object);

    await addLog(TrackingLog(
      qrCode: qrCode,
      action: 'Received',
      performedBy: username,
      timestamp: now,
    ));

    final progressMessage = 'Document "$title" is now at $username.';

    // Always let the creator (admin) know progress
    if (doc != null && doc.createdBy != username) {
      await addNotification(recipient: doc.createdBy, qrCode: qrCode, message: progressMessage);
    }

    // Let the sender (if they have an account) know progress too
    if (senderUsername.isNotEmpty && senderUsername != username && senderUsername != doc?.createdBy) {
      await addNotification(
        recipient: senderUsername,
        qrCode: qrCode,
        message: 'Your document "$title" is now at $username.',
      );
    }

    // Find the next pending step, if any
    RouteStep? followingStep;
    for (final step in route) {
      if (step.stepOrder > nextStep.stepOrder && step.status == 'Pending') {
        followingStep = step;
        break;
      }
    }

    if (followingStep != null) {
      await updateDocumentStatus(qrCode, 'In-Transit', followingStep.assignedTo);
      await addLog(TrackingLog(
        qrCode: qrCode,
        action: 'Forwarded',
        performedBy: username,
        forwardedTo: followingStep.assignedTo,
        timestamp: now,
      ));

      // Next office in line — needs to act
      await addNotification(
        recipient: followingStep.assignedTo,
        qrCode: qrCode,
        message: 'A document ("$title") has arrived and needs your action.',
      );

      // Final receiver gets a progress update too, if they're not the one acting now
      if (finalOffice != followingStep.assignedTo && finalOffice != username) {
        await addNotification(
          recipient: finalOffice,
          qrCode: qrCode,
          message: 'Document "$title" is now at $username, on its way to you.',
        );
      }

      return 'Received. Forwarded to ${followingStep.assignedTo}.';
    } else {
      // This was the last step — the document is fully done
      await updateDocumentStatus(qrCode, 'Completed', username);

      if (senderUsername.isNotEmpty) {
        await addNotification(
          recipient: senderUsername,
          qrCode: qrCode,
          message: 'Your document "$title" has been fully delivered and completed.',
        );
      }

      return 'Received. This document has completed its full routing.';
    }
  }

  // ---------------- NOTIFICATIONS ----------------

  Future<void> addNotification({
    required String recipient,
    required String qrCode,
    required String message,
  }) async {
    await _client.from('notifications').insert({
      'recipient': recipient,
      'qr_code': qrCode,
      'message': message,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<AppNotification>> getNotificationsForUser(String username) async {
    final result = await _client
        .from('notifications')
        .select()
        .eq('recipient', username)
        .order('created_at', ascending: false);
    return (result as List).map((e) => AppNotification.fromMap(e)).toList();
  }

  Future<int> getUnreadNotificationCount(String username) async {
    final result = await _client
        .from('notifications')
        .select()
        .eq('recipient', username)
        .eq('is_read', false);
    return (result as List).length;
  }

  Future<void> markNotificationRead(int id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllNotificationsRead(String username) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient', username)
        .eq('is_read', false);
  }

  /// Live stream of this user's notifications, newest first. Powers the
  /// bell badge and the notifications list — updates instantly (no manual
  /// refresh) whenever a new notification is inserted or one is marked
  /// read, via Supabase Realtime. Requires Realtime to be enabled for the
  /// `notifications` table in your Supabase project settings.
  Stream<List<AppNotification>> notificationsStreamForUser(String username) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient', username)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((e) => AppNotification.fromMap(e)).toList());
  }
}
