import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    final name = (_profile?.displayName?.isNotEmpty ?? false)
        ? _profile!.displayName!
        : localpartOf(mxid);
    final avatarMxc = _profile?.avatarUrl?.toString();
    // matrix.to is the canonical share URL for a Matrix user: any client
    // that understands the format can resolve the mxid back. Plain mxid
    // would work too but is harder to scan into other apps.
    final shareUrl = 'https://matrix.to/#/$mxid';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _QrSheet(
        name: name,
        mxid: mxid,
        avatarMxc: avatarMxc,
        shareUrl: shareUrl,
      ),
    );
  }
}

class _QrSheet extends StatelessWidget {
  const _QrSheet({
    required this.name,
    required this.mxid,
    required this.avatarMxc,
    required this.shareUrl,
  });

  final String name;
  final String mxid;
  final String? avatarMxc;
  final String shareUrl;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle.
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.subtleText.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('profile.myQr'.tr,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink)),
            const SizedBox(height: 4),
            Text('profile.qrHint'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.subtleText)),
            const SizedBox(height: 18),
            // QR card.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: avatarMxc != null
                          ? MxcImage(url: avatarMxc!, width: 56, height: 56)
                          : Container(
                              color: AppTheme.accentSoft,
                              alignment: Alignment.center,
                              child: Text(
                                name.isEmpty
                                    ? '?'
                                    : name.characters.first.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accentDeep),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink)),
                  const SizedBox(height: 2),
                  Text('@${localpartOf(mxid)}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.subtleText)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: QrImageView(
                      data: shareUrl,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppTheme.ink,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppTheme.ink,
                      ),
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                          color: AppTheme.subtleText.withValues(alpha: .3)),
                      foregroundColor: AppTheme.ink,
                    ),
                    icon: const PebbleIcon(PIcon.close,
                        size: 16, color: AppTheme.ink),
                    label: Text('profile.qrClose'.tr),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: mxid));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('profile.qrCopied'.tr),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: AppTheme.accent,
                    ),
                    icon: const Icon(Icons.copy_rounded,
                        size: 16, color: Colors.white),
                    label: Text('profile.qrCopy'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
