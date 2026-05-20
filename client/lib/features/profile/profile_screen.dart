import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/avatar.dart';
import '../../core/util/mxid.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/pebble_icon.dart';
import '../../ui/widgets/mxc_image.dart';

/// Pebble-style profile: accent hero banner, avatar, stats, action cards.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  Client get _c => MatrixClientService.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _c.userID;
    if (id == null) return;
    try {
      final p = await _c.getProfileFromUserId(id);
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  Future<void> _editAvatar() async {
    if (await pickAndSetAvatar(context) && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final mxid = _c.userID ?? '';
    final name = (_profile?.displayName?.isNotEmpty ?? false)
        ? _profile!.displayName!
        : localpartOf(mxid);
    final avatarMxc = _profile?.avatarUrl?.toString();

    final joined = _c.rooms.where((r) => r.membership == Membership.join);
    final dms = joined.where((r) => r.isDirectChat).length;
    final groups = joined.where((r) => !r.isDirectChat).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        // Hero banner.
        Container(
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.accentSoft, AppTheme.accent],
            ),
          ),
        ),
        // Avatar + identity, pulled up over the banner.
        Transform.translate(
          offset: const Offset(0, -44),
          child: Column(
            children: [
              GestureDetector(
                onTap: _editAvatar,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.bg, shape: BoxShape.circle),
                  child: Stack(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: avatarMxc != null
                              ? MxcImage(url: avatarMxc, width: 88, height: 88)
                              : Container(
                                  color: AppTheme.accentSoft,
                                  alignment: Alignment.center,
                                  child: Text(
                                    name.isEmpty
                                        ? '?'
                                        : name.characters.first.toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accentDeep),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.bg, width: 2),
                          ),
                          child: const PebbleIcon(PIcon.camera,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(name,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink)),
              const SizedBox(height: 2),
              Text('@${localpartOf(mxid)}',
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.subtleText)),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: Column(
            children: [
              // Stats.
              Row(
                children: [
                  _stat('$dms', 'profile.statFriends'.tr),
                  const SizedBox(width: 10),
                  _stat('$groups', 'profile.statGroups'.tr),
                  const SizedBox(width: 10),
                  _stat('${dms + groups}', 'profile.statChats'.tr),
                ],
              ),
              const SizedBox(height: 14),
              // Action cards.
              Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      icon: PIcon.qr,
                      label: 'profile.myQr'.tr,
                      tag: 'profile.share'.tr,
                      onTap: () => _showQr(mxid),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionCard(
                      icon: PIcon.plus,
                      label: 'home.addFriend'.tr.replaceAll('\n', ' '),
                      tag: 'profile.invite'.tr,
                      onTap: () => context.push('/add-friends'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required PIcon icon,
    required String label,
    required String tag,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PebbleIcon(icon, size: 22, color: AppTheme.accent),
                Text(tag,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.subtleText)),
              ],
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink)),
          ],
        ),
      ),
    );
  }

  void _showQr(String mxid) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile.myQr'.tr),
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
