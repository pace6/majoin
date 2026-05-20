import 'package:flutter/material.dart';
import '../../core/i18n/strings.dart';
import 'sticker_pack.dart';
import 'sticker_repo.dart';
import 'sticker_store.dart';
import 'sticker_thumb.dart';

class StickerPickerSheet extends StatefulWidget {
  const StickerPickerSheet({super.key});

  static Future<StickerImage?> show(BuildContext context) {
    return showModalBottomSheet<StickerImage>(
      context: context,
      showDragHandle: true,
      builder: (_) => const StickerPickerSheet(),
    );
  }

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> {
  List<StickerPack>? _packs;
  String? _error;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final packs = await StickerRepo.instance.installedPacks();
      if (mounted) setState(() => _packs = packs);
    } catch (e) {
      if (mounted) setState(() => _error = '${'picker.loadFailed'.tr}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ),
        ),
      );
    }
    final packs = _packs;
    if (packs == null) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (packs.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(child: Text('picker.empty'.tr)),
      );
    }
    final active = packs[_active.clamp(0, packs.length - 1)];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: active.images.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, i) {
                  final s = active.images[i];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(s),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: StickerThumb(sticker: s),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < packs.length; i++)
                          _PackTab(
                            pack: packs[i],
                            selected: i == _active,
                            onTap: () => setState(() => _active = i),
                          ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const StickerStorePage()),
                      );
                      _load();
                    },
                    child: Container(
                      width: 48,
                      alignment: Alignment.center,
                      child: const Icon(Icons.add_circle_outline,
                          color: Color(0xFF888888)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackTab extends StatelessWidget {
  const _PackTab({
    required this.pack,
    required this.selected,
    required this.onTap,
  });
  final StickerPack pack;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 52,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAFBEF) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: pack.images.isNotEmpty
              ? StickerThumb(sticker: pack.images.first)
              : StickerCover(url: pack.coverUrl, size: 36),
        ),
      ),
    );
  }
}
