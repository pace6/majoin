import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:matrix/matrix.dart';
import 'package:video_player/video_player.dart';

import '../../core/util/attachment.dart';

/// Inline voice-message player — play/pause + progress + duration.
/// Downloads + decrypts the attachment before playing (E2EE-safe).
class AudioMessagePlayer extends StatefulWidget {
  const AudioMessagePlayer({
    super.key,
    required this.event,
    this.durationMs,
    required this.mine,
  });
  final Event event;
  final int? durationMs;
  final bool mine;

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final _player = AudioPlayer();
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await attachmentFile(widget.event);
      await _player.setFilePath(file.path);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : const Color(0xFF1A1A1A);
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snap) {
              final playing = snap.data?.playing ?? false;
              final completed =
                  snap.data?.processingState == ProcessingState.completed;
              return IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _failed
                      ? Icons.error_outline
                      : playing && !completed
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                  color: fg,
                  size: 34,
                ),
                onPressed: !_ready
                    ? null
                    : () async {
                        if (completed) {
                          await _player.seek(Duration.zero);
                          await _player.play();
                        } else if (playing) {
                          await _player.pause();
                        } else {
                          await _player.play();
                        }
                      },
              );
            },
          ),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final total = _player.duration ??
                    Duration(milliseconds: widget.durationMs ?? 0);
                final frac = total.inMilliseconds == 0
                    ? 0.0
                    : (pos.inMilliseconds / total.inMilliseconds)
                        .clamp(0.0, 1.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: frac,
                      backgroundColor: fg.withValues(alpha: 0.25),
                      valueColor: AlwaysStoppedAnimation(fg),
                      minHeight: 3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmt(pos == Duration.zero ? total : pos),
                      style: TextStyle(fontSize: 11, color: fg),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Image message — decrypts + shows the attachment, tap opens fullscreen.
class ChatImage extends StatefulWidget {
  const ChatImage({super.key, required this.event});
  final Event event;

  @override
  State<ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<ChatImage> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await attachmentFile(widget.event);
      if (mounted) setState(() => _file = f);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return GestureDetector(
      onTap: file == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _ImageFullScreen(file: file),
                  fullscreenDialog: true,
                ),
              ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: file != null
            ? Image.file(file, width: 240, fit: BoxFit.cover)
            : Container(
                width: 240,
                height: 180,
                color: const Color(0x22000000),
                child: Center(
                  child: _failed
                      ? const Icon(Icons.broken_image_outlined,
                          color: Colors.grey)
                      : const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
              ),
      ),
    );
  }
}

class _ImageFullScreen extends StatelessWidget {
  const _ImageFullScreen({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.file(file),
        ),
      ),
    );
  }
}

/// Video message thumbnail → tap opens fullscreen player.
class VideoMessageTile extends StatelessWidget {
  const VideoMessageTile({super.key, required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _VideoFullScreen(event: event),
          fullscreenDialog: true,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 240,
          height: 160,
          color: Colors.black,
          alignment: Alignment.center,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoFullScreen extends StatefulWidget {
  const _VideoFullScreen({required this.event});
  final Event event;

  @override
  State<_VideoFullScreen> createState() => _VideoFullScreenState();
}

class _VideoFullScreenState extends State<_VideoFullScreen> {
  VideoPlayerController? _ctl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await attachmentFile(widget.event);
      final c = VideoPlayerController.file(file);
      await c.initialize();
      await c.play();
      if (mounted) {
        setState(() => _ctl = c);
      } else {
        await c.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctl;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _failed
            ? const Icon(Icons.broken_image_outlined,
                color: Colors.grey, size: 48)
            : c == null
                ? const CircularProgressIndicator()
                : AspectRatio(
                    aspectRatio: c.value.aspectRatio,
                    child: GestureDetector(
                      onTap: () => setState(() =>
                          c.value.isPlaying ? c.pause() : c.play()),
                      child: VideoPlayer(c),
                    ),
                  ),
      ),
    );
  }
}
