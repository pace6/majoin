import 'package:flutter/services.dart' show rootBundle;
import 'package:matrix/matrix.dart';
import 'sticker_pack.dart';

/// Send an `m.sticker` event.
///
/// - Remote stickers (`mxc://`) are sent as-is.
/// - Bundled-asset stickers are uploaded to the content repo once, then the
///   resulting `mxc://` is cached in memory per sticker.
class StickerSender {
  StickerSender(this._client);
  final Client _client;
  final Map<String, Uri> _cache = {};

  Future<String?> send(Room room, StickerImage sticker) async {
    Uri mxc;
    if (sticker.source == StickerSource.mxc) {
      mxc = Uri.parse(sticker.url);
    } else {
      final cached = _cache[sticker.cacheKey];
      if (cached != null) {
        mxc = cached;
      } else {
        final bytes = (await rootBundle.load(sticker.assetPath))
            .buffer
            .asUint8List();
        mxc = await _client.uploadContent(
          bytes,
          filename: '${sticker.id}.png',
          contentType: 'image/png',
        );
        _cache[sticker.cacheKey] = mxc;
      }
    }

    final content = <String, dynamic>{
      'body': sticker.body,
      'url': mxc.toString(),
      'info': {
        'w': sticker.width,
        'h': sticker.height,
        'mimetype': 'image/png',
        'size': 0,
      },
    };
    return room.sendEvent(content, type: 'm.sticker');
  }
}
