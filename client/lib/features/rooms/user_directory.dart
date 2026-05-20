import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/client/matrix_client.dart';
import '../../core/config.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
import '../../ui/theme/app_theme.dart';
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
}

/// Friends tab: every registered user, searchable. Tapping one opens (or
/// reuses) a direct chat with them.
class UserDirectory extends StatefulWidget {
  const UserDirectory({super.key, this.query});

  /// External search text (from the shell app bar). Null = show internal box.
  final String? query;

  @override
  State<UserDirectory> createState() => _UserDirectoryState();
}

class _UserDirectoryState extends State<UserDirectory> {
  List<DirectoryUser>? _users;
  String? _error;
  String _localQuery = '';
  String? _openingUserId;

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
      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}';
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['users'] as List)
          .map((u) => DirectoryUser.fromJson(u as Map<String, dynamic>))
          .toList();
      final me = MatrixClientService.instance.client.userID;
      list.removeWhere((u) => u.userId == me); // don't list yourself
      list.sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      if (mounted) setState(() => _users = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _openChat(DirectoryUser u) async {
    if (_openingUserId != null) return;
    setState(() => _openingUserId = u.userId);
    try {
      final id = await MatrixClientService.instance.client
          .startDirectChat(u.userId);
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

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _Centered(
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
      return const _Centered(child: CircularProgressIndicator());
    }

    final q = (widget.query ?? _localQuery).trim().toLowerCase();
    final filtered = q.isEmpty
        ? users
        : users
            .where((u) =>
                u.displayName.toLowerCase().contains(q) ||
                localpartOf(u.userId).toLowerCase().contains(q))
            .toList();

    return Column(
      children: [
        if (widget.query == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'friends.search'.tr,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onChanged: (v) => setState(() => _localQuery = v),
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? _Centered(
                  child: Text('friends.empty'.tr,
                      style: const TextStyle(color: AppTheme.subtleText)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _UserTile(
                      user: filtered[i],
                      busy: _openingUserId == filtered[i].userId,
                      onTap: () => _openChat(filtered[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.busy, required this.onTap});
  final DirectoryUser user;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.isNotEmpty
        ? user.displayName
        : localpartOf(user.userId);
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return ListTile(
      leading: SizedBox(
        width: 44,
        height: 44,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: user.avatarUrl != null
              ? MxcImage(url: user.avatarUrl!, width: 44, height: 44)
              : Container(
                  color: AppTheme.lineGreen.withValues(alpha: 0.15),
                  alignment: Alignment.center,
                  child: Text(letter,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.lineGreen)),
                ),
        ),
      ),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(localpartOf(user.userId),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppTheme.subtleText)),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chat_bubble_outline, size: 20),
      onTap: busy ? null : onTap,
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(child: child);
}
