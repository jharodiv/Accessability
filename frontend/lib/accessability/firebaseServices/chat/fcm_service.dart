import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey;

  FCMService({required this.navigatorKey});

  Future<void> initializeFCMListeners() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create a notification channel for high importance notifications
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // Channel ID
      'High Importance Notifications', // Channel Name
      importance: Importance.high, // Set importance to high for heads-up notifications
      sound: RawResourceAndroidNotificationSound('default'), // Use default sound
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request notification permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');

      // Get the FCM token
      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token'); // Log the token

      // Listen for messages when the app is in the foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Foreground message received: ${message.notification?.title}');
        _showNotification(message);
      });

      // Handle messages when the app is in the background or terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('App opened from background: ${message.notification?.title}');
        _handleNotificationClick(message.data);
      });

      // Handle initial message when the app is launched from terminated state
      RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('App launched from terminated state: ${initialMessage.notification?.title}');
        _handleNotificationClick(initialMessage.data);
      }

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } else {
      print('User declined or has not accepted notification permissions');
    }
  }

  // Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Handling a background message: ${message.messageId}');
  }

  // Display a local notification
  Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high', 
      'High Importance Notifications', 
      importance: Importance.defaultImportance,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('default'), // Use default sound
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Generate a unique ID for the notification
    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _flutterLocalNotificationsPlugin.show(
      notificationId, // Use a unique ID
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
    );
  }

  // Handle notification click
  void _handleNotificationClick(Map<String, dynamic> data) {
    final String senderEmail = data['senderEmail'];
    final String senderID = data['senderID'];
    final String spaceId = data['spaceId'];

    if (spaceId != null) {
      // Navigate to the space chat room
      navigatorKey.currentState?.pushNamed(
        '/chatconvo',
        arguments: {
          'receiverUsername': 'Space Chat',
          'receiverID': spaceId,
          'isSpaceChat': true,
        },
      );
    } else {
      // Navigate to the private chat room
      navigatorKey.currentState?.pushNamed(
        '/chatconvo',
        arguments: {
          'receiverEmail': senderEmail,
          'receiverID': senderID,
        },
      );
    }
  }

  // Get the FCM token
  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }
}