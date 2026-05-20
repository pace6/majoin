import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';
import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import 'timeline_state.dart';
import '../../core/util/room_ext.dart';

const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Bottom sheet shown on long-press of a message bubble.
Future<void> showMessageActions(
  BuildContext context,
  Event event,
  TimelineUiState ui,
) async {
  final mine = event.senderId == MatrixClientService.instance.client.userID;

  final canEdit = mine && event.messageType == MessageTypes.Text;

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick emoji reactions.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final emoji in _quickReactions)
                  InkWell(
                    onTap: () async {
                      Navigator.of(sheetCtx).pop();
                      try {
                        await event.room.sendReaction(event.eventId, emoji);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.reply_outlined),
            title: Text('msg.reply'.tr),
            onTap: () {
              ui.setReply(event);
              Navigator.of(sheetCtx).pop();
            },
          ),
          if (canEdit)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('msg.edit'.tr),
              onTap: () {
                ui.setEdit(event);
                Navigator.of(sheetCtx).pop();
              },
            ),
          if (event.body.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text('msg.copy'.tr),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: event.body));
                if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
              },
            ),
          ListTile(
            leading: const Icon(Icons.forward_outlined),
            title: Text('msg.forward'.tr),
            onTap: () async {
              Navigator.of(sheetCtx).pop();
              await _forward(context, event);
            },
          ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('msg.unsend'.tr,
                  style: const TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                try {
                  await event.redactEvent();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${'msg.unsend'.tr}: $e')),
                    );
                  }
                }
              },
            ),
        ],
      ),
    ),
  );
}

/// Forward [event] to another joined room picked from a bottom sheet.
/// Re-sends the content map (same mxc URLs — no re-upload), dropping any
/// reply/edit relation so the forwarded copy stands on its own.
Future<void> _forward(BuildContext context, Event event) async {
  final client = MatrixClientService.instance.client;
  final rooms = client.rooms
      .where((r) => r.membership == Membership.join)
      .toList()
    ..sort((a, b) =>
        b.latestEventReceivedTime.compareTo(a.latestEventReceivedTime));

  final target = await showModalBottomSheet<Room>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('msg.forwardTo'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final r in rooms)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFE0E0E0),
                      child: Text(
                        roomTitle(r).characters.first
                            .toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    title: Text(roomTitle(r)),
                    onTap: () => Navigator.of(sheetCtx).pop(r),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (target == null) return;

  // Forwarding out of an encrypted room into a plaintext one would leak the
  // content (and break encrypted attachments). Block it.
  if (event.room.encrypted && !target.encrypted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('msg.forwardBlocked'.tr)),
      );
    }
    return;
  }

  final content = Map<String, dynamic>.from(event.content)
    ..remove('m.relates_to');
  try {
    await target.sendEvent(content, type: event.type);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('msg.forwarded'.tr)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'msg.forward'.tr}: $e')),
      );
    }
  }
}
