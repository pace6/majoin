import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
import '../../features/home/home_tab.dart';
import '../../features/rooms/chats_tab.dart';
import '../../features/rooms/user_directory.dart';
import '../../features/timeline/timeline_view.dart';
import '../theme/app_theme.dart';

/// Mobile shell: Home / Chats / Friends.
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
    _TabSpec('tab.friends', Icons.people_outline, Icons.people),
  ];

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => const HomeTab(),
      1 => const ChatsTab(),
      2 => const UserDirectory(),
      _ => const SizedBox.shrink(),
    };

    return Scaffold(
      // Chats draws its own large-title header; Home and Friends use the bar.
      appBar: _tab == 1
          ? null
          : AppBar(
              titleSpacing: 16,
              title: Text(_tabs[_tab].label.tr,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
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

/// Account bottom sheet — profile, language, security, sign out.
Future<void> showAccountSheet(BuildContext context) async {
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
            subtitle: Text(localpartOf(mxid)),
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
