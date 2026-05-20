import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/mxc_image.dart';
import '../stickers/sticker_store.dart';

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
        final friends = joined.where((r) => r.isDirectChat).toList();
        final groups = joined.where((r) => !r.isDirectChat).toList();
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
                  _Avatar(
                    mxc: _profile?.avatarUrl?.toString(),
                    label: name,
                    size: 44,
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

            // Quick actions.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _quickAction(
                    icon: Icons.qr_code_2,
                    label: 'home.qrCode'.tr.replaceAll('\n', ' '),
                    tint: const Color(0xFF3A6FF0),
                    onTap: () => _showQr(mxid),
                  ),
                  const SizedBox(width: 10),
                  _quickAction(
                    icon: Icons.person_add_alt_1,
                    label: 'home.addFriend'.tr.replaceAll('\n', ' '),
                    tint: AppTheme.accent,
                    onTap: _addFriends,
                  ),
                  const SizedBox(width: 10),
                  _quickAction(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'home.stickerShop'.tr.replaceAll('\n', ' '),
                    tint: const Color(0xFFE86A5C),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const StickerStorePage()),
                    ),
                  ),
                ],
              ),
            ),

            // Groups.
            _sectionLabel('home.groups'.tr),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: groups.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('home.noGroups'.tr,
                            style: const TextStyle(
                                color: AppTheme.subtleText, fontSize: 13)),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < groups.length; i++)
                            _groupRow(groups[i], i == groups.length - 1),
                        ],
                      ),
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
              child: const Icon(Icons.add,
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
    final name = r.getLocalizedDisplayname();
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

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(height: 7),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupRow(Room r, bool last) {
    final name = r.getLocalizedDisplayname();
    final members = r.summary.mJoinedMemberCount ?? 0;
    return Column(
      children: [
        InkWell(
          onTap: () => _openRoom(r),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _Avatar(
                    mxc: r.avatar?.toString(),
                    label: name,
                    size: 40,
                    square: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink)),
                      const SizedBox(height: 1),
                      Text('$members ${'home.members'.tr}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppTheme.subtleText)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppTheme.subtleText),
              ],
            ),
          ),
        ),
        if (!last)
          const Divider(
              height: 0.5,
              thickness: 0.5,
              indent: 66,
              color: AppTheme.dividerColor),
      ],
    );
  }

  void _showQr(String mxid) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('home.qrCode'.tr.replaceAll('\n', ' ')),
        content: Text('@${localpartOf(mxid)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.ok'.tr),
          ),
        ],
      ),
    );
  }
}

/// Round (or rounded-square) avatar with an mxc image or initial fallback.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.mxc,
    required this.label,
    required this.size,
    this.square = false,
  });
  final String? mxc;
  final String label;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final radius =
        square ? BorderRadius.circular(size * 0.28) : BorderRadius.circular(size);
    final letter = label.isEmpty ? '?' : label.characters.first.toUpperCase();
    return ClipRRect(
      borderRadius: radius,
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
