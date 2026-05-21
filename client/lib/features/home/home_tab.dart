import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/avatar.dart';
import '../../core/util/room_ext.dart';
import '../../core/util/mxid.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/pebble_icon.dart';
import '../../ui/widgets/mxc_image.dart';

/// Pebble-style Home: greeting strip, friends row, quick actions, groups card.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Profile? _profile;
  Client get _c => MatrixClientService.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final id = _c.userID;
    if (id == null) return;
    try {
      final p = await _c.getProfileFromUserId(id);
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'home.morning'.tr;
    if (h < 18) return 'home.afternoon'.tr;
    return 'home.evening'.tr;
  }

  void _openRoom(Room r) =>
      context.push('/rooms/${Uri.encodeComponent(r.id)}');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _c.onSync.stream,
      builder: (context, _) {
        final joined =
            _c.rooms.where((r) => r.membership == Membership.join);
        final friends = joined.where(isOneToOne).toList();
        final groups = joined.where((r) => !isOneToOne(r)).toList();
        final mxid = _c.userID ?? '';
        final name = (_profile?.displayName?.isNotEmpty ?? false)
            ? _profile!.displayName!
            : localpartOf(mxid);
        final firstName = name.split(' ').first;

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Greeting strip.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _editAvatar,
                    child: Stack(
                      children: [
                        _Avatar(
                          mxc: _profile?.avatarUrl?.toString(),
                          label: name,
                          size: 44,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppTheme.bg, width: 1.5),
                            ),
                            child: const PebbleIcon(PIcon.camera,
                                size: 9, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$_greeting,',
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.subtleText)),
                        Text(firstName,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Friends row.
            _sectionLabel('home.friends'.tr),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _addFriendCircle(),
                  for (final r in friends) _friendCircle(r),
                ],
              ),
            ),

            // Groups row — same circle layout as Friends.
            _sectionLabel('home.groups'.tr),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _addGroupCircle(),
                  for (final r in groups) _groupCircle(r),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink)),
      );

  void _addFriends() => context.push('/add-friends');

  Future<void> _newGroup() async {
    final id = await context.push<String>('/create-group');
    if (id != null && mounted) {
      context.push('/rooms/${Uri.encodeComponent(id)}');
    }
  }

  /// "Create group" circle — mirrors [_addFriendCircle].
  Widget _addGroupCircle() {
    return GestureDetector(
      onTap: _newGroup,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0x33000000), width: 1.5),
              ),
              child: const PebbleIcon(PIcon.plus,
                  size: 20, color: AppTheme.subtleText),
            ),
            const SizedBox(height: 6),
            Text('home.add'.tr,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }

  Widget _groupCircle(Room r) {
    final name = roomTitleWithCount(r);
    return GestureDetector(
      onTap: () => _openRoom(r),
      child: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              _Avatar(
                  mxc: r.avatar?.toString(),
                  label: roomTitle(r),
                  size: 56),
              const SizedBox(height: 6),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAvatar() async {
    if (await pickAndSetAvatar(context) && mounted) await _loadProfile();
  }

  Widget _addFriendCircle() {
    return GestureDetector(
      onTap: _addFriends,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0x33000000),
                    width: 1.5,
                    style: BorderStyle.solid),
              ),
              child: const PebbleIcon(PIcon.plus,
                  size: 20, color: AppTheme.subtleText),
            ),
            const SizedBox(height: 6),
            Text('home.add'.tr,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }

  Widget _friendCircle(Room r) {
    final name = roomTitle(r);
    return GestureDetector(
      onTap: () => _openRoom(r),
      child: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              _Avatar(mxc: r.avatar?.toString(), label: name, size: 56),
              const SizedBox(height: 6),
              Text(name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.ink)),
            ],
          ),
        ),
      ),
    );
  }

}

/// Round avatar with an mxc image or initial fallback.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.mxc,
    required this.label,
    required this.size,
  });
  final String? mxc;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = label.isEmpty ? '?' : label.characters.first.toUpperCase();
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: mxc != null && mxc!.isNotEmpty
            ? MxcImage(url: mxc!, width: size, height: size)
            : Container(
                color: AppTheme.accentSoft,
                alignment: Alignment.center,
                child: Text(letter,
                    style: TextStyle(
                        fontSize: size * 0.36,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentDeep)),
              ),
      ),
    );
  }
}
