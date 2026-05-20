import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../ui/theme/app_theme.dart';

/// Hold-to-record voice message control. Shown inline in the composer while
/// recording; sends an `m.audio` event on release.
class VoiceRecorderBar extends StatefulWidget {
  const VoiceRecorderBar({
    super.key,
    required this.room,
    required this.onDone,
  });
  final Room room;
  final VoidCallback onDone;

  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar> {
  final _rec = AudioRecorder();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String? _path;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      widget.onDone();
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
    _started = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    if (mounted) setState(() {});
  }

  Future<void> _stopAndSend() async {
    _ticker?.cancel();
    if (!_started) {
      widget.onDone();
      return;
    }
    final path = await _rec.stop();
    final filePath = path ?? _path;
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
    widget.onDone();
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    if (_started) {
      final p = await _rec.stop();
      if (p != null) {
        final f = File(p);
        if (await f.exists()) await f.delete();
      }
    }
    widget.onDone();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _rec.dispose();
    super.dispose();
  }

  String get _label {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _cancel,
          ),
          const Icon(Icons.mic, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(_label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          const Text('กำลังอัด...',
              style: TextStyle(color: AppTheme.subtleText)),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.lineGreen,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            onPressed: _stopAndSend,
            child: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
