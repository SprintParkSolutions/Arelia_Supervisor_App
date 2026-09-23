import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';
import 'push_backend.dart';
import 'storage_service.dart';

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();
  static const channelId = 'arelia_updates_v1';
  static const silentChannelId = 'arelia_updates_silent_v1';
  final _local = FlutterLocalNotificationsPlugin();
  final status = ValueNotifier<String>('Notification setup pending');
  final openInboxRequested = ValueNotifier<bool>(false);
  bool _localReady = false;
  bool _firebaseReady = false;
  bool _starting = false;
  bool _permissionGranted = false;
  String? _token;

  Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _openLocal(response.payload),
      );
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          'Arelia updates',
          description: 'Salesforce updates and email alerts',
          importance: Importance.high,
          playSound: true,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          silentChannelId,
          'Arelia updates (silent)',
          description: 'Updates without sound',
          importance: Importance.high,
          playSound: false,
        ),
      );
      _localReady = true;
      NotificationService.instance.onSystemNotification = show;
      NotificationService.instance.onSystemClear = cancel;
      NotificationService.instance.onSystemClearAll = _local.cancelAll;
      NotificationService.instance.onSoundChanged = (_) => _register();
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _openLocal(launch?.notificationResponse?.payload);
      }
      status.value =
          'Popups available. Locked-phone delivery awaits push setup.';
    } catch (_) {
      status.value =
          'System notification setup failed. Retry enabling notifications.';
    }
    if (!PushBackend.firebaseEnabled || _firebaseReady) return;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      // Local notifications provide one consistent foreground banner on both OSes.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
      FirebaseMessaging.onMessage.listen(
        (message) => _receive(message, popup: true),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _receive(message, popup: false, open: true),
      );
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) {
          _token = token;
          unawaited(_register());
        },
        onError: (Object _) {
          status.value =
              'Push token unavailable. Retry enabling notifications.';
        },
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _receive(initial, popup: false, open: true);
      StorageService.beforeLogout = disconnect;
    } catch (_) {
      status.value =
          'Popups available. Firebase push configuration is missing or invalid.';
    }
  }

  Future<void> start() async {
    if (_starting || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    _starting = true;
    try {
      if (!_localReady || (PushBackend.firebaseEnabled && !_firebaseReady)) {
        await initialize();
      }
      bool granted;
      if (_firebaseReady) {
        final permission = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        granted =
            permission.authorizationStatus == AuthorizationStatus.authorized ||
            permission.authorizationStatus == AuthorizationStatus.provisional;
      } else if (Platform.isAndroid) {
        granted =
            await _local
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      } else {
        granted =
            await _local
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      _permissionGranted = granted;
      if (!granted) {
        status.value =
            'Notifications are blocked. Enable them in phone Settings.';
        return;
      }
      if (!_firebaseReady) {
        status.value =
            'Phone popups enabled. Locked-phone delivery awaits Firebase push setup.';
        return;
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      if (Platform.isIOS &&
          await FirebaseMessaging.instance.getAPNSToken() == null) {
        status.value =
            'Waiting for Apple push registration. Retry enabling notifications.';
        return;
      }
      _token = await FirebaseMessaging.instance.getToken();
      if (_token == null) throw StateError('No Firebase device token');
      if (!PushBackend.enabled) {
        status.value =
            'Firebase connected. Automatic Salesforce push delivery still needs the server connection.';
        return;
      }
      await _register();
      // Retry registration on inbox refresh/resume and sync missed, unopened alerts.
      NotificationService.instance.fetchRemote = (cursor) async {
        await _register();
        return PushBackend.events(cursor);
      };
      await NotificationService.instance.refresh();
    } catch (_) {
      status.value = 'Push setup could not finish. Check connection and retry.';
    } finally {
      _starting = false;
    }
  }

  Future<void> _register() async {
    if (!PushBackend.enabled ||
        !_firebaseReady ||
        _token == null ||
        await StorageService.getAccessToken() == null) {
      return;
    }
    try {
      await PushBackend.register(
        _token!,
        Platform.isIOS ? 'ios' : 'android',
        NotificationService.instance.soundEnabled,
      );
      status.value =
          'Push notifications enabled. Phone notification settings apply.';
    } catch (_) {
      status.value =
          'Phone popups enabled; Salesforce push registration is unavailable.';
    }
  }

  void _openLocal(String? payload) {
    if (payload != null) {
      try {
        final event = parsePushEvent(
          Map<String, dynamic>.from(jsonDecode(payload) as Map),
        );
        if (event != null) {
          NotificationService.instance.enqueueRemote(event, popup: false);
        }
      } catch (_) {
        /* Older notifications only contain an ID. */
      }
    }
    openInboxRequested.value = true;
  }

  /// OS-scheduled display test; does not claim to test remote Salesforce delivery.
  Future<void> scheduleTestPopup() async {
    await start();
    if (!_localReady || !_permissionGranted) {
      throw StateError('Allow notifications in phone Settings before testing.');
    }
    final when = DateTime.now().toUtc().add(const Duration(seconds: 30));
    final event = <String, dynamic>{
      'id': 'local-popup-test:${when.microsecondsSinceEpoch}',
      'title': 'Arelia notification test',
      'body':
          'Tap to open your notification inbox. This is a display test, not a Salesforce update.',
      'source': 'Test',
      'time': when.toIso8601String(),
    };
    await _local.zonedSchedule(
      systemNotificationId(event['id'] as String),
      event['title'] as String,
      event['body'] as String,
      tz.TZDateTime.from(when, tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Arelia updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notification',
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode(event),
    );
  }

  Future<void> copyTestDeviceToken() async {
    if (!PushBackend.testMode) {
      throw StateError('Firebase test mode is not enabled.');
    }
    await start();
    if (_token == null) {
      throw StateError('Configure Firebase and allow notifications first.');
    }
    await Clipboard.setData(ClipboardData(text: _token!));
  }

  void _receive(
    RemoteMessage message, {
    required bool popup,
    bool open = false,
  }) {
    final event =
        parsePushEvent(message.data) ??
        (PushBackend.testMode && message.notification != null
            ? parsePushEvent({
                'id':
                    'firebase-test:${message.messageId ?? DateTime.now().microsecondsSinceEpoch}',
                'title':
                    message.notification!.title ?? 'Firebase test notification',
                'body':
                    message.notification!.body ??
                    'Tap to open your notification inbox.',
                'source': 'Test',
                'time': (message.sentTime ?? DateTime.now())
                    .toUtc()
                    .toIso8601String(),
              })
            : null);
    if (event != null) {
      NotificationService.instance.enqueueRemote(event, popup: popup);
      // Cold-start events remain queued until the authenticated home screen starts.
      if (!open) unawaited(NotificationService.instance.refresh());
    }
    if (open) openInboxRequested.value = true;
  }

  Future<void> show(Map<String, dynamic> event, bool sound) async {
    if (!_localReady) return;
    await _local.show(
      systemNotificationId(event['id'] as String),
      event['title'] as String,
      event['body'] as String,
      NotificationDetails(
        android: AndroidNotificationDetails(
          sound ? channelId : silentChannelId,
          sound ? 'Arelia updates' : 'Arelia updates (silent)',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          playSound: sound,
          icon: 'ic_stat_notification',
          styleInformation: BigTextStyleInformation(event['body'] as String),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: sound,
        ),
      ),
      payload: jsonEncode(event),
    );
  }

  Future<void> cancel(String eventId) async {
    if (!_localReady) return;
    await _local.cancel(systemNotificationId(eventId));
    // FCM notification payloads use id=0 with the sender's explicit event tag.
    if (Platform.isAndroid) await _local.cancel(0, tag: eventId);
    if (Platform.isIOS) {
      await const MethodChannel(
        'arelia/push',
      ).invokeMethod<void>('cancelRemote', eventId);
    }
  }

  Future<void> disconnect() async {
    final token = _token;
    if (PushBackend.enabled && token != null) {
      try {
        await PushBackend.unregister(token);
      } catch (_) {
        /* Token deletion below revokes device delivery. */
      }
    }
    if (_firebaseReady) {
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseMessaging.instance.deleteToken();
    }
    _token = null;
    NotificationService.instance.fetchRemote = null;
    await _local.cancelAll();
  }
}
