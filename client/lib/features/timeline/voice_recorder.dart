import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/i18n/strings.dart';
import '../../ui/theme/app_theme.dart';

/// Inline voice-message tray — opens above the composer like the attach and
/// sticker trays. Tap the circle to start recording, tap again to stop and
/// send the voice message.
class VoiceTray extends StatefulWidget {
  const VoiceTray({super.key, required this.room, required this.onSent});
  final Room room;
  final VoidCallback onSent;

  @override
  State<VoiceTray> createState() => _VoiceTrayState();
}

class _VoiceTrayState extends State<VoiceTray> {
  final _rec = AudioRecorder();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String? _path;
  bool _recording = false;
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await _rec.hasPermission()) {
        if (mounted) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('voice.noPermission'.tr)),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _path = path;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
      if (mounted) {
        setState(() {
          _recording = true;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _stopAndSend() async {
    if (_busy) return;
    setState(() => _busy = true);
    _ticker?.cancel();
    final stopped = await _rec.stop();
    final filePath = stopped ?? _path;
    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        await widget.room.sendFileEvent(
          MatrixAudioFile(
            bytes: bytes,
            name: 'voice_message.m4a',
            duration: _elapsed.inMilliseconds,
          ),
        );
        await file.delete();
      }
    }
    widget.onSent();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recording) _rec.stop();
    _rec.dispose();
    super.dispose();
  }

  String get _timer {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 268,
      decoration: const BoxDecoration(
        color: Color(0x06000000),
        border: Border(top: BorderSide(color: AppTheme.dividerColor, width: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _recording ? _timer : 'voice.tapToRecord'.tr,
            style: TextStyle(
              fontSize: _recording ? 22 : 15,
              fontWeight: _recording ? FontWeight.w700 : FontWeight.normal,
              color: _recording ? AppTheme.ink : AppTheme.subtleText,
            ),
          ),
          const SizedBox(height: 22),
          // Record / stop circle.
          GestureDetector(
            onTap: _recording ? _stopAndSend : _start,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x22000000), width: 4),
              ),
              alignment: Alignment.center,
              child: _recording
                  ? Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_recording)
            Text('voice.tapToSend'.tr,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.subtleText)),
        ],
      ),
    );
  }
}
