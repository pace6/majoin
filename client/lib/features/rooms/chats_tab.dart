import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../ui/shells/mobile_shell.dart' show showAccountSheet;
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
                  tooltip: 'common.account'.tr,
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () => showAccountSheet(context),
                ),
                IconButton(
                  tooltip: 'rooms.newChat'.tr,
                  icon: const Icon(Icons.add_comment_outlined),
                  onPressed: _newChat,
                ),
              ],
            ),
          ),
          // Search.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'common.search'.tr,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Filter chip row — only "All" for now.
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.lineGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('chats.filterAll'.tr,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lineGreen)),
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
