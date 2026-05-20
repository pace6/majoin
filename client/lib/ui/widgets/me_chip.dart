import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import '../../core/client/matrix_client.dart';

/// Avatar + display name + mxid for the logged-in user.
/// Live updates if profile changes via /sync.
class MeChip extends StatefulWidget {
  const MeChip({super.key, this.onTap, this.compact = false});
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<MeChip> createState() => _MeChipState();
}

class _MeChipState extends State<MeChip> {
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = MatrixClientService.instance.client;
    final id = c.userID;
    if (id == null) return;
    try {
      final p = await c.getProfileFromUserId(id);
      if (mounted) setState(() => _profile = p);
    } catch (_) {
      // ignore — fall back to mxid only
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MatrixClientService.instance.client;
    final mxid = c.userID ?? '?';
    final name = _profile?.displayName ?? _localpart(mxid);
    final avatarUrl = _profile?.avatarUrl;
    final http = avatarUrl != null ? _mxcToHttp(avatarUrl.toString()) : null;

    final avatar = CircleAvatar(
      radius: widget.compact ? 14 : 16,
      backgroundImage: http != null ? CachedNetworkImageProvider(http) : null,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: http == null
          ? Text(name.characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 12))
          : null,
    );

    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        if (!widget.compact) ...[
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(_localpart(mxid),
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ],
      ],
    );

    return widget.onTap == null
        ? body
        : InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: body,
            ),
          );
  }
}

String _localpart(String mxid) =>
    mxid.startsWith('@') && mxid.contains(':')
        ? mxid.substring(1, mxid.indexOf(':'))
        : mxid;

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
