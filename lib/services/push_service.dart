import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database_helper.dart';

/// Handles Firebase Cloud Messaging: requesting permission, registering this
/// device's token against the logged-in user, and showing a system
/// notification banner when a push arrives while the app is in the
/// foreground (FCM does not auto-display foreground notifications on
/// Android — flutter_local_notifications does that part).
class PushService {
  PushService._privateConstructor();
  static final PushService instance = PushService._privateConstructor();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'document_tracker_default',
    'Document Tracker Notifications',
    description: 'Updates when a document is routed to or received by you.',
    importance: Importance.high,
  );

  bool _initialized = false;

  /// Call once, early in main() after Firebase.initializeApp().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // ignore: avoid_print
    print('DEBUG PushService: permission status = ${settings.authorizationStatus}');

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(settings: initSettings);

    // App open and in the foreground when the push arrives — show it
    // manually so it looks the same as a background/closed-app push.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  /// Call right after a successful login. Gets this device's FCM token and
  /// saves it against the user's account so the send-push Edge Function
  /// knows where to deliver pushes for them.
  Future<void> registerTokenForUser(String username) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      // ignore: avoid_print
      print('DEBUG PushService: got token = $token');
      if (token == null) {
        // ignore: avoid_print
        print('DEBUG PushService: token was null, not saving.');
        return;
      }
      await DatabaseHelper.instance.saveFcmToken(username, token);
      // ignore: avoid_print
      print('DEBUG PushService: saved token for $username');
    } catch (e, st) {
      // ignore: avoid_print
      print('DEBUG PushService ERROR: $e');
      // ignore: avoid_print
      print(st);
    }

    // Keep it up to date if Firebase rotates the token later.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      DatabaseHelper.instance.saveFcmToken(username, newToken);
    });
  }
}
