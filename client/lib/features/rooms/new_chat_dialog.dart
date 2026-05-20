import 'package:flutter/material.dart';
import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';

/// Entry sheet — choose Direct chat or Group room. Returns the new/reused
/// room id on success.
Future<String?> showNewChatDialog(BuildContext context) async {
  final mode = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text('newChat.direct'.tr),
            subtitle: Text('newChat.directDesc'.tr),
            onTap: () => Navigator.pop(context, 'dm'),
          ),
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: Text('newChat.group'.tr),
            subtitle: Text('newChat.groupDesc'.tr),
            onTap: () => Navigator.pop(context, 'group'),
          ),
        ],
      ),
    ),
  );
  if (mode == null || !context.mounted) return null;
  return mode == 'dm'
      ? showDirectChatDialog(context)
      : showGroupRoomDialog(context);
}

Future<String?> showDirectChatDialog(BuildContext context) async {
  final ctl = TextEditingController(text: '@');
  String? error;
  bool busy = false;

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> submit() async {
            final raw = ctl.text.trim();
            if (!raw.startsWith('@') || !raw.contains(':')) {
              setState(() => error = 'newChat.mxidFormatHint'.tr);
              return;
            }
            setState(() {
              busy = true;
              error = null;
            });
            try {
              final id = await MatrixClientService.instance.client
                  .startDirectChat(raw);
              if (ctx.mounted) Navigator.of(ctx).pop(id);
            } catch (e) {
              setState(() {
                busy = false;
                error = e.toString();
              });
            }
          }

          return AlertDialog(
            title: Text('newChat.directTitle'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('newChat.directHint'.tr),
                const SizedBox(height: 8),
                TextField(
                  controller: ctl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '@bob:localhost',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => submit(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: Text('common.cancel'.tr),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('newChat.startChat'.tr),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<String?> showGroupRoomDialog(BuildContext context) async {
  final nameCtl = TextEditingController();
  final inviteCtl = TextEditingController();
  String? error;
  bool busy = false;

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> submit() async {
            final name = nameCtl.text.trim();
            if (name.isEmpty) {
              setState(() => error = 'newChat.groupNameRequired'.tr);
              return;
            }
            final invites = inviteCtl.text
                .split(RegExp(r'[\s,]+'))
                .where((s) => s.isNotEmpty)
                .toList();
            for (final id in invites) {
              if (!id.startsWith('@') || !id.contains(':')) {
                setState(() => error = '${'newChat.badMxid'.tr}: $id');
                return;
              }
            }
            setState(() {
              busy = true;
              error = null;
            });
            try {
              final id = await MatrixClientService.instance.client
                  .createGroupChat(
                groupName: name,
                invite: invites.isEmpty ? null : invites,
              );
              if (ctx.mounted) Navigator.of(ctx).pop(id);
            } catch (e) {
              setState(() {
                busy = false;
                error = e.toString();
              });
            }
          }

          return AlertDialog(
            title: Text('newChat.groupTitle'.tr),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'newChat.groupName'.tr,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: inviteCtl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'newChat.invite'.tr,
                      hintText: '@bob:localhost, @carol:localhost',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: Text('common.cancel'.tr),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('newChat.create'.tr),
              ),
            ],
          );
        },
      );
    },
  );
}
