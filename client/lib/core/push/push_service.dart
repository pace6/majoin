import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import '../config.dart';

const _channelId = 'majoin-messages';
const _channelName = 'Messages';

/// Background isolate handler for FCM data messages (app killed/background).
///
/// Runs in its own isolate with no access to the live [Client], so it only
/// pops a generic notification. `event_id_only` push format means the real
/// content is fetched by the app on next launch / foreground sync.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    return;
  }
  final local = FlutterLocalNotificationsPlugin();
  await local.show(
    message.hashCode,
    AppConfig.appName,
    'New message',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: message.data['room_id'] as String?,
  );
}

/// Notification wiring.
///
/// Two layers:
///   1. Local notifications driven by the live `/sync` stream — covers the
///      app-running case on every platform (incl. desktop).
///   2. FCM remote push relayed through sygnal — covers app background/killed
///      on Android & iOS. Requires google-services.json / GoogleService-Info
///      .plist; without them FCM init fails gracefully and layer 1 still works.
///      See docs/push-setup.md.
class PushService {
  PushService(this._client, this._navKey);

  final Client _client;
  final GlobalKey<NavigatorState> _navKey;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );
    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _client.onTimelineEvent.stream.listen(_onTimelineEvent);

    await _initFcm();
  }

  // ---- FCM remote push -----------------------------------------------------

  Future<void> _initFcm() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // No Firebase config bundled — stay on local-only notifications.
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final token = await messaging.getToken();
    if (token != null) await _registerPusher(token);
    messaging.onTokenRefresh.listen(_registerPusher);

    // Foreground FCM messages: the live /sync stream + _onTimelineEvent
    // already surface these, so nothing extra is needed here.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final roomId = message.data['room_id'] as String?;
      if (roomId != null) _openRoom(roomId);
    });
  }

  Future<void> _registerPusher(String token) => registerRemotePusher(
        token: token,
        appId: Platform.isAndroid ? AppConfig.fcmAppId : AppConfig.apnsAppId,
        pushGatewayUrl: AppConfig.pushGatewayUrl,
      );

  /// Register an HTTP pusher with the homeserver so sygnal relays pushes to
  /// this device. Safe to call repeatedly — `append: false` replaces.
  Future<void> registerRemotePusher({
    required String token,
    required String appId,
    required String pushGatewayUrl,
  }) async {
    if (kIsWeb) return;
    await _client.postPusher(
      Pusher(
        pushkey: token,
        appId: appId,
        kind: 'http',
        appDisplayName: AppConfig.appName,
        deviceDisplayName: Platform.operatingSystem,
        lang: _platformLang(),
        data: PusherData(
          url: Uri.parse(pushGatewayUrl),
          format: 'event_id_only',
        ),
      ),
      append: false,
    );
  }

  // ---- Local notifications -------------------------------------------------

  Future<void> _onTimelineEvent(Event e) async {
    if (e.senderId == _client.userID) return;
    if (e.type != 'm.room.message' &&
        e.type != 'm.sticker' &&
        e.type != 'app.majoin.flex') {
      return;
    }
    // Don't notify for the room the user is currently looking at.
    if (_isRoomOpen(e.room.id)) return;

    final body = e.body.isNotEmpty
        ? e.body
        : (e.type == 'm.sticker' ? '[sticker]' : '[message]');
    final title = e.room.getLocalizedDisplayname();

    await _local.show(
      e.room.id.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
      payload: e.room.id,
    );
  }

  // ---- Navigation ----------------------------------------------------------

  void _onNotificationTap(NotificationResponse response) {
    final roomId = response.payload;
    if (roomId != null && roomId.isNotEmpty) _openRoom(roomId);
  }

  void _openRoom(String roomId) {
    final ctx = _navKey.currentContext;
    if (ctx == null) return;
    ctx.push('/rooms/${Uri.encodeComponent(roomId)}');
  }

  bool _isRoomOpen(String roomId) {
    final ctx = _navKey.currentContext;
    if (ctx == null) return false;
    // GoRouterState.of needs a context under a route builder; the nav key's
    // context is the root Navigator, so read the location off the router.
    final location = GoRouter.of(ctx)
        .routerDelegate
        .currentConfiguration
        .uri
        .toString();
    return location.contains(Uri.encodeComponent(roomId));
  }

  String _platformLang() {
    try {
      return Platform.localeName.split('.').first;
    } catch (_) {
      return 'en';
    }
  }
}
