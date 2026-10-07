import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PushNotificationService {
  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _firestore = FirebaseFirestore.instance;

  static const _channelId = 'adsb_support_high';
  static const _channelName = 'ADSB Support';

  /// Initialize once after login
  Future<void> initialize(String userEmail) async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _setupLocalNotifications();

    // Save FCM token (optional, in case you enable Cloud Functions later)
    final token = await _fcm.getToken();
    if (token != null) {
      await _firestore.collection('fcm_tokens').doc(userEmail).set({
        'token': token,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    // Show notification if a remote FCM message arrives (unused for now)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  Future<void> _setupLocalNotifications() async {
    // Android init settings
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init settings
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combine into one settings object
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    // Initialize with named parameter `settings:`
    await _local.initialize(settings: initSettings);

    // Create Android channel
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

  /// Show a local notification immediately
  Future<void> showLocal({
    required String title,
    required String body,
    String? ticketId,
  }) async {
    // New API: everything is a named parameter
    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
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