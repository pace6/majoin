import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/client/matrix_client.dart';
import 'flex_event.dart';

/// Render a [FlexBubble] into a Material widget tree.
class FlexBubbleView extends StatelessWidget {
  const FlexBubbleView({super.key, required this.bubble});
  final FlexBubble bubble;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bubble.hero != null) _renderImage(bubble.hero!, hero: true),
            if (bubble.body != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: _renderBox(bubble.body!),
              ),
            if (bubble.footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _renderBox(bubble.footer!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Render a [FlexCarousel] — a fixed-height horizontal pager of bubbles.
class FlexCarouselView extends StatelessWidget {
  const FlexCarouselView({super.key, required this.carousel});
  final FlexCarousel carousel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 248,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemCount: carousel.bubbles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => SizedBox(
          width: 232,
          child: FlexBubbleView(bubble: carousel.bubbles[i]),
        ),
      ),
    );
  }
}

Widget _renderComponent(FlexComponent c) {
  if (c is FlexBox) return _renderBox(c);
  if (c is FlexText) return _renderText(c);
  if (c is FlexImage) return _renderImage(c);
  if (c is FlexButton) return _renderButton(c);
  if (c is FlexSeparator) return _renderSeparator(c);
  if (c is FlexSpacer) return _renderSpacer(c);
  return const SizedBox.shrink();
}

Widget _renderBox(FlexBox b) {
  final children = <Widget>[];
  for (var i = 0; i < b.contents.length; i++) {
    if (i > 0 && b.spacing != null) {
      children.add(SizedBox(
        width: b.layout == 'horizontal' ? _spacing(b.spacing!) : 0,
        height: b.layout == 'vertical' ? _spacing(b.spacing!) : 0,
      ));
    }
    children.add(_renderComponent(b.contents[i]));
  }
  Widget content = b.layout == 'horizontal'
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: _mainAxis(b.justifyContent),
          children: children,
        )
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  if (b.paddingAll != null) {
    content = Padding(
      padding: EdgeInsets.all(_spacing(b.paddingAll!)),
      child: content,
    );
  }
  if (b.backgroundColor != null) {
    content = ColoredBox(color: _color(b.backgroundColor!), child: content);
  }
  return content;
}

Widget _renderText(FlexText t) {
  return Text(
    t.text,
    softWrap: t.wrap,
    overflow: t.wrap ? TextOverflow.visible : TextOverflow.ellipsis,
    textAlign: _textAlign(t.align),
    style: TextStyle(
      fontSize: _fontSize(t.size),
      fontWeight: t.weight == 'bold' ? FontWeight.w600 : FontWeight.w400,
      color: t.color != null ? _color(t.color!) : null,
    ),
  );
}

Widget _renderImage(FlexImage img, {bool hero = false}) {
  final parts = img.aspectRatio.split(':');
  final ratio = parts.length == 2
      ? (double.tryParse(parts[0]) ?? 20) / (double.tryParse(parts[1]) ?? 13)
      : 20 / 13;
  return AspectRatio(
    aspectRatio: ratio,
    child: _ImageFromUrl(
      url: img.url,
      fit: img.aspectMode == 'cover' ? BoxFit.cover : BoxFit.contain,
    ),
  );
}

Widget _renderButton(FlexButton b) {
  final style = b.style;
  final action = b.action;
  void onPressed() {
    // TODO: route through a real handler. For demo: copy data to clipboard.
    Clipboard.setData(ClipboardData(text: action.data));
  }

  if (style == 'link') {
    return TextButton(onPressed: onPressed, child: Text(action.label));
  }
  if (style == 'secondary') {
    return OutlinedButton(onPressed: onPressed, child: Text(action.label));
  }
  return FilledButton(onPressed: onPressed, child: Text(action.label));
}

Widget _renderSeparator(FlexSeparator s) => Divider(
      color: s.color != null ? _color(s.color!) : null,
      height: 12,
    );

Widget _renderSpacer(FlexSpacer s) => SizedBox(height: _spacing(s.size));

class _ImageFromUrl extends StatelessWidget {
  const _ImageFromUrl({required this.url, required this.fit});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http')) {
      return CachedNetworkImage(imageUrl: url, fit: fit);
    }
    if (url.startsWith('mxc://')) {
      final c = MatrixClientService.instance.client;
      final http = Uri.parse(url).toMxcUriHttps(c)?.toString();
      if (http == null) return const SizedBox.shrink();
      return CachedNetworkImage(imageUrl: http, fit: fit);
    }
    // asset:foo.png
    if (url.startsWith('asset:')) {
      return Image.asset(
        'assets/stickers/majoin_v1/${url.substring(6)}',
        fit: fit,
      );
    }
    return const SizedBox.shrink();
  }
}

double _fontSize(String? s) => switch (s) {
      'xs' => 10,
      'sm' => 12,
      'md' => 14,
      'lg' => 16,
      'xl' => 20,
      _ => 14,
    };

double _spacing(String s) => switch (s) {
      'sm' => 4,
      'md' => 8,
      'lg' => 16,
      'xl' => 24,
      _ => 8,
    };

MainAxisAlignment _mainAxis(String? j) => switch (j) {
      'center' => MainAxisAlignment.center,
      'end' => MainAxisAlignment.end,
      'space-between' => MainAxisAlignment.spaceBetween,
      _ => MainAxisAlignment.start,
    };

TextAlign? _textAlign(String? a) => switch (a) {
      'center' => TextAlign.center,
      'end' => TextAlign.end,
      'start' => TextAlign.start,
      _ => null,
    };

Color _color(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

extension on Uri {
  /// Convert mxc:// to homeserver media URL.
  Uri? toMxcUriHttps(dynamic c) {
    try {
      return c.homeserver?.replace(
        path: '/_matrix/client/v1/media/download/$host$path',
      );
    } catch (_) {
      return null;
    }
  }
}
