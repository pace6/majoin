import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../../core/client/matrix_client.dart';
import '../../core/config.dart';
import 'sticker_pack.dart';

/// Sticker catalog + installed-list repository.
///
/// - Catalog/packs come from the FastAPI store ([AppConfig.stickerApi]).
/// - The bundled `majoin_v1` pack is the always-available offline default.
/// - The installed-pack list lives in Matrix `account_data`, so it syncs
///   across the user's devices for free (no extra backend).
class StickerRepo {
  StickerRepo._();
  static final instance = StickerRepo._();

  static const _bundledDefaultId = 'majoin_v1';

  final Map<String, StickerPack> _packCache = {};
  List<StickerPack>? _catalogCache;

  // ---- Catalog ----

  Future<List<StickerPack>> catalog({bool refresh = false}) async {
    if (_catalogCache != null && !refresh) return _catalogCache!;
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.stickerApi}/api/stickers/catalog'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final packs = (j['packs'] as List? ?? [])
            .map((e) => _packSummaryFromJson(e as Map<String, dynamic>))
            .toList();
        _catalogCache = packs;
        return packs;
      }
    } catch (_) {
      // offline / API down — fall through to bundled-only catalog
    }
    final fallback = [await _bundledPack()];
    _catalogCache = fallback;
    return fallback;
  }

  /// Pack summary without stickers (catalog entries).
  StickerPack _packSummaryFromJson(Map<String, dynamic> j) => StickerPack(
        id: j['id'] as String,
        displayName: j['name'] as String? ?? j['id'] as String,
        images: const [],
        category: j['category'] as String? ?? 'general',
        featured: j['featured'] as bool? ?? false,
        isNew: j['isNew'] as bool? ?? false,
        coverUrl: j['coverMxc'] as String? ?? '',
      );

  // ---- Full pack (with stickers) ----

  Future<StickerPack> loadPack(String packId) async {
    final cached = _packCache[packId];
    if (cached != null) return cached;

    if (packId == _bundledDefaultId) {
      final p = await _bundledPack();
      _packCache[packId] = p;
      return p;
    }

    final res = await http
        .get(Uri.parse('${AppConfig.stickerApi}/api/stickers/pack/$packId'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('pack $packId not found (${res.statusCode})');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final pack = StickerPack(
      id: j['id'] as String,
      displayName: j['name'] as String? ?? packId,
      category: j['category'] as String? ?? 'general',
      featured: j['featured'] as bool? ?? false,
      isNew: j['isNew'] as bool? ?? false,
      coverUrl: j['coverMxc'] as String? ?? '',
      images: (j['stickers'] as List? ?? []).map((e) {
        final s = e as Map<String, dynamic>;
        return StickerImage(
          id: s['id'] as String,
          packId: packId,
          url: s['mxc'] as String? ?? '',
          body: s['body'] as String? ?? s['id'] as String,
          width: (s['w'] as num?)?.toInt() ?? 256,
          height: (s['h'] as num?)?.toInt() ?? 256,
        );
      }).toList(),
    );
    _packCache[packId] = pack;
    return pack;
  }

  Future<StickerPack> _bundledPack() async {
    final raw =
        await rootBundle.loadString('assets/stickers/majoin_v1/pack.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final pack = j['pack'] as Map<String, dynamic>? ?? {};
    final imgs = (j['images'] as Map<String, dynamic>? ?? {});
    final images = imgs.entries.map((e) {
      final v = e.value as Map<String, dynamic>;
      return StickerImage(
        id: e.key,
        packId: _bundledDefaultId,
        url: v['url'] as String? ?? '',
        body: v['body'] as String? ?? e.key,
        width: (v['w'] as num?)?.toInt() ?? 256,
        height: (v['h'] as num?)?.toInt() ?? 256,
      );
    }).toList();
    return StickerPack(
      id: _bundledDefaultId,
      displayName: pack['display_name'] as String? ?? 'majoin',
      images: images,
      coverUrl: images.isNotEmpty ? images.first.url : '',
    );
  }

  // ---- Installed list (Matrix account_data) ----

  Future<List<String>> installedIds() async {
    final c = MatrixClientService.instance.client;
    final data = c.accountData[AppConfig.stickerAccountDataType];
    final ids = (data?.content['packs'] as List?)?.cast<String>() ?? const [];
    if (!ids.contains(_bundledDefaultId)) {
      return [_bundledDefaultId, ...ids];
    }
    return ids;
  }

  Future<void> install(String packId) async {
    final list = await installedIds();
    if (list.contains(packId)) return;
    await _saveInstalled([...list, packId]);
  }

  Future<void> uninstall(String packId) async {
    if (packId == _bundledDefaultId) return; // default is permanent
    final list = await installedIds();
    await _saveInstalled(list.where((p) => p != packId).toList());
  }

  Future<void> _saveInstalled(List<String> ids) async {
    final c = MatrixClientService.instance.client;
    await c.setAccountData(
      c.userID!,
      AppConfig.stickerAccountDataType,
      {'packs': ids},
    );
  }

  /// Installed packs fully loaded (with stickers), bundled default first.
  Future<List<StickerPack>> installedPacks() async {
    final ids = await installedIds();
    final result = <StickerPack>[];
    for (final id in ids) {
      try {
        result.add(await loadPack(id));
      } catch (_) {
        // skip a pack that failed to load (e.g. removed from server)
      }
    }
    return result;
  }
}
