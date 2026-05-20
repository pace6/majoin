import 'package:flutter/material.dart';
import '../../ui/widgets/mxc_image.dart';
import 'sticker_pack.dart';

/// Renders a sticker image — bundled asset or remote mxc.
class StickerThumb extends StatelessWidget {
  const StickerThumb({super.key, required this.sticker, this.size});
  final StickerImage sticker;
  final double? size;

  @override
  Widget build(BuildContext context) {
    if (sticker.source == StickerSource.asset) {
      return Image.asset(sticker.assetPath, width: size, height: size);
    }
    return MxcImage(
      url: sticker.url,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Renders a pack cover (asset or mxc URL string).
class StickerCover extends StatelessWidget {
  const StickerCover({super.key, required this.url, this.size = 56});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return SizedBox(width: size, height: size);
    }
    if (url.startsWith('asset:')) {
      // Bundled cover paths aren't packId-scoped here; only the default pack
      // uses asset covers, so resolve against majoin_v1.
      return Image.asset(
        'assets/stickers/majoin_v1/${url.substring('asset:'.length)}',
        width: size,
        height: size,
      );
    }
    return MxcImage(url: url, width: size, height: size, fit: BoxFit.contain);
  }
}
