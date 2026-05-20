import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:matrix/matrix.dart';
import '../../core/i18n/strings.dart';

/// Full-screen call UI for a single [CallSession] — handles both directions.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.session});
  final CallSession session;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCVideoRenderer? _local;
  RTCVideoRenderer? _remote;
  bool _muted = false;
  bool _videoMuted = false;
  late bool _speakerOn;

  // Set when the call first connects; drives the on-screen call timer.
  DateTime? _connectedAt;
  Timer? _tick;

  CallSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    // Video calls default to loudspeaker, voice calls to the earpiece.
    _speakerOn = s.type == CallType.kVideo;
    _initRenderers();
    s.onCallStreamsChanged.stream.listen((_) => _refreshStreams());
    s.onCallStateChanged.stream.listen((_) {
      _onCallState();
      if (mounted) setState(() {});
    });
    s.onStreamAdd.stream.listen((_) => _refreshStreams());
    s.onStreamRemoved.stream.listen((_) => _refreshStreams());
  }

  void _onCallState() {
    if (s.state == CallState.kConnected && _connectedAt == null) {
      _connectedAt = DateTime.now();
      Helper.setSpeakerphoneOn(_speakerOn);
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  String get _durationLabel {
    final start = _connectedAt;
    if (start == null) return '';
    final d = DateTime.now().difference(start);
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _initRenderers() async {
    final l = RTCVideoRenderer();
    final r = RTCVideoRenderer();
    await l.initialize();
    await r.initialize();
    if (mounted) {
      setState(() {
        _local = l;
        _remote = r;
      });
      _refreshStreams();
    }
  }

  void _refreshStreams() {
    if (!mounted) return;
    final localStream = s.localUserMediaStream?.stream;
    final remoteStream = s.remoteUserMediaStream?.stream;
    setState(() {
      _local?.srcObject = localStream;
      _remote?.srcObject = remoteStream;
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _local?.dispose();
    _remote?.dispose();
    super.dispose();
  }

  Future<void> _hangup() async {
    await s.hangup(reason: CallErrorCode.userHangup);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _answer() async {
    await s.answer();
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await s.setMicrophoneMuted(_muted);
  }

  Future<void> _toggleVideo() async {
    setState(() => _videoMuted = !_videoMuted);
    await s.setLocalVideoMuted(_videoMuted);
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);
    await Helper.setSpeakerphoneOn(_speakerOn);
  }

  Future<void> _switchCamera() async {
    final localStream = s.localUserMediaStream?.stream;
    final track = localStream?.getVideoTracks().firstOrNull;
    if (track != null) await Helper.switchCamera(track);
  }

  bool get _isVideo => s.type == CallType.kVideo;
  bool get _isConnected =>
      s.state == CallState.kConnected || s.state == CallState.kConnecting;
  bool get _isIncoming =>
      s.direction == CallDirection.kIncoming &&
      s.state == CallState.kRinging;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await s.hangup(reason: CallErrorCode.userHangup);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF111111),
        body: Stack(
          children: [
            // Remote feed full-screen.
            if (_isVideo && _remote != null && _isConnected)
              Positioned.fill(
                child: RTCVideoView(
                  _remote!,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFF111111)),
              ),

            // Peer name + status header.
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        s.room.getLocalizedDisplayname(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusLabel(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Local self-view (picture-in-picture).
            if (_isVideo && _local != null && _isConnected)
              Positioned(
                top: 80, right: 12,
                child: SizedBox(
                  width: 110, height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(
                      _local!,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Bottom control bar.
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: _isIncoming
                      ? _incomingBar()
                      : _activeBar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel() {
    switch (s.state) {
      case CallState.kRinging:
        return s.direction == CallDirection.kIncoming
            ? 'call.incoming'.tr
            : 'call.ringing'.tr;
      case CallState.kInviteSent:
      case CallState.kCreateOffer:
        return 'call.calling'.tr;
      case CallState.kConnecting:
        return 'call.connecting'.tr;
      case CallState.kConnected:
        return _durationLabel.isNotEmpty ? _durationLabel : 'call.connecting'.tr;
      case CallState.kEnded:
        return 'call.ended'.tr;
      default:
        return '';
    }
  }

  Widget _incomingBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleBtn(
          icon: Icons.call_end,
          color: Colors.red,
          label: 'call.decline'.tr,
          onTap: _hangup,
        ),
        _CircleBtn(
          icon: Icons.call,
          color: const Color(0xFF06C755),
          label: 'call.accept'.tr,
          onTap: _answer,
        ),
      ],
    );
  }

  Widget _activeBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleBtn(
          icon: _muted ? Icons.mic_off : Icons.mic,
          color: _muted ? Colors.white24 : Colors.white12,
          onTap: _toggleMute,
        ),
        if (_isVideo)
          _CircleBtn(
            icon: _videoMuted ? Icons.videocam_off : Icons.videocam,
            color: _videoMuted ? Colors.white24 : Colors.white12,
            onTap: _toggleVideo,
          ),
        if (_isVideo)
          _CircleBtn(
            icon: Icons.cameraswitch_outlined,
            color: Colors.white12,
            onTap: _switchCamera,
          ),
        if (!_isVideo)
          _CircleBtn(
            icon: _speakerOn ? Icons.volume_up : Icons.volume_down,
            color: Colors.white12,
            onTap: _toggleSpeaker,
          ),
        _CircleBtn(
          icon: Icons.call_end,
          color: Colors.red,
          onTap: _hangup,
        ),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 36,
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!, style: const TextStyle(color: Colors.white70)),
        ],
      ],
    );
  }
}
