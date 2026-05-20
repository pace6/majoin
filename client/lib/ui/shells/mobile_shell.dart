import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../features/home/home_tab.dart';
import '../../features/rooms/new_chat_dialog.dart';
import '../../features/rooms/room_list.dart';
import '../../features/timeline/timeline_view.dart';
import '../theme/app_theme.dart';
import '../widgets/me_chip.dart';

/// Mobile shell: Line-style 5 tabs.
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _tab = 1; // Default to Chats

  static const _tabs = <_TabSpec>[
    _TabSpec('tab.home', Icons.home_outlined, Icons.home),
    _TabSpec('tab.chats', Icons.chat_bubble_outline, Icons.chat_bubble),
    _TabSpec('tab.voom', Icons.play_circle_outline, Icons.play_circle),
    _TabSpec('tab.news', Icons.article_outlined, Icons.article),
    _TabSpec('tab.wallet', Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet),
  ];

  String get _title => _tabs[_tab].label.tr;

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => const HomeTab(),
      1 => RoomList(
          onRoomTap: (r) =>
              context.push('/rooms/${Uri.encodeComponent(r.id)}'),
        ),
      2 => const _PlaceholderTab(label: 'VOOM', subtitle: 'Short videos'),
      3 => const _PlaceholderTab(label: 'News', subtitle: 'Daily feed'),
      4 => const _PlaceholderTab(label: 'Wallet', subtitle: 'Pay & rewards'),
      _ => const SizedBox.shrink(),
    };

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: _tab == 1
            ? MeChip(onTap: () => _showAccountSheet(context))
            : Text(_title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 18)),
        actions: _tab == 1
            ? [
                IconButton(
                  tooltip: 'rooms.newChat'.tr,
                  icon: const Icon(Icons.add_comment_outlined),
                  onPressed: () async {
                    final id = await showNewChatDialog(context);
                    if (id != null && context.mounted) {
                      context.push('/rooms/${Uri.encodeComponent(id)}');
                    }
                  },
                ),
                IconButton(
                  tooltip: 'common.search'.tr,
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
              ]
            : [
                IconButton(
                    icon: const Icon(Icons.search), onPressed: () {}),
              ],
      ),
      body: body,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
              top: BorderSide(color: AppTheme.dividerColor, width: 0.5)),
          color: Colors.white,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      spec: _tabs[i],
                      selected: _tab == i,
                      onTap: () => setState(() => _tab = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.iconActive);
  final String label;
  final IconData icon;
  final IconData iconActive;
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.spec,
    required this.selected,
    required this.onTap,
  });
  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1A1A1A) : const Color(0xFF9E9E9E);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? spec.iconActive : spec.icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(spec.label.tr,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label, required this.subtitle});
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppTheme.subtleText)),
        ],
      ),
    );
  }
}

Future<void> _showAccountSheet(BuildContext context) async {
  final mxid = MatrixClientService.instance.client.userID ?? '';
  final lc = LocaleController.instance;
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text('common.account'.tr),
            subtitle: Text(mxid),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text('common.language'.tr),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'th', label: Text('TH')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {lc.locale.languageCode},
              onSelectionChanged: (s) =>
                  lc.setLocale(Locale(s.first)),
              showSelectedIcon: false,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: Text('security.title'.tr),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              context.push('/security');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text('common.signOut'.tr,
                style: const TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.of(sheetCtx).pop();
              await MatrixClientService.instance.logout();
            },
          ),
        ],
      ),
    ),
  );
}

class MobileTimelinePage extends StatelessWidget {
  const MobileTimelinePage({super.key, required this.room});
  final Room room;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TimelineAppBar(
        room: room,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: TimelineView(room: room),
    );
  }
}
