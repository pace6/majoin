import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import '../flex/flex_event.dart';
import '../flex/flex_renderer.dart';
import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/mxc_image.dart';
import 'media_players.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.event,
    required this.timeline,
    this.showSender = false,
    this.showAvatar = true,
    this.onLongPress,
  });
  final Event event;
  final Timeline timeline;
  final bool showSender;
  final bool showAvatar;
  final VoidCallback? onLongPress;

  bool get _mine =>
      event.senderId == MatrixClientService.instance.client.userID;

  @override
  Widget build(BuildContext context) {
    // Call invites render as a centered system entry, not a sender bubble.
    if (event.type == 'm.call.invite') {
      return _CallEntry(invite: event, timeline: timeline);
    }

    // Render the latest edit (or redaction) of this event, not the original.
    final display = event.getDisplayEvent(timeline);
    final isSticker = display.type == 'm.sticker';
    final isFlex = display.type == kFlexEventType;
    final isImage = display.messageType == MessageTypes.Image;
    final isEdited =
        event.hasAggregatedEvents(timeline, RelationshipTypes.edit);

    final time = DateFormat.Hm().format(event.originServerTs);
    final timeWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(time,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.subtleText)),
          if (_mine) ...[
            const SizedBox(width: 3),
            const Text('✓✓',
                style: TextStyle(fontSize: 10, color: AppTheme.accent)),
          ],
        ],
      ),
    );

    final isVideo = display.messageType == MessageTypes.Video;
    final messageBody = _renderEvent(context, display, isEdited);

    // Stickers, flex, images, video: no colored bubble.
    // Audio keeps the bubble (player tints itself by sender).
    final bare = isSticker || isFlex || isImage || isVideo;

    Widget bubble = bare
        ? messageBody
        : _Bubble(mine: _mine, child: messageBody);

    bubble = GestureDetector(
      onLongPress: onLongPress,
      child: bubble,
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment:
          _mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!_mine && showAvatar) _avatar(),
        if (!_mine && showAvatar) const SizedBox(width: 6),
        if (_mine) timeWidget,
        Flexible(
          child: Column(
            crossAxisAlignment:
                _mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!_mine && showSender)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    event.senderFromMemoryOrFallback.calcDisplayname(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.subtleText),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: bubble,
              ),
              _ReactionsRow(event: event, timeline: timeline, mine: _mine),
            ],
          ),
        ),
        if (!_mine) timeWidget,
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      child: row,
    );
  }

  Widget _avatar() {
    final sender = event.senderFromMemoryOrFallback;
    final name = sender.calcDisplayname();
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final mxc = sender.avatarUrl?.toString();
    return ClipOval(
      child: SizedBox(
        width: 32,
        height: 32,
        child: mxc != null && mxc.isNotEmpty
            ? MxcImage(url: mxc, width: 32, height: 32)
            : Container(
                color: AppTheme.accentSoft,
                alignment: Alignment.center,
                child: Text(letter,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentDeep)),
              ),
      ),
    );
  }

  Widget _renderEvent(BuildContext context, Event display, bool isEdited) {
    if (display.type == 'm.room.encrypted') {
      // Decryption failed — no megolm key for this message on this device.
      final fg = _mine ? AppTheme.myBubbleText : AppTheme.theirBubbleText;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 14, color: fg.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Flexible(
            child: Text('chat.undecryptable'.tr,
                style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: fg.withValues(alpha: 0.7))),
          ),
        ],
      );
    }
    if (display.type == kFlexEventType) {
      final flexJson = display.content['app.majoin.flex'];
      if (flexJson is Map) {
        return FlexBubbleView(
          bubble: FlexBubble.fromJson(Map<String, dynamic>.from(flexJson)),
        );
      }
      return Text(display.body);
    }
    if (display.type == 'm.sticker') {
      final url = display.content['url'] as String?;
      if (url != null && url.startsWith('mxc://')) {
        return MxcImage(
          url: url,
          width: 128,
          height: 128,
          fit: BoxFit.contain,
        );
      }
      return const Text('[sticker]');
    }
    if (display.messageType == MessageTypes.Audio) {
      if (display.attachmentMxcUrl != null) {
        final dur = (display.content['info'] as Map?)?['duration'] as int?;
        return AudioMessagePlayer(
          event: display,
          durationMs: dur,
          mine: _mine,
        );
      }
      return const _UploadingBox(width: 200, height: 48);
    }
    if (display.messageType == MessageTypes.Video) {
      if (display.attachmentMxcUrl != null) {
        return VideoMessageTile(event: display);
      }
      return const _UploadingBox(width: 240, height: 160);
    }
    if (display.messageType == MessageTypes.Image) {
      if (display.attachmentMxcUrl != null) {
        return ChatImage(event: display);
      }
      return const _UploadingBox(width: 240, height: 180);
    }
    if (display.messageType == MessageTypes.File) {
      return _FileTile(event: display, mine: _mine);
    }
    final color = _mine ? AppTheme.myBubbleText : AppTheme.theirBubbleText;
    return Text.rich(
      TextSpan(
        text: display.body,
        children: [
          if (isEdited)
            TextSpan(
              text: '  ${'msg.edited'.tr}',
              style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic),
            ),
        ],
      ),
      style: TextStyle(color: color, fontSize: 15, height: 1.3),
    );
  }
}

enum _CallOutcome { ringing, answered, missed, canceled, declined }

/// Centered timeline entry for a voice/video call — resolves its outcome
/// (answered + duration, missed, canceled, declined) by reading the matching
/// `m.call.answer` / `m.call.hangup` / `m.call.reject` events off [timeline].
class _CallEntry extends StatelessWidget {
  const _CallEntry({required this.invite, required this.timeline});
  final Event invite;
  final Timeline timeline;

  bool get _isVideo {
    final offer = invite.content['offer'];
    final sdp = offer is Map ? offer['sdp'] : null;
    return sdp is String && sdp.contains('m=video');
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final myId = MatrixClientService.instance.client.userID;
    final outgoing = invite.senderId == myId;
    final callId = invite.content['call_id'];

    // Newest-first scan; one answer / one ender per call in practice.
    Event? answer;
    Event? ender;
    for (final e in timeline.events) {
      if (e.content['call_id'] != callId) continue;
      if (e.type == 'm.call.answer') {
        answer ??= e;
      } else if (e.type == 'm.call.hangup' || e.type == 'm.call.reject') {
        ender ??= e;
      }
    }

    _CallOutcome outcome;
    Duration? duration;
    if (answer != null) {
      outcome = _CallOutcome.answered;
      final end = ender?.originServerTs ?? DateTime.now();
      duration = end.difference(answer.originServerTs);
    } else if (ender == null) {
      outcome = _CallOutcome.ringing;
    } else if (ender.type == 'm.call.reject') {
      outcome = _CallOutcome.declined;
    } else if (ender.senderId == invite.senderId) {
      // Caller hung up before it was answered.
      outcome = outgoing ? _CallOutcome.canceled : _CallOutcome.missed;
    } else {
      // Callee hung up without answering.
      outcome = _CallOutcome.declined;
    }

    final kind =
        (_isVideo ? 'call.videoCall' : 'call.voiceCall').tr;
    IconData icon = _isVideo ? Icons.videocam_outlined : Icons.call_outlined;
    Color color = AppTheme.subtleText;
    String label;
    switch (outcome) {
      case _CallOutcome.answered:
        label = '$kind · ${_fmtDuration(duration!)}';
      case _CallOutcome.ringing:
        label = 'call.calling'.tr;
      case _CallOutcome.missed:
        icon = Icons.call_missed;
        color = const Color(0xFFFF3B30);
        label = 'call.missed'.tr;
      case _CallOutcome.canceled:
        icon = _isVideo ? Icons.videocam_off_outlined : Icons.call_missed;
        label = 'call.noAnswer'.tr;
      case _CallOutcome.declined:
        label = 'call.declined'.tr;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x14000000),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reaction chips under a bubble. Tapping a chip toggles your own reaction.
class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({
    required this.event,
    required this.timeline,
    required this.mine,
  });
  final Event event;
  final Timeline timeline;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    if (!event.hasAggregatedEvents(timeline, RelationshipTypes.reaction)) {
      return const SizedBox.shrink();
    }
    final myId = MatrixClientService.instance.client.userID;
    final reactions =
        event.aggregatedEvents(timeline, RelationshipTypes.reaction);

    // key -> (count, my reaction event id if I reacted)
    final counts = <String, int>{};
    final myReaction = <String, String>{};
    for (final r in reactions) {
      if (r.redacted) continue;
      final key = r.content
          .tryGetMap<String, Object?>('m.relates_to')
          ?.tryGet<String>('key');
      if (key == null) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      if (r.senderId == myId) myReaction[key] = r.eventId;
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final entry in counts.entries)
            _ReactionChip(
              emoji: entry.key,
              count: entry.value,
              reacted: myReaction.containsKey(entry.key),
              onTap: () async {
                final mineId = myReaction[entry.key];
                if (mineId != null) {
                  await event.room.redactEvent(mineId);
                } else {
                  await event.room.sendReaction(event.eventId, entry.key);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.reacted,
    required this.onTap,
  });
  final String emoji;
  final int count;
  final bool reacted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: reacted ? const Color(0x3306C755) : const Color(0x22000000),
          borderRadius: BorderRadius.circular(12),
          border: reacted
              ? Border.all(color: AppTheme.lineGreen, width: 1)
              : null,
        ),
        child: Text('$emoji $count',
            style: const TextStyle(fontSize: 12, color: Colors.white)),
      ),
    );
  }
}

/// Document message: filename + size, tap to download into the app dir.
class _FileTile extends StatefulWidget {
  const _FileTile({required this.event, required this.mine});
  final Event event;
  final bool mine;

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  bool _busy = false;

  String get _name =>
      widget.event.body.isEmpty ? 'file' : widget.event.body;

  String? get _sizeLabel {
    final size = (widget.event.content['info'] as Map?)?['size'];
    if (size is! int) return null;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('file.downloading'.tr)));
    try {
      final matrixFile = await widget.event.downloadAndDecryptAttachment();
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/$_name';
      await File(path).writeAsBytes(matrixFile.bytes);
      messenger.showSnackBar(
        SnackBar(content: Text('${'file.saved'.tr}: $path')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${'pickerError'.tr}: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg =
        widget.mine ? AppTheme.myBubbleText : AppTheme.theirBubbleText;
    return InkWell(
      onTap: _download,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: _busy
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(Icons.insert_drive_file_outlined, size: 22, color: fg),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                if (_sizeLabel != null)
                  Text(_sizeLabel!,
                      style: TextStyle(
                          color: fg.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadingBox extends StatelessWidget {
  const _UploadingBox({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.mine, required this.child});
  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bg = mine ? AppTheme.myBubble : AppTheme.theirBubble;
    final radius = const Radius.circular(20);
    final smallRadius = const Radius.circular(6);
    final shape = mine
        ? BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: radius,
            bottomRight: smallRadius,
          )
        : BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: smallRadius,
            bottomRight: radius,
          );
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: shape,
        boxShadow: mine
            ? null
            : [
                const BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: child,
    );
  }
}

