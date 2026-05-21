import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import '../../core/client/matrix_client.dart';
import '../../core/config.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/mxc_image.dart';
import '../../ui/widgets/pebble_icon.dart';
import 'add_friends_screen.dart';

/// Create-group screen — set a name and multi-select members from the user
/// directory. Pops the new room id on success.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameCtl = TextEditingController();
  List<DirectoryUser>? _users;
  String? _error;
  String _query = '';
  final _selected = <String>{};
  bool _busy = false;

  Client get _c => MatrixClientService.instance.client;

  @override
  void initState() {
    super.initState();
    _nameCtl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
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

  Future<void> _create() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final id = await _c.createGroupChat(
        groupName: name,
        invite: _selected.isEmpty ? null : _selected.toList(),
      );
      if (mounted) context.pop(id);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'newChat.createError'.tr}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _nameCtl.text.trim().isNotEmpty && !_busy;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('newChat.groupTitle'.tr,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: canCreate ? _create : null,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('newChat.create'.tr,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Group name.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _nameCtl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'newChat.groupName'.tr,
                  prefixIcon:
                      const Icon(Icons.group_outlined, size: 20),
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
            // Member search.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
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
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      '${'newChat.selected'.tr} ${_selected.length}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent)),
                ),
              ),
            const Divider(height: 1, thickness: 0.5),
            Expanded(child: _list()),
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
    final shown = q.isEmpty
        ? users
        : users
            .where((u) =>
                u.name.toLowerCase().contains(q) ||
                localpartOf(u.userId).toLowerCase().contains(q))
            .toList();
    if (shown.isEmpty) {
      return Center(
        child: Text('friends.empty'.tr,
            style: const TextStyle(color: AppTheme.subtleText)),
      );
    }
    return ListView(children: shown.map(_userTile).toList());
  }

  Widget _userTile(DirectoryUser u) {
    final selected = _selected.contains(u.userId);
    final letter = u.name.isEmpty ? '?' : u.name.characters.first.toUpperCase();
    return ListTile(
      onTap: () => setState(() {
        selected ? _selected.remove(u.userId) : _selected.add(u.userId);
      }),
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
      trailing: _SelectDot(selected: selected),
    );
  }
}

/// LINE-style selection circle — filled check when picked, empty otherwise.
class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppTheme.accent : Colors.transparent,
        border: Border.all(
            color: selected ? AppTheme.accent : const Color(0x40000000),
            width: 1.6),
      ),
      child: selected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
