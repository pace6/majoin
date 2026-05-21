import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import '../../core/client/matrix_client.dart';
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
  int _tab = 0; // Default to Home
  StreamSubscription<SyncUpdate>? _sync;

  static const _tabs = <_TabSpec>[
    _TabSpec('tab.home', PIcon.home),
    _TabSpec('tab.chats', PIcon.chat),
    _TabSpec('tab.profile', PIcon.person),
    _TabSpec('tab.settings', PIcon.gear),
  ];

  @override
  void initState() {
    super.initState();
    // Rebuild on every sync so the Chats badge stays current.
    _sync = MatrixClientService.instance.client.onSync.stream
        .listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    _sync?.cancel();
    super.dispose();
  }

  /// Chats needing attention — unread, marked unread, or pending invites.
  int get _unreadChats {
    final c = MatrixClientService.instance.client;
    return c.rooms
        .where((r) =>
            r.membership == Membership.invite ||
            r.notificationCount > 0 ||
            r.markedUnread)
        .length;
  }

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
      // No page-title bar — each tab manages its own header.
      body: SafeArea(bottom: false, child: body),
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
                      badge: i == 1 ? _unreadChats : 0,
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
    this.badge = 0,
  });
  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.accent : AppTheme.subtleText;
    Widget icon =
        PebbleIcon(spec.icon, color: color, size: 24, filled: selected);
    if (badge > 0) {
      icon = Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(right: -7, top: -4, child: _Badge(count: badge)),
        ],
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
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

/// Red unread-count pill shown on the Chats tab icon.
class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.bg, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              height: 1)),
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
