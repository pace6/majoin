import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:matrix/matrix.dart';
import 'package:webrtc_interface/webrtc_interface.dart';
import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/room_ext.dart';
import 'call_screen.dart';

/// Implements [WebRTCDelegate] + owns the [VoIP] singleton.
class CallService implements WebRTCDelegate {
  CallService._(this._navKey);
  static CallService? _instance;
  static CallService get instance =>
      _instance ?? (throw StateError('CallService not initialized'));

  final GlobalKey<NavigatorState> _navKey;
  late final VoIP voip;

  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  Timer? _ringTimer;

  static Future<void> init(GlobalKey<NavigatorState> navKey) async {
    if (_instance != null) return;
    final svc = CallService._(navKey);
    svc.voip = VoIP(MatrixClientService.instance.client, svc);
    // Register before notification setup — notif init can throw on iOS, and a
    // missing ringtone notification must not leave CallService unusable.
    _instance = svc;
    try {
      await svc._notif.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
        ),
      );
    } catch (e) {
      debugPrint('CallService: notification init failed: $e');
    }
  }

  // ---- WebRTCDelegate ----

  @override
  MediaDevices get mediaDevices => rtc.navigator.mediaDevices;

  @override
  Future<RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration, [
    Map<String, dynamic> constraints = const {},
  ]) =>
      rtc.createPeerConnection(configuration, constraints);

  @override
  Future<void> playRingtone() async {
    // No bundled audio asset — pulse the system alert sound + haptics on a
    // repeating timer for the duration of ringing.
    _ringTimer?.cancel();
    void pulse() {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }

    pulse();
    _ringTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => pulse());
  }

  @override
  Future<void> stopRingtone() async {
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  @override
  Future<void> registerListeners(CallSession session) async {/* per-screen */}

  @override
  Future<void> handleNewCall(CallSession session) async {
    final navState = _navKey.currentState;
    if (navState == null) return;
    navState.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(session: session),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Future<void> handleCallEnded(CallSession session) async {
    await stopRingtone();
    final navState = _navKey.currentState;
    if (navState == null) return;
    if (navState.canPop()) navState.pop();
  }

  @override
  Future<void> handleMissedCall(CallSession session) async {
    await stopRingtone();
    await _notif.show(
      session.callId.hashCode,
      roomTitle(session.room),
      'call.missed'.tr,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'majoin-calls',
          'Calls',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> handleGroupCallEnded(GroupCallSession groupCall) async {}

  @override
  Future<void> handleNewGroupCall(GroupCallSession groupCall) async {}

  @override
  bool get canHandleNewCall => voip.currentCID == null;

  @override
  EncryptionKeyProvider? get keyProvider => null;

  @override
  bool get isWeb => false;

  // ---- Public helpers ----

  Future<void> startCall(Room room,
      {required String peer, required bool video}) async {
    await voip.inviteToCall(
      room,
      video ? CallType.kVideo : CallType.kVoice,
      userId: peer,
    );
  }
}
