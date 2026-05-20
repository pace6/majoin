import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import '../../core/i18n/strings.dart';
import '../../features/home/home_tab.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/rooms/chats_tab.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/timeline/timeline_view.dart';
import '../theme/app_theme.dart';
import '../widgets/pebble_icon.dart';

/// Mobile shell: Home / Chats / Profile / Settings (Pebble layout).
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _tab = 1; // Default to Chats

  static const _tabs = <_TabSpec>[
    _TabSpec('tab.home', PIcon.home),
    _TabSpec('tab.chats', PIcon.chat),
    _TabSpec('tab.profile', PIcon.person),
    _TabSpec('tab.settings', PIcon.gear),
  ];

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => const HomeTab(),
      1 => const ChatsTab(),
      2 => const ProfileScreen(),
      3 => const SettingsScreen(),
      _ => const SizedBox.shrink(),
    };

    return Scaffold(
      // Chats draws its own large-title header; the rest use a plain bar.
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
          color: AppTheme.bg,
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
  const _TabSpec(this.label, this.icon);
  final String label;
  final PIcon icon;
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
    final color = selected ? AppTheme.accent : AppTheme.subtleText;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PebbleIcon(spec.icon, color: color, size: 24, filled: selected),
            const SizedBox(height: 3),
            Text(spec.label.tr,
                style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
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
