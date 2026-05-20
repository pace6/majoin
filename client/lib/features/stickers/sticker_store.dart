import 'package:flutter/material.dart';
import '../../core/i18n/strings.dart';
import '../../ui/theme/app_theme.dart';
import 'sticker_pack.dart';
import 'sticker_repo.dart';
import 'sticker_thumb.dart';

/// Free sticker store — browse catalog from the API, install / remove.
class StickerStorePage extends StatefulWidget {
  const StickerStorePage({super.key});

  @override
  State<StickerStorePage> createState() => _StickerStorePageState();
}

class _StickerStorePageState extends State<StickerStorePage> {
  List<StickerPack> _catalog = [];
  Set<String> _installed = {};
  final Set<String> _busy = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = await StickerRepo.instance.catalog(refresh: true);
      final installed = await StickerRepo.instance.installedIds();
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _installed = installed.toSet();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggle(StickerPack pack) async {
    setState(() => _busy.add(pack.id));
    try {
      if (_installed.contains(pack.id)) {
        await StickerRepo.instance.uninstall(pack.id);
      } else {
        await StickerRepo.instance.install(pack.id);
      }
      final installed = await StickerRepo.instance.installedIds();
      if (mounted) setState(() => _installed = installed.toSet());
    } finally {
      if (mounted) setState(() => _busy.remove(pack.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final featured = _catalog.where((p) => p.featured).toList();
    final rest = _catalog.where((p) => !p.featured).toList();

    return Scaffold(
      appBar: AppBar(title: Text('store.title'.tr)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('${'store.loadFailed'.tr}\n$_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (featured.isNotEmpty) ...[
                        _sectionTitle('store.featured'.tr),
                        ...featured.map(_packCard),
                        const SizedBox(height: 8),
                      ],
                      _sectionTitle('store.allPacks'.tr),
                      ...rest.map(_packCard),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.subtleText)),
      );

  Widget _packCard(StickerPack pack) {
    final installed = _installed.contains(pack.id);
    final isDefault = pack.id == 'majoin_v1';
    final busy = _busy.contains(pack.id);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEBEBEB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: StickerCover(url: pack.coverUrl, size: 60),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(pack.displayName,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (pack.isNew) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('NEW',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  Text(pack.category,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.subtleText)),
                ],
              ),
            ),
            if (isDefault)
              Text('store.default'.tr,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.subtleText))
            else
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: installed
                      ? const Color(0xFFE0E0E0)
                      : AppTheme.lineGreen,
                  foregroundColor:
                      installed ? Colors.black87 : Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: busy ? null : () => _toggle(pack),
                child: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(installed
                        ? 'store.remove'.tr
                        : 'store.add'.tr),
              ),
          ],
        ),
      ),
    );
  }
}
