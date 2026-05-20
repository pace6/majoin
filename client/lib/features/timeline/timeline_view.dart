import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/strings.dart';
import '../call/call_service.dart';
import 'composer.dart';
import 'message_actions.dart';
import 'message_bubble.dart';
import 'timeline_state.dart';
import '../../core/client/matrix_client.dart';
import '../../ui/theme/app_theme.dart';

class TimelineView extends StatefulWidget {
  const TimelineView({super.key, required this.room});
  final Room room;

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  Timeline? _timeline;
  String? _loadError;
  final TimelineUiState _ui = TimelineUiState();
  final ScrollController _scrollCtl = ScrollController();
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _open();
    _scrollCtl.addListener(_onScroll);
    // Receipts arrive as ephemeral EDUs that don't fire timeline onChange.
    // Rebuild on every sync so read-avatars track peer receipts.
    _syncSub = MatrixClientService.instance.client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  /// List is reverse:true, so scrolling toward older messages moves toward
  /// maxScrollExtent. Near the end, pull the next page of history.
  void _onScroll() {
    final tl = _timeline;
    if (tl == null || !tl.canRequestHistory || tl.isRequestingHistory) return;
    if (_scrollCtl.position.pixels >=
        _scrollCtl.position.maxScrollExtent - 400) {
      tl.requestHistory().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant TimelineView old) {
    super.didUpdateWidget(old);
    if (old.room.id != widget.room.id) {
      _timeline?.cancelSubscriptions();
      _timeline = null;
      _ui.clearReply();
      _open();
    }
  }

  Future<void> _open() async {
    try {
      final t = await widget.room.getTimeline(onChange: (_) {
        if (mounted) setState(() {});
      }, onInsert: (_) {
        if (mounted) setState(() {});
        _sendReadReceipt();
      }).timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _timeline = t);
      _sendReadReceipt();
    } catch (e, st) {
      // Surface a stuck/failed getTimeline instead of an endless spinner.
      Logs().e('[Timeline] getTimeline failed for ${widget.room.id}', e, st);
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  void _sendReadReceipt() {
    final tl = _timeline;
    if (tl == null) return;
    // Only mark a real, server-acked event — a local echo still carries its
    // transaction id (not a `$...` event id) and setReadMarker would 404.
    final newest = tl.events.cast<Event?>().firstWhere(
          (e) => e != null && _visible(e) && e.eventId.startsWith(r'$'),
          orElse: () => null,
        );
    if (newest != null) {
      widget.room
          .setReadMarker(newest.eventId, mRead: newest.eventId)
          .catchError((_) {}); // best-effort; ignore transient failures
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _scrollCtl.dispose();
    _timeline?.cancelSubscriptions();
    _ui.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tl = _timeline;
    if (tl == null) {
      return Container(
        color: AppTheme.chatBg,
        alignment: Alignment.center,
        child: _loadError != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('chat.loadError'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.subtleText)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() => _loadError = null);
                        _open();
                      },
                      child: Text('common.retry'.tr),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      );
    }
    final events = tl.events.where(_visible).toList();
    final isGroup = !widget.room.isDirectChat;
    final myId = MatrixClientService.instance.client.userID;

    // Max read timestamp among peers (exclude self).
    var maxPeerReadTs = 0;
    widget.room.receiptState.global.otherUsers.forEach((uid, data) {
      if (uid != myId && data.ts > maxPeerReadTs) maxPeerReadTs = data.ts;
    });
    // Newest own message that a peer has read → show "Read" under it.
    String? readMarkerEventId;
    for (final e in events) {
      if (e.senderId == myId &&
          e.originServerTs.millisecondsSinceEpoch <= maxPeerReadTs) {
        readMarkerEventId = e.eventId;
        break; // events is newest-first
      }
    }

    return ChangeNotifierProvider.value(
      value: _ui,
      child: Container(
        color: AppTheme.chatBg,
        child: Column(
          children: [
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        'chat.empty'.tr,
                        style: const TextStyle(color: AppTheme.subtleText),
                      ),
                    )
                  : ListView.builder(
                controller: _scrollCtl,
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                // Trailing spinner only while a history page is actually
                // being fetched. `canRequestHistory` stays true until the
                // room start is reached, so using it would leave the spinner
                // stuck forever on chats too short to scroll.
                itemCount:
                    events.length + (tl.isRequestingHistory ? 1 : 0),
                itemBuilder: (context, i) {
                  // Trailing (oldest end) slot: history-loading spinner.
                  if (i >= events.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final e = events[i];
                  final newer = i - 1 >= 0 ? events[i - 1] : null;
                  final older = i + 1 < events.length ? events[i + 1] : null;
                  final isStreakHead = newer == null ||
                      newer.senderId != e.senderId ||
                      newer.originServerTs
                              .difference(e.originServerTs)
                              .inMinutes >
                          5;

                  // Date separator: between this event and the older one.
                  final showDateSep = older == null ||
                      !_sameDay(older.originServerTs, e.originServerTs);

                  final showRead = e.eventId == readMarkerEventId;

                  return Column(
                    children: [
                      MessageBubble(
                        event: e,
                        timeline: tl,
                        showSender: isGroup && isStreakHead,
                        showAvatar: isStreakHead,
                        onLongPress: () =>
                            showMessageActions(context, e, _ui),
                      ),
                      if (showRead)
                        Padding(
                          padding:
                              const EdgeInsets.only(right: 16, bottom: 2),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'msg.read'.tr,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xE6FFFFFF)),
                            ),
                          ),
                        ),
                      if (showDateSep)
                        _DateSeparator(date: e.originServerTs),
                    ],
                  );
                },
              ),
            ),
            _TypingIndicator(room: widget.room),
            Composer(room: widget.room, ui: _ui),
          ],
        ),
      ),
    );
  }

  bool _visible(Event e) {
    if (e.redacted) return false;
    return e.type == 'm.room.message' ||
        e.type == 'm.sticker' ||
        e.type == 'app.majoin.flex';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Thin bar above the composer — shows peers currently typing.
/// Parent [TimelineView] rebuilds on every sync, so this stays current.
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    final myId = MatrixClientService.instance.client.userID;
    final names = room.typingUsers
        .where((u) => u.id != myId)
        .map((u) => u.calcDisplayname())
        .toList();
    if (names.isEmpty) return const SizedBox.shrink();
    final label = room.isDirectChat
        ? 'chat.typing'.tr
        : '${names.join(', ')} ${'chat.typing'.tr}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11,
            color: Color(0xE6FFFFFF),
            fontStyle: FontStyle.italic),
      ),
    );
  }
}

/// Row of mini avatars shown under a message — peers who read up to it.
class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    final lang = Localizations.localeOf(context).languageCode;
    final label = diff == 0
        ? 'date.today'.tr
        : diff == 1
            ? 'date.yesterday'.tr
            : diff < 7
                ? DateFormat.EEEE(lang).format(date)
                : DateFormat.yMMMMd(lang).format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0x33FFFFFF), thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x55000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0x33FFFFFF), thickness: 0.5)),
        ],
      ),
    );
  }
}

class TimelineAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TimelineAppBar({super.key, required this.room, this.leading});
  final Room room;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFE0E0E0),
            child: Text(
              room.getLocalizedDisplayname().characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF444444)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              room.getLocalizedDisplayname(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_outlined),
          onPressed: () => _startCall(context, room, video: false),
        ),
        IconButton(
          icon: const Icon(Icons.videocam_outlined),
          onPressed: () => _startCall(context, room, video: true),
        ),
        IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
      ],
    );
  }
}

Future<void> _startCall(BuildContext context, Room room,
    {required bool video}) async {
  if (!room.isDirectChat) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('call.notDm'.tr)),
    );
    return;
  }
  await CallService.instance.startCall(room, video: video);
}

