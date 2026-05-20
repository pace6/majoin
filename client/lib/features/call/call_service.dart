import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:matrix/matrix.dart';
import 'package:webrtc_interface/webrtc_interface.dart';
import '../../core/client/matrix_client.dart';
import 'call_screen.dart';

/// Implements [WebRTCDelegate] + owns the [VoIP] singleton.
class CallService implements WebRTCDelegate {
  CallService._(this._navKey);
  static CallService? _instance;
  static CallService get instance =>
      _instance ?? (throw StateError('CallService not initialized'));

  final GlobalKey<NavigatorState> _navKey;
  late final VoIP voip;

  static Future<void> init(GlobalKey<NavigatorState> navKey) async {
    if (_instance != null) return;
    final svc = CallService._(navKey);
    svc.voip = VoIP(MatrixClientService.instance.client, svc);
    _instance = svc;
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
  Future<void> playRingtone() async {/* TODO */}

  @override
  Future<void> stopRingtone() async {/* TODO */}

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
    final navState = _navKey.currentState;
    if (navState == null) return;
    if (navState.canPop()) navState.pop();
  }

  @override
  Future<void> handleMissedCall(CallSession session) async {}

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

  Future<void> startCall(Room room, {required bool video}) async {
    final peer = room.directChatMatrixID;
    if (peer == null) return;
    await voip.inviteToCall(
      room,
      video ? CallType.kVideo : CallType.kVoice,
      userId: peer,
    );
  }
}
