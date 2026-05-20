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

/// Pebble-style settings: grouped cards with rounded icon tiles.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
    final lc = LocaleController.instance;
    final mxid = _c.userID ?? '';
    final name = (_profile?.displayName?.isNotEmpty ?? false)
        ? _profile!.displayName!
        : localpartOf(mxid);
    final avatarMxc = _profile?.avatarUrl?.toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        // Mini profile header.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _editAvatar,
                child: Stack(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: avatarMxc != null
                            ? MxcImage(url: avatarMxc, width: 48, height: 48)
                            : Container(
                                color: AppTheme.accentSoft,
                                alignment: Alignment.center,
                                child: Text(
                                  name.isEmpty
                                      ? '?'
                                      : name.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accentDeep),
                                ),
                              ),
                      ),
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
                              Border.all(color: AppTheme.card, width: 1.5),
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
                    Text(name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink)),
                    const SizedBox(height: 1),
                    Text('@${localpartOf(mxid)}',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppTheme.subtleText)),
                  ],
                ),
              ),
            ],
          ),
        ),

        _section('settings.account'.tr, [
          _row(
            icon: PIcon.person,
            iconBg: const Color(0xFF3A6FF0),
            label: 'common.account'.tr,
            value: '@${localpartOf(mxid)}',
          ),
          _row(
            icon: PIcon.lock,
            iconBg: AppTheme.accentDeep,
            label: 'security.title'.tr,
            onTap: () => context.push('/security'),
            last: true,
          ),
        ]),

        _section('settings.appearance'.tr, [
          _langRow(lc),
        ]),

        _section(null, [
          _row(
            icon: PIcon.logout,
            iconBg: const Color(0xFFFF3B30),
            label: 'common.signOut'.tr,
            danger: true,
            chevron: false,
            last: true,
            onTap: () => MatrixClientService.instance.logout(),
          ),
        ]),

        const SizedBox(height: 18),
        const Center(
          child: Text('majoin',
              style: TextStyle(fontSize: 11, color: AppTheme.subtleText)),
        ),
      ],
    );
  }

  Widget _section(String? header, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(header.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppTheme.subtleText)),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required PIcon icon,
    required String label,
    Color? iconBg,
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
    bool chevron = true,
    bool last = false,
    bool danger = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconBg ?? const Color(0x0D000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: PebbleIcon(icon,
                      size: 17,
                      color: iconBg != null
                          ? Colors.white
                          : AppTheme.subtleText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: danger
                              ? const Color(0xFFFF3B30)
                              : AppTheme.ink)),
                ),
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(value,
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.subtleText)),
                  ),
                ?trailing,
                if (chevron && trailing == null)
                  const PebbleIcon(PIcon.chevron,
                      size: 18, color: AppTheme.subtleText),
              ],
            ),
          ),
        ),
        if (!last)
          const Divider(
              height: 0.5, thickness: 0.5, indent: 56, color: AppTheme.dividerColor),
      ],
    );
  }

  Widget _langRow(LocaleController lc) {
    return _row(
      icon: PIcon.globe,
      iconBg: const Color(0xFF34C759),
      label: 'common.language'.tr,
      chevron: false,
      last: true,
      trailing: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'th', label: Text('TH')),
          ButtonSegment(value: 'en', label: Text('EN')),
        ],
        selected: {lc.locale.languageCode},
        onSelectionChanged: (s) => lc.setLocale(Locale(s.first)),
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
