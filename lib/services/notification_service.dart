import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel kayaChannel = AndroidNotificationChannel(
  'kaya_reminders',
  'Kaya Reminders',
  description: 'Notifications for meetings, contributions and loans',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // background handler
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _requestPermissions();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Notification tapped: ${message.messageId}');
    });

    if (!Platform.isMacOS) {
      final token = await _messaging.getToken();
      debugPrint('[FCM] Token: $token');
    }
  }

  static Future<void> registerDeviceForMember({
    required String memberId,
    required String chamaId,
  }) async {
    final token = await _messaging.getToken();

    if (token == null || token.trim().isEmpty) return;

    String platform = 'unknown';
    if (kIsWeb) {
      platform = 'web';
    } else if (Platform.isAndroid) {
      platform = 'android';
    } else if (Platform.isIOS) {
      platform = 'ios';
    } else if (Platform.isMacOS) {
      platform = 'macos';
    }

    debugPrint('[FCM] Registering device for member $memberId on $platform');

    await SupabaseService.saveDeviceToken(
      memberId: memberId,
      chamaId: chamaId,
      fcmToken: token,
      platform: platform,
    );

    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed');
      await SupabaseService.saveDeviceToken(
        memberId: memberId,
        chamaId: chamaId,
        fcmToken: newToken,
        platform: platform,
      );
    });
  }

  static Future<void> _requestPermissions() async {
    if (Platform.isMacOS) return; // skip on macOS — requires signing
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings();
    const macosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(settings: settings);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(kayaChannel);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await flutterLocalNotificationsPlugin.show(
      id: notification.hashCode,
      title: notification.title ?? 'Kaya',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'kaya_reminders',
          'Kaya Reminders',
          channelDescription:
              'Notifications for meetings, contributions and loans',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
