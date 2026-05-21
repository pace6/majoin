import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';
import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/room_ext.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/pebble_icon.dart';
import '../../ui/widgets/mxc_image.dart';

/// Preview text for a room's last event — labels non-text message kinds.
String _lastPreview(Event e) {
  if (e.type == 'm.sticker') return 'msg.sticker'.tr;
  if (e.type == 'app.majoin.flex') return 'msg.flex'.tr;
  if (e.type == 'm.room.encrypted') return 'chat.undecryptable'.tr;
  if (e.type.startsWith('m.call.')) return 'call.missed'.tr;
  switch (e.messageType) {
    case MessageTypes.Image:
      return 'msg.image'.tr;
    case MessageTypes.Video:
      return 'msg.video'.tr;
    case MessageTypes.Audio:
      return 'msg.audio'.tr;
    case MessageTypes.File:
      return 'msg.file'.tr;
    default:
      // Membership changes, redactions, etc. have no body — fall back to a
      // human-readable line so the row never blanks out.
      final body = e.body.trim();
      return body.isNotEmpty ? body : 'msg.update'.tr;
  }
}

/// Room list panel. On mobile = full screen. On desktop = left pane.
/// Shows joined + invited rooms; invited rows offer an "Accept" button.
class RoomList extends StatefulWidget {
  const RoomList({
    super.key,
    required this.onRoomTap,
    this.selectedRoomId,
    this.query,
  });

  final void Function(Room room) onRoomTap;
  final String? selectedRoomId;

  /// When non-empty, only rooms whose display name contains it are shown.
  final String? query;

  @override
  State<RoomList> createState() => _RoomListState();
}

class _RoomListState extends State<RoomList> {
  late final Client _c = MatrixClientService.instance.client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _c.onSync.stream,
      builder: (context, _) {
        var rooms = [..._c.rooms];
        rooms.sort((a, b) {
          // invites pinned to top
          final aInv = a.membership == Membership.invite;
          final bInv = b.membership == Membership.invite;
          if (aInv != bInv) return aInv ? -1 : 1;
          return (b.lastEvent?.originServerTs ?? DateTime(0))
              .compareTo(a.lastEvent?.originServerTs ?? DateTime(0));
        });

        final q = widget.query?.trim().toLowerCase();
        if (q != null && q.isNotEmpty) {
          rooms = rooms
              .where((r) =>
                  roomTitle(r).toLowerCase().contains(q))
              .toList();
        }

        if (rooms.isEmpty) {
          return Center(
            child: Text('rooms.empty'.tr,
                style: const TextStyle(color: Colors.black54)),
          );
        }

        return ListView.builder(
          itemCount: rooms.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
                child: Text(
                  'chats.allChats'.tr.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.subtleText,
                  ),
                ),
              );
            }
            final r = rooms[i - 1];
            return _RoomTile(
              room: r,
              selected: r.id == widget.selectedRoomId,
              onTap: () => widget.onRoomTap(r),
            );
          },
        );
      },
    );
  }
}

class _RoomTile extends StatefulWidget {
  const _RoomTile({
    required this.room,
    required this.selected,
    required this.onTap,
  });
  final Room room;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RoomTile> createState() => _RoomTileState();
}

class _RoomTileState extends State<_RoomTile> {
  bool _joining = false;
  // Last non-empty preview — kept so a transient null lastEvent (the SDK
  // briefly clears it while refreshing) doesn't blank the row.
  String _cachedPreview = '';

  Future<void> _accept() async {
    setState(() => _joining = true);
    try {
      await widget.room.join();
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _decline() async {
    await widget.room.leave();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.room;
    final invited = r.membership == Membership.invite;
    final last = r.lastEvent;
    final isMine = last != null &&
        last.senderId == MatrixClientService.instance.client.userID;
    var preview = invited
        ? 'rooms.invitation'.tr
        : last == null
            ? ''
            : _lastPreview(last);
    if (isMine && !invited && preview.isNotEmpty) preview = '✓ $preview';
    // Hold the last known preview through a transient empty refresh.
    if (preview.isNotEmpty) {
      _cachedPreview = preview;
    } else {
      preview = _cachedPreview;
    }

    final ts = r.lastEvent?.originServerTs;
    final timeLabel = ts == null ? '' : _formatTime(ts);

    return InkWell(
      onTap: invited ? _accept : widget.onTap,
      child: Container(
        color: widget.selected ? AppTheme.accentSoft : AppTheme.bg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(
              url: r.avatar?.toString(),
              name: roomTitle(r),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomTitleWithCount(r),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: invited
                          ? AppTheme.lineGreen
                          : AppTheme.subtleText,
                      fontWeight:
                          invited ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeLabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.subtleText),
                ),
                const SizedBox(height: 6),
                if (invited)
                  _joining
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MiniAction(
                              icon: PIcon.close,
                              color: Colors.red,
                              onTap: _decline,
                            ),
                            const SizedBox(width: 4),
                            _MiniAction(
                              icon: PIcon.check,
                              color: AppTheme.lineGreen,
                              onTap: _accept,
                            ),
                          ],
                        )
                else if (r.notificationCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.lineGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${r.notificationCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime ts) {
    final now = DateTime.now();
    final sameDay = ts.year == now.year &&
        ts.month == now.month &&
        ts.day == now.day;
    if (sameDay) return DateFormat.Hm().format(ts);
    final diff = now.difference(ts);
    if (diff.inDays < 7) return DateFormat.E().format(ts);
    return DateFormat.Md().format(ts);
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final PIcon icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: PebbleIcon(icon, color: color, size: 20),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final color = _colorFor(name);
    const size = 52.0;
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: MxcImage(url: url!, width: size, height: size),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color _colorFor(String s) {
    const palette = [
      Color(0xFFE57373),
      Color(0xFF64B5F6),
      Color(0xFF81C784),
      Color(0xFFFFB74D),
      Color(0xFFBA68C8),
      Color(0xFF4DB6AC),
      Color(0xFFA1887F),
    ];
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }
}
