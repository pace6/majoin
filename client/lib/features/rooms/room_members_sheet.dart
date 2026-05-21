import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/mxc_image.dart';

/// Bottom sheet listing a room's members — owners and admins first.
Future<void> showRoomMembersSheet(BuildContext context, Room room) async {
  // Make sure the full member list is loaded, not just the summary heroes.
  await room.requestParticipants();
  if (!context.mounted) return;

  PowerLevelRole roleOf(User u) => room.getPowerLevelByUserId(u.id).role;

  final members = room
      .getParticipants()
      .where((u) =>
          u.membership == Membership.join ||
          u.membership == Membership.invite)
      .toList()
    ..sort((a, b) {
      final byRole = roleOf(b).index.compareTo(roleOf(a).index);
      if (byRole != 0) return byRole;
      return a
          .calcDisplayname()
          .toLowerCase()
          .compareTo(b.calcDisplayname().toLowerCase());
    });

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${'members.title'.tr} (${members.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in members)
                  _MemberTile(member: m, role: roleOf(m)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.role});
  final User member;
  final PowerLevelRole role;

  @override
  Widget build(BuildContext context) {
    final name = member.calcDisplayname();
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final mxc = member.avatarUrl?.toString();
    final invited = member.membership == Membership.invite;
    final roleLabel = switch (role) {
      PowerLevelRole.owner => 'members.owner'.tr,
      PowerLevelRole.admin => 'members.admin'.tr,
      PowerLevelRole.moderator => 'members.mod'.tr,
      PowerLevelRole.user => null,
    };

    return ListTile(
      leading: ClipOval(
        child: SizedBox(
          width: 42,
          height: 42,
          child: mxc != null && mxc.isNotEmpty
              ? MxcImage(url: mxc, width: 42, height: 42)
              : Container(
                  color: AppTheme.accentSoft,
                  alignment: Alignment.center,
                  child: Text(letter,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentDeep)),
                ),
        ),
      ),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text('@${localpartOf(member.id)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              const TextStyle(fontSize: 12.5, color: AppTheme.subtleText)),
      trailing: invited
          ? Text('members.invited'.tr,
              style: const TextStyle(
                  fontSize: 11.5, color: AppTheme.subtleText))
          : roleLabel == null
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(roleLabel,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentDeep)),
                ),
    );
  }
}
