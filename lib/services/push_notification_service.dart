import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app.dart';
import '../screens/adsb/adsb_chat_screen.dart';
import '../screens/owner/ticket_detail_screen.dart';
import 'session_service.dart';

class PushNotificationService {
  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _firestore = FirebaseFirestore.instance;

  static const _channelId = 'adsb_support_high';
  static const _channelName = 'ADSB Support';

  Future<void> initialize(String userEmail) async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _setupLocalNotifications();

    final safeKey = userEmail.replaceAll('.', '_');
    final token = await _fcm.getToken();
    if (token != null) {
      await _firestore.collection('fcm_tokens').doc(safeKey).set({
        'token': token,
        'email': userEmail,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    _fcm.onTokenRefresh.listen((newToken) async {
      await _firestore.collection('fcm_tokens').doc(safeKey).set({
        'token': newToken,
        'email': userEmail,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });

    // Handle FCM messages when app is foreground (background is auto-handled)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle FCM notification tap → opens chat/ticket
    FirebaseMessaging.onMessageOpenedApp.listen(_handleFCMPayload);

    // Handle the case where the app was launched from a notification tap
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      Future.delayed(const Duration(seconds: 2), () {
        _handleFCMPayload(initial);
      });
    }
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

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // Payload format: "ticketId|type"
    final parts = payload.split('|');
    final ticketId = parts.isNotEmpty ? parts[0] : '';
    final type = parts.length > 1 ? parts[1] : 'general';

    if (ticketId.isEmpty) return;
    _navigateFromPayload(ticketId, type);
  }

  /// Handles tapping an FCM push (system notification).
  Future<void> _handleFCMPayload(RemoteMessage message) async {
    final ticketId = message.data['ticket_id'] as String?;
    final type = message.data['type'] as String?;
    if (ticketId == null || ticketId.isEmpty) return;

    _navigateFromPayload(ticketId, type);
  }

  /// Loads current user, then routes to chat or ticket.
  Future<void> _navigateFromPayload(String ticketId, String? type) async {
    try {
      final nav = navigatorKey.currentState;
      if (nav == null) return;

      // Get current user from session
      final user = await SessionService().getUser();
      if (user == null) return;

      // Chat notifications → open chat directly
      if (type == 'chat_message') {
        nav.push(MaterialPageRoute(
          builder: (_) => AdsbChatScreen(
            ticketId: ticketId,
            user: user,
          ),
        ));
        return;
      }

      // Everything else → ticket detail
      nav.push(MaterialPageRoute(
        builder: (_) => TicketDetailScreen(
          ticketId: ticketId,
          user: user,
        ),
      ));
    } catch (e) {
      print('_navigateFromPayload error: $e');
    }
  }

  Future<void> showLocal({
    required String title,
    required String body,
    String? ticketId,
    String? type,
  }) async {
    // Encode both ticketId and type into the payload
    final payload = ticketId == null || ticketId.isEmpty
        ? null
        : '$ticketId|${type ?? 'general'}';

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
      payload: payload,
    );
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Foreground handled by AppNotificationListener — skip to avoid duplicates
  }
}