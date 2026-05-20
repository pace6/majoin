import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matrix/matrix.dart';

/// Push wiring stub.
///
/// Production wiring (TODO):
///   - Android: firebase_messaging → register FCM token →
///     `registerRemotePusher(appId: 'app.majoin.android', ...)`
///   - iOS: APNs token via `firebase_messaging` →
///     `registerRemotePusher(appId: 'app.majoin.ios', ...)`
///   - Desktop: no remote push; rely on local notifications driven by /sync
///
/// For MVP we only set up local notifications + a /sync listener that pops a
/// notification for every incoming message the user did not send.
class PushService {
  PushService(this._client);
  final Client _client;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );
    await _local.initialize(init);

    _client.onTimelineEvent.stream.listen(_onTimelineEvent);
  }

  Future<void> _onTimelineEvent(Event e) async {
    if (e.senderId == _client.userID) return;
    if (e.type != 'm.room.message' &&
        e.type != 'm.sticker' &&
        e.type != 'app.majoin.flex') {
      return;
    }

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
          'majoin-messages',
          'Messages',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
    );
  }

  /// Stub: call from platform code once FCM/APNs token is acquired.
  Future<void> registerRemotePusher({
    required String token,
    required String appId, // app.majoin.android | app.majoin.ios
    required String pushGatewayUrl, // http://host:5000/_matrix/push/v1/notify
  }) async {
    if (kIsWeb) return;
    final lang = _platformLang();
    await _client.postPusher(
      Pusher(
        pushkey: token,
        appId: appId,
        kind: 'http',
        appDisplayName: 'Majoin',
        deviceDisplayName: Platform.operatingSystem,
        lang: lang,
        data: PusherData(
          url: Uri.parse(pushGatewayUrl),
          format: 'event_id_only',
        ),
      ),
      append: false,
    );
  }

  String _platformLang() {
    try {
      return Platform.localeName.split('.').first;
    } catch (_) {
      return 'en';
    }
  }
}
