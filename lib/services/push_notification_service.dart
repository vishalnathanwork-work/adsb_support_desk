import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PushNotificationService {
  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _firestore = FirebaseFirestore.instance;

  static const _channelId = 'adsb_support_high';
  static const _channelName = 'ADSB Support';

  /// Initialize once after login.
  Future<void> initialize(String userEmail) async {
    // Request permission (iOS + Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android 13+ explicit runtime permission for notifications
    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _setupLocalNotifications();

    // Save FCM token — key matches Firestore rules
    // Rules expect email with dots replaced by underscores
    final safeKey = userEmail.replaceAll('.', '_');
    final token = await _fcm.getToken();
    if (token != null) {
      await _firestore.collection('fcm_tokens').doc(safeKey).set({
        'token': token,
        'email': userEmail,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    // Refresh token listener
    _fcm.onTokenRefresh.listen((newToken) async {
      await _firestore.collection('fcm_tokens').doc(safeKey).set({
        'token': newToken,
        'email': userEmail,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });

    // Foreground FCM (unused until Cloud Functions are set up)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Android channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Support chat and ticket updates',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Handle tap on a local notification.
  /// Payload is expected to be a ticket ID.
  void _onNotificationTap(NotificationResponse response) {
    final ticketId = response.payload;
    if (ticketId == null || ticketId.isEmpty) return;

    // Ignore for now — the notifications screen already deep-links.
    // Future: use a global navigator key to route directly to the ticket.
    print('Notification tapped: ticket=$ticketId');
  }

  /// Show a local notification immediately.
  Future<void> showLocal({
    required String title,
    required String body,
    String? ticketId,
  }) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Support chat and ticket updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: ticketId,
    );
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await showLocal(
      title: n.title ?? 'Notification',
      body: n.body ?? '',
      ticketId: message.data['ticket_id'],
    );
  }
}