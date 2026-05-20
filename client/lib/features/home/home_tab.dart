import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/mxc_image.dart';
import '../rooms/new_chat_dialog.dart';
import '../stickers/sticker_store.dart';

/// Line-style Home tab: profile card + collapsible Friends / Groups sections +
/// quick actions row.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Profile? _profile;
  bool _friendsExpanded = true;
  bool _groupsExpanded = true;

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

  /// Pick an image and set it as the account avatar.
  Future<void> _editAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    final XFile? x;
    try {
      x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 800,
        maxHeight: 800,
      );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('${'pickerError'.tr}: $e')));
      return;
    }
    if (x == null) return;
    try {
      final bytes = await File(x.path).readAsBytes();
      await _c.setAvatar(MatrixImageFile(bytes: bytes, name: x.name));
      await _loadProfile();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('${'profile.avatarError'.tr}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _c.onSync.stream,
      builder: (context, _) {
        final rooms = _c.rooms.where((r) => r.membership == Membership.join);
        final dms = rooms.where((r) => r.isDirectChat).toList();
        final groups = rooms.where((r) => !r.isDirectChat).toList();
        final friends = <String, Room>{};
        for (final r in dms) {
          final peer = r.directChatMatrixID;
          if (peer != null) friends[peer] = r;
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProfileCard(
              profile: _profile,
              mxid: _c.userID ?? '',
              onEditAvatar: _editAvatar,
            ),
            const SizedBox(height: 8),
            _QuickActions(
              onAddFriend: () async {
                final id = await showNewChatDialog(context);
                if (id != null && context.mounted) {
                  // RoomList stream will pick it up on next sync.
                }
              },
            ),
            const _SectionDivider(),
            _SectionHeader(
              title: 'home.friends'.tr,
              count: friends.length,
              expanded: _friendsExpanded,
              onToggle: () => setState(
                  () => _friendsExpanded = !_friendsExpanded),
            ),
            if (_friendsExpanded)
              ...friends.values.map((r) => _ContactTile(room: r, isDm: true)),
            const _SectionDivider(),
            _SectionHeader(
              title: 'home.groups'.tr,
              count: groups.length,
              expanded: _groupsExpanded,
              onToggle: () => setState(
                  () => _groupsExpanded = !_groupsExpanded),
            ),
            if (_groupsExpanded)
              ...groups.map((r) => _ContactTile(room: r, isDm: false)),
            const _SectionDivider(),
            _SectionHeader(
                title: 'home.officialAccounts'.tr,
                count: 0,
                expanded: false),
            const _SectionDivider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text('common.settings'.tr),
              trailing: const Icon(Icons.chevron_right, color: Colors.black26),
              onTap: () {},
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.mxid,
    required this.onEditAvatar,
  });
  final Profile? profile;
  final String mxid;
  final VoidCallback onEditAvatar;

  String get _displayName {
    final dn = profile?.displayName;
    if (dn != null && dn.isNotEmpty) return dn;
    return localpartOf(mxid);
  }

  @override
  Widget build(BuildContext context) {
    final avatarMxc = profile?.avatarUrl?.toString();
    return InkWell(
      onTap: onEditAvatar,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.lineGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: avatarMxc != null
                      ? MxcImage(url: avatarMxc, width: 56, height: 56)
                      : Text(
                          _displayName.characters.first.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.lineGreen),
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppTheme.lineGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_displayName,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text(localpartOf(mxid),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.subtleText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAddFriend});
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          _ActionTile(
            icon: Icons.person_add_alt_1_outlined,
            label: 'home.addFriend'.tr,
            onTap: onAddFriend,
          ),
          _ActionTile(
            icon: Icons.qr_code_scanner,
            label: 'home.qrCode'.tr,
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.search,
            label: 'home.search'.tr,
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.emoji_emotions_outlined,
            label: 'home.stickerShop'.tr,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const StickerStorePage()),
            ),
          ),
          _ActionTile(
            icon: Icons.palette_outlined,
            label: 'home.themeShop'.tr,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: const Color(0xFF333333)),
              ),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.expanded,
    this.onToggle,
  });
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Text('$title  ',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.subtleText)),
            Text('$count',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.subtleText)),
            const Spacer(),
            if (onToggle != null)
              Icon(expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) => Container(
        height: 6,
        color: const Color(0xFFF5F5F5),
      );
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.room, required this.isDm});
  final Room room;
  final bool isDm;

  @override
  Widget build(BuildContext context) {
    final name = room.getLocalizedDisplayname();
    final avatarHttp =
        room.avatar != null ? _mxcToHttp(room.avatar.toString()) : null;
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: avatarHttp != null
          ? CachedNetworkImage(
              imageUrl: avatarHttp,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            )
          : Container(
              width: 44,
              height: 44,
              color: _colorFor(name),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
            ),
    );

    return InkWell(
      onTap: () => context.push('/rooms/${Uri.encodeComponent(room.id)}'),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            if (!isDm)
              Text('${room.summary.mJoinedMemberCount ?? 0}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }

  static Color _colorFor(String s) {
    const palette = [
      Color(0xFFE57373),
      Color(0xFF64B5F6),
      Color(0xFF81C784),
      Color(0xFFFFB74D),
      Color(0xFFBA68C8),
      Color(0xFF4DB6AC),
      Color(0xFFA1887F),
    ];
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }
}

String? _mxcToHttp(String mxc) {
  final c = MatrixClientService.instance.client;
  final uri = Uri.tryParse(mxc);
  if (uri == null || uri.scheme != 'mxc') return null;
  final hs = c.homeserver;
  if (hs == null) return null;
  return hs
      .replace(
        path: '/_matrix/client/v1/media/download/${uri.host}${uri.path}',
      )
      .toString();
}
