import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../ui/theme/app_theme.dart';
import 'new_chat_dialog.dart';
import 'room_list.dart';

/// WhatsApp-style Chats screen: large title, search field, an "All" filter
/// chip, then the room list.
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final _searchCtl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _newChat() async {
    final id = await showNewChatDialog(context);
    if (id != null && mounted) {
      context.push('/rooms/${Uri.encodeComponent(id)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Large title + actions.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 2),
            child: Row(
              children: [
                Text('tab.chats'.tr,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  tooltip: 'rooms.newChat'.tr,
                  icon: const Icon(Icons.add_comment_outlined),
                  onPressed: _newChat,
                ),
              ],
            ),
          ),
          // Search — soft rounded pill.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'common.search'.tr,
                hintStyle: const TextStyle(color: AppTheme.subtleText),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: AppTheme.subtleText),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 38, minHeight: 38),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                filled: true,
                fillColor: const Color(0x0D000000),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: RoomList(
              onRoomTap: (r) =>
                  context.push('/rooms/${Uri.encodeComponent(r.id)}'),
              query: _query,
            ),
          ),
        ],
      ),
    );
  }
}
