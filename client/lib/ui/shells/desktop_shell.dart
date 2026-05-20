import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import '../../core/client/matrix_client.dart';
import '../../features/rooms/new_chat_dialog.dart';
import '../../features/rooms/room_list.dart';
import '../../features/timeline/timeline_view.dart';
import '../widgets/me_chip.dart';

/// Desktop shell: 3-pane (rail | room list | timeline) — Line desktop layout.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  Room? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _NavRail(),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 320,
            child: Column(
              children: [
                _Header(title: 'Chats'),
                const Divider(height: 1),
                Expanded(
                  child: RoomList(
                    onRoomTap: (r) => setState(() => _selected = r),
                    selectedRoomId: _selected?.id,
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selected == null
                ? const _EmptyTimeline()
                : Column(
                    children: [
                      TimelineAppBar(room: _selected!),
                      Expanded(child: TimelineView(room: _selected!)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _NavRail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: 0,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (_) {},
      destinations: const [
        NavigationRailDestination(
            icon: Icon(Icons.chat_bubble_outline), label: Text('Chats')),
        NavigationRailDestination(
            icon: Icon(Icons.people_outline), label: Text('Contacts')),
        NavigationRailDestination(
            icon: Icon(Icons.settings_outlined), label: Text('Settings')),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const MeChip(),
          const Spacer(),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => showNewChatDialog(context),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => MatrixClientService.instance.logout(),
          ),
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Select a chat',
            style: TextStyle(color: Colors.black54)),
      );
}
