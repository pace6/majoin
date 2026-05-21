import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import '../../core/client/matrix_client.dart';
import '../../core/config.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
import '../../core/util/room_ext.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/pebble_icon.dart';
import '../../ui/widgets/mxc_image.dart';

/// A registered user from the backend `/api/users` directory.
class DirectoryUser {
  DirectoryUser({required this.userId, required this.displayName, this.avatarUrl});
  final String userId;
  final String displayName;
  final String? avatarUrl;

  factory DirectoryUser.fromJson(Map<String, dynamic> j) => DirectoryUser(
        userId: j['userId'] as String,
        displayName: (j['displayname'] as String?) ?? '',
        avatarUrl: (j['avatarUrl'] as String?)?.isNotEmpty == true
            ? j['avatarUrl'] as String
            : null,
      );

  String get name => displayName.isNotEmpty ? displayName : localpartOf(userId);
}

/// Add Friends — a single search screen. The directory shows as suggestions
/// until the user types a query; a "new group" shortcut sits above the list.
class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  List<DirectoryUser>? _users;
  String? _error;
  String _query = '';
  String? _openingUserId;

  Client get _c => MatrixClientService.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _users = null;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.stickerApi}/api/users'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['users'] as List)
          .map((u) => DirectoryUser.fromJson(u as Map<String, dynamic>))
          .toList();
      list.removeWhere((u) => u.userId == _c.userID);
      list.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _users = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _openChat(DirectoryUser u) async {
    if (_openingUserId != null) return;
    setState(() => _openingUserId = u.userId);
    try {
      // Reuse an existing chat with this peer instead of creating a duplicate.
      final id = findDirectRoom(_c, u.userId)?.id ??
          await _c.startDirectChat(u.userId);
      if (mounted) context.push('/rooms/${Uri.encodeComponent(id)}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'friends.openError'.tr}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingUserId = null);
    }
  }

  Future<void> _newGroup() async {
    final id = await context.push<String>('/create-group');
    if (id != null && mounted) {
      context.push('/rooms/${Uri.encodeComponent(id)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('addFriends.title'.tr,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search field.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'addFriends.searchHint'.tr,
                  prefixIcon: const PebbleIcon(PIcon.search, size: 20),
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
            // New group shortcut.
            _newGroupTile(),
            const Divider(height: 1, thickness: 0.5),
            Expanded(child: _list()),
          ],
        ),
      ),
    );
  }

  Widget _newGroupTile() {
    return InkWell(
      onTap: _newGroup,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppTheme.accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_add_outlined,
                  size: 22, color: AppTheme.accentDeep),
            ),
            const SizedBox(width: 12),
            Text('newChat.group'.tr,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('friends.loadError'.tr,
                style: const TextStyle(color: AppTheme.subtleText)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: Text('common.retry'.tr)),
          ],
        ),
      );
    }
    final users = _users;
    if (users == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final q = _query.trim().toLowerCase();
    final List<DirectoryUser> shown;
    String? header;
    if (q.isEmpty) {
      // No query — show the whole directory. (Don't hide people already in
      // a chat; tapping them just reopens the existing room.)
      shown = users;
      header = 'addFriends.suggested'.tr;
    } else {
      shown = users
          .where((u) =>
              u.name.toLowerCase().contains(q) ||
              localpartOf(u.userId).toLowerCase().contains(q))
          .toList();
    }
    if (shown.isEmpty) {
      return Center(
        child: Text('friends.empty'.tr,
            style: const TextStyle(color: AppTheme.subtleText)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(header,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.subtleText)),
              ),
            ),
          ...shown.map(_userTile),
        ],
      ),
    );
  }

  Widget _userTile(DirectoryUser u) {
    final busy = _openingUserId == u.userId;
    final letter = u.name.isEmpty ? '?' : u.name.characters.first.toUpperCase();
    return ListTile(
      leading: ClipOval(
        child: SizedBox(
          width: 46,
          height: 46,
          child: u.avatarUrl != null
              ? MxcImage(url: u.avatarUrl!, width: 46, height: 46)
              : Container(
                  color: AppTheme.accentSoft,
                  alignment: Alignment.center,
                  child: Text(letter,
                      style: const TextStyle(
                          fontSize: 18,
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
          : FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _openChat(u),
              child: Text('addFriends.add'.tr,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),
      onTap: busy ? null : () => _openChat(u),
    );
  }
}
