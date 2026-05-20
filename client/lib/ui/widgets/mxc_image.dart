import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/client/matrix_client.dart';

/// Renders a Matrix `mxc://` (or http) image with the auth header required by
/// Synapse 1.100+ authenticated media (`/_matrix/client/v1/media/download`).
class MxcImage extends StatelessWidget {
  const MxcImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolve(url);
    if (resolved == null) {
      return SizedBox(
        width: width,
        height: height,
        child: const ColoredBox(color: Color(0x22000000)),
      );
    }
    return CachedNetworkImage(
      imageUrl: resolved.$1,
      httpHeaders: resolved.$2,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
      ),
    );
  }
}

/// Returns (httpUrl, headers) for an mxc:// or http(s):// URL.
(String, Map<String, String>)? resolveMatrixImage(String url) => _resolve(url);

(String, Map<String, String>)? _resolve(String url) {
  if (url.startsWith('http')) return (url, const {});
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'mxc') return null;
  final c = MatrixClientService.instance.client;
  final hs = c.homeserver;
  final token = c.accessToken;
  if (hs == null || token == null) return null;
  final httpUrl = hs
      .replace(
        path: '/_matrix/client/v1/media/download/${uri.host}${uri.path}',
      )
      .toString();
  return (httpUrl, {'Authorization': 'Bearer $token'});
}
