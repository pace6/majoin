import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:just_audio/just_audio.dart';
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

  // Looping ringtone for incoming calls; ringback for outgoing calls.
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _ringbackPlayer = AudioPlayer();
  Timer? _hapticTimer;

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
    // Incoming-call ringtone: looped audio asset + a periodic haptic pulse.
    try {
      await _ringtonePlayer.setAsset('assets/sounds/ringtone.wav');
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      // Not awaited — play() completes only when looped playback stops.
      unawaited(_ringtonePlayer.play());
    } catch (e) {
      debugPrint('CallService: ringtone play failed: $e');
    }
    _hapticTimer?.cancel();
    HapticFeedback.heavyImpact();
    _hapticTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => HapticFeedback.heavyImpact());
  }

  @override
  Future<void> stopRingtone() async {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    try {
      await _ringtonePlayer.stop();
    } catch (e) {
      debugPrint('CallService: ringtone stop failed: $e');
    }
  }

  /// Outgoing-call ringback. The matrix VoIP layer only drives [playRingtone]
  /// for incoming calls, so [CallScreen] calls this directly while an outgoing
  /// call is still ringing.
  Future<void> playRingback() async {
    try {
      await _ringbackPlayer.setAsset('assets/sounds/ringback.wav');
      await _ringbackPlayer.setLoopMode(LoopMode.one);
      unawaited(_ringbackPlayer.play());
    } catch (e) {
      debugPrint('CallService: ringback play failed: $e');
    }
  }

  Future<void> stopRingback() async {
    try {
      await _ringbackPlayer.stop();
    } catch (e) {
      debugPrint('CallService: ringback stop failed: $e');
    }
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
    await stopRingback();
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
