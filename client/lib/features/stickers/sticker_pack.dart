/// Sticker data models. A sticker image is either bundled in the app
/// (`asset:foo.png`) or hosted on the homeserver (`mxc://...`).

enum StickerSource { asset, mxc }

class StickerImage {
  StickerImage({
    required this.id,
    required this.packId,
    required this.url,
    required this.body,
    required this.width,
    required this.height,
  });

  final String id;
  final String packId;

  /// `asset:foo.png` for bundled, `mxc://...` for remote.
  final String url;
  final String body;
  final int width;
  final int height;

  StickerSource get source =>
      url.startsWith('mxc://') ? StickerSource.mxc : StickerSource.asset;

  /// Bundled-asset path (only valid when [source] == asset).
  String get assetPath =>
      'assets/stickers/$packId/${url.substring('asset:'.length)}';

  /// Unique key across packs (upload caching).
  String get cacheKey => '$packId/$id';
}

class StickerPack {
  StickerPack({
    required this.id,
    required this.displayName,
    required this.images,
    this.category = 'general',
    this.featured = false,
    this.isNew = false,
    this.coverUrl = '',
  });

  final String id;
  final String displayName;
  final List<StickerImage> images;
  final String category;
  final bool featured;
  final bool isNew;

  /// `mxc://` (remote) or `asset:` (bundled) cover image.
  final String coverUrl;
}
