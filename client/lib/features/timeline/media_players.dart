import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../../ui/widgets/mxc_image.dart';

/// Inline voice-message player — play/pause + progress + duration.
class AudioMessagePlayer extends StatefulWidget {
  const AudioMessagePlayer({
    super.key,
    required this.mxcUrl,
    this.durationMs,
    required this.mine,
  });
  final String mxcUrl;
  final int? durationMs;
  final bool mine;

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final _player = AudioPlayer();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final resolved = resolveMatrixImage(widget.mxcUrl);
    if (resolved == null) return;
    try {
      await _player.setUrl(resolved.$1, headers: resolved.$2);
      if (mounted) setState(() => _ready = true);
    } catch (_) {}
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
                  playing && !completed
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

/// Video message thumbnail → tap opens fullscreen player.
class VideoMessageTile extends StatelessWidget {
  const VideoMessageTile({super.key, required this.mxcUrl, this.thumbnailUrl});
  final String mxcUrl;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _VideoFullScreen(mxcUrl: mxcUrl),
          fullscreenDialog: true,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 240,
              height: 160,
              color: Colors.black12,
              child: thumbnailUrl != null
                  ? MxcImage(url: thumbnailUrl!, width: 240, height: 160)
                  : null,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.play_arrow, color: Colors.white, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoFullScreen extends StatefulWidget {
  const _VideoFullScreen({required this.mxcUrl});
  final String mxcUrl;

  @override
  State<_VideoFullScreen> createState() => _VideoFullScreenState();
}

class _VideoFullScreenState extends State<_VideoFullScreen> {
  VideoPlayerController? _ctl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final resolved = resolveMatrixImage(widget.mxcUrl);
    if (resolved == null) return;
    final c = VideoPlayerController.networkUrl(
      Uri.parse(resolved.$1),
      httpHeaders: resolved.$2,
    );
    await c.initialize();
    await c.play();
    if (mounted) setState(() => _ctl = c);
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
        child: c == null
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
