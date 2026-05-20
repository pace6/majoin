import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import '../../core/config.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/mxc_image.dart';
import 'add_friends_screen.dart' show DirectoryUser;

/// Pick a registered user from the directory and invite them into [room].
/// Avoids free-text usernames so you can't invite people who don't exist.
Future<void> showAddMemberSheet(BuildContext context, Room room) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddMemberSheet(room: room),
  );
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({required this.room});
  final Room room;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  List<DirectoryUser>? _users;
  String? _error;
  String _query = '';
  String? _invitingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.stickerApi}/api/users'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      // Already-in-room members can't be invited again.
      final inRoom =
          widget.room.getParticipants().map((u) => u.id).toSet();
      final list = (body['users'] as List)
          .map((u) => DirectoryUser.fromJson(u as Map<String, dynamic>))
          .where((u) => !inRoom.contains(u.userId))
          .toList()
        ..sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _users = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _invite(DirectoryUser u) async {
    if (_invitingId != null) return;
    setState(() => _invitingId = u.userId);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.room.invite(u.userId);
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('group.invited'.tr)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      if (mounted) setState(() => _invitingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    final q = _query.trim().toLowerCase();
    final shown = users == null
        ? const <DirectoryUser>[]
        : (q.isEmpty
            ? users
            : users
                .where((u) =>
                    u.name.toLowerCase().contains(q) ||
                    localpartOf(u.userId).toLowerCase().contains(q))
                .toList());

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('group.addMember'.tr,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'friends.search'.tr,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0x0D000000),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text('friends.loadError'.tr,
                          style:
                              const TextStyle(color: AppTheme.subtleText)))
                  : users == null
                      ? const Center(child: CircularProgressIndicator())
                      : shown.isEmpty
                          ? Center(
                              child: Text('friends.empty'.tr,
                                  style: const TextStyle(
                                      color: AppTheme.subtleText)))
                          : ListView.builder(
                              itemCount: shown.length,
                              itemBuilder: (_, i) => _tile(shown[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(DirectoryUser u) {
    final busy = _invitingId == u.userId;
    final letter =
        u.name.isEmpty ? '?' : u.name.characters.first.toUpperCase();
    return ListTile(
      leading: ClipOval(
        child: SizedBox(
          width: 44,
          height: 44,
          child: u.avatarUrl != null
              ? MxcImage(url: u.avatarUrl!, width: 44, height: 44)
              : Container(
                  color: AppTheme.accentSoft,
                  alignment: Alignment.center,
                  child: Text(letter,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentDeep)),
                ),
        ),
      ),
      title: Text(u.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text('@${localpartOf(u.userId)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, color: AppTheme.subtleText)),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      onTap: busy ? null : () => _invite(u),
    );
  }
}
