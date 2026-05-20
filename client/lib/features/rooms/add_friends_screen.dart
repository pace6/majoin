import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/client/matrix_client.dart';
import '../../core/config.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
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

enum _Tab { search, qr, suggested }

/// Add Friends — Pebble layout: pill tabs for Search / QR / Suggested.
class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  _Tab _tab = _Tab.search;
  List<DirectoryUser>? _users;
  String? _error;
  String _query = '';
  String? _openingUserId;
  Profile? _profile;

  Client get _c => MatrixClientService.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
    _loadProfile();
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

  Future<void> _loadProfile() async {
    final id = _c.userID;
    if (id == null) return;
    try {
      final p = await _c.getProfileFromUserId(id);
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  /// MXIDs the user already has a direct chat with.
  Set<String> _connectedPeers() {
    final peers = <String>{};
    for (final r in _c.rooms) {
      if (r.isDirectChat) {
        final p = r.directChatMatrixID;
        if (p != null) peers.add(p);
      }
    }
    return peers;
  }

  Future<void> _openChat(DirectoryUser u) async {
    if (_openingUserId != null) return;
    setState(() => _openingUserId = u.userId);
    try {
      final id = await _c.startDirectChat(u.userId);
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
            // Pill tab bar.
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _pill(_Tab.search, PIcon.search, 'addFriends.search'.tr),
                  _pill(_Tab.qr, PIcon.qr, 'addFriends.qr'.tr),
                  _pill(_Tab.suggested, PIcon.person,
                      'addFriends.suggested'.tr),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _pill(_Tab tab, PIcon icon, String label) {
    final active = _tab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : const Color(0x0D000000),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              PebbleIcon(icon,
                  size: 16,
                  color: active ? Colors.white : AppTheme.subtleText),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppTheme.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
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
    return switch (_tab) {
      _Tab.search => _searchTab(),
      _Tab.qr => _qrTab(),
      _Tab.suggested => _suggestedTab(),
    };
  }

  Widget _searchTab() {
    final users = _users;
    final q = _query.trim().toLowerCase();
    final results = (users == null || q.isEmpty)
        ? <DirectoryUser>[]
        : users
            .where((u) =>
                u.name.toLowerCase().contains(q) ||
                localpartOf(u.userId).toLowerCase().contains(q))
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: TextField(
            autofocus: true,
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
        Expanded(
          child: q.isEmpty
              ? _hint('addFriends.searchEmpty'.tr)
              : users == null
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                      ? _hint('friends.empty'.tr)
                      : ListView(children: results.map(_userTile).toList()),
        ),
      ],
    );
  }

  Widget _suggestedTab() {
    final users = _users;
    if (users == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final connected = _connectedPeers();
    final suggested =
        users.where((u) => !connected.contains(u.userId)).toList();
    if (suggested.isEmpty) return _hint('friends.empty'.tr);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: suggested.map(_userTile).toList()),
    );
  }

  Widget _qrTab() {
    final mxid = _c.userID ?? '';
    final name = (_profile?.displayName?.isNotEmpty ?? false)
        ? _profile!.displayName!
        : localpartOf(mxid);
    final avatarMxc = _profile?.avatarUrl?.toString();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
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
                                      color: AppTheme.accentDeep)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('@${localpartOf(mxid)}',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.subtleText)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: 'https://matrix.to/#/$mxid',
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: AppTheme.ink),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppTheme.ink),
              ),
              const SizedBox(height: 16),
              Text('addFriends.qrHint'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.subtleText)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hint(String text) => Center(
        child: Text(text,
            style: const TextStyle(color: AppTheme.subtleText)),
      );

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
