import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../ui/widgets/pebble_icon.dart';
import '../../ui/theme/app_theme.dart';
import 'room_list.dart';

/// Chats screen: a search field with add-friend / add-group / add-meeting
/// actions, then the room list.
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

  void _addFriend() => context.push('/add-friends');

  Future<void> _addGroup() async {
    final id = await context.push<String>('/create-group');
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
          // Search + action icons.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtl,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'common.search'.tr,
                      hintStyle:
                          const TextStyle(color: AppTheme.subtleText),
                      prefixIcon: const PebbleIcon(PIcon.search,
                          size: 20, color: AppTheme.subtleText),
                      prefixIconConstraints: const BoxConstraints(
                          minWidth: 38, minHeight: 38),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 9),
                      filled: true,
                      fillColor: const Color(0x0D000000),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'newChat.optChat'.tr,
                  icon: const Icon(Icons.person_add_outlined),
                  onPressed: _addFriend,
                ),
                IconButton(
                  tooltip: 'newChat.optGroup'.tr,
                  icon: const Icon(Icons.group_add_outlined),
                  onPressed: _addGroup,
                ),
                // Meeting (group call) isn't implemented yet.
                IconButton(
                  tooltip: 'newChat.optMeeting'.tr,
                  icon: const Icon(Icons.video_call_outlined),
                  onPressed: null,
                ),
              ],
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
