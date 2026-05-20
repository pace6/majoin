import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:matrix/matrix.dart';
import '../../core/i18n/strings.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/mxc_image.dart';

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
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background — remote feed for a connected video call, else a
            // warm accent-to-dark gradient.
            if (_isVideo && _remote != null && _isConnected)
              Positioned.fill(
                child: RTCVideoView(
                  _remote!,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppTheme.accentDeep, Color(0xFF0A0A0C)],
                    ),
                  ),
                ),
              ),

            // Caller block — big avatar, name, status (voice, or while
            // connecting).
            if (!_isVideo || !_isConnected)
              Positioned.fill(
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _callerAvatar(140),
                      const SizedBox(height: 18),
                      Text(
                        s.room.getLocalizedDisplayname(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _statusLabel(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Connected video — small name/status header.
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
                              fontSize: 20,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(_statusLabel(),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),

            // Local self-view (picture-in-picture).
            if (_isVideo && _local != null && _isConnected)
              Positioned(
                top: 80, right: 16,
                child: SizedBox(
                  width: 100, height: 134,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: _isIncoming ? _incomingBar() : _activeBar(),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallBtn(
              icon: _muted ? Icons.mic_off : Icons.mic,
              label: 'call.mic'.tr,
              on: _muted,
              onTap: _toggleMute,
            ),
            if (_isVideo)
              _CallBtn(
                icon: _videoMuted ? Icons.videocam_off : Icons.videocam,
                label: 'call.camera'.tr,
                on: _videoMuted,
                onTap: _toggleVideo,
              ),
            if (_isVideo)
              _CallBtn(
                icon: Icons.cameraswitch_outlined,
                label: 'call.flip'.tr,
                on: false,
                onTap: _switchCamera,
              ),
            if (!_isVideo)
              _CallBtn(
                icon: _speakerOn ? Icons.volume_up : Icons.volume_down,
                label: 'call.speaker'.tr,
                on: _speakerOn,
                onTap: _toggleSpeaker,
              ),
          ],
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: _hangup,
            icon: const Icon(Icons.call_end),
            label: Text('call.hangUp'.tr,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _callerAvatar(double size) {
    final mxc = s.room.avatar?.toString();
    final name = s.room.getLocalizedDisplayname();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: _isConnected
                ? Colors.transparent
                : AppTheme.accent.withValues(alpha: 0.6),
            width: 3),
      ),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: mxc != null && mxc.isNotEmpty
              ? MxcImage(url: mxc, width: size, height: size)
              : Container(
                  color: AppTheme.accentDeep,
                  alignment: Alignment.center,
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: TextStyle(
                        fontSize: size * 0.36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Frosted 60px call-control button with a label.
class _CallBtn extends StatelessWidget {
  const _CallBtn({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 34,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 24, color: on ? const Color(0xFF0A0A0C) : Colors.white),
          ),
        ),
        const SizedBox(height: 7),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
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
