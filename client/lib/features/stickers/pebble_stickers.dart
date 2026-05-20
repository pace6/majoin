import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One Pebble cartoon sticker — a blob character with an expression and an
/// optional Thai caption. Drawn entirely with a [CustomPainter] (original
/// art, ported from the Pebble design's SVG component).
class PebbleStickerSpec {
  const PebbleStickerSpec({
    required this.color,
    required this.expr,
    this.caption,
    this.captionColor = const Color(0xFFD04A6B),
    this.pos = 'tl',
  });
  final Color color;
  final String expr;
  final String? caption;
  final Color captionColor;
  final String pos; // tl | tr | bl | br
}

/// A named pack of Pebble stickers.
class PebbleStickerPack {
  const PebbleStickerPack({
    required this.id,
    required this.name,
    required this.iconColor,
    required this.iconExpr,
    required this.stickers,
  });
  final String id;
  final String name;
  final Color iconColor;
  final String iconExpr;
  final List<PebbleStickerSpec> stickers;
}

const _ink = Color(0xFF2B2018);
const _accent = Color(0xFFF4B5C9); // cheeks / inner ears

const pebbleStickerPacks = <PebbleStickerPack>[
  PebbleStickerPack(
    id: 'mochi',
    name: 'โมจิ',
    iconColor: Color(0xFFFFE2A8),
    iconExpr: 'happy',
    stickers: [
      PebbleStickerSpec(color: Color(0xFFFFE2A8), expr: 'happy', caption: 'สวัสดี', pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFFFE2A8), expr: 'love', caption: 'รัก', pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFFFE2A8), expr: 'wink', caption: 'นะ', pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFFFE2A8), expr: 'laugh', caption: '555', pos: 'bl'),
      PebbleStickerSpec(color: Color(0xFFFFE2A8), expr: 'shy', caption: 'เขิน', pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFFFE2A8), expr: 'yummy', caption: 'อร่อย', pos: 'bl'),
      PebbleStickerSpec(color: Color(0xFFFFE2A8), expr: 'smug', caption: 'แหะๆ', pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFFFE2A8), expr: 'sleepy', caption: 'ง่วง', pos: 'tl'),
    ],
  ),
  PebbleStickerPack(
    id: 'cocoa',
    name: 'โกโก้',
    iconColor: Color(0xFFC8A87C),
    iconExpr: 'wink',
    stickers: [
      PebbleStickerSpec(color: Color(0xFFC8A87C), expr: 'happy', caption: 'ขอบคุณ', captionColor: Color(0xFF5A3A1A), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFC8A87C), expr: 'wink', caption: 'โอเค', captionColor: Color(0xFF5A3A1A), pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFC8A87C), expr: 'love', caption: 'รักนะ', captionColor: Color(0xFF5A3A1A), pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFC8A87C), expr: 'laugh', caption: 'ฮ่าๆ', captionColor: Color(0xFF5A3A1A), pos: 'bl'),
      PebbleStickerSpec(color: Color(0xFFC8A87C), expr: 'cry', caption: 'งอน', captionColor: Color(0xFF5A3A1A), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFC8A87C), expr: 'shock', caption: 'หา!?', captionColor: Color(0xFF5A3A1A), pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFC8A87C), expr: 'smug', caption: 'รู้แล้ว', captionColor: Color(0xFF5A3A1A), pos: 'br'),
      PebbleStickerSpec(color: Color(0xFFC8A87C), expr: 'sleepy', caption: 'นอน', captionColor: Color(0xFF5A3A1A), pos: 'tl'),
    ],
  ),
  PebbleStickerPack(
    id: 'mint',
    name: 'มิ้นต์',
    iconColor: Color(0xFFA8E6C9),
    iconExpr: 'love',
    stickers: [
      PebbleStickerSpec(color: Color(0xFFA8E6C9), expr: 'love', caption: 'รักเลย', captionColor: Color(0xFF1E7A53), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFA8E6C9), expr: 'happy', caption: 'ดี!', captionColor: Color(0xFF1E7A53), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFA8E6C9), expr: 'yummy', caption: 'หิว', captionColor: Color(0xFF1E7A53), pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFA8E6C9), expr: 'wink', caption: 'ลุย', captionColor: Color(0xFF1E7A53), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFA8E6C9), expr: 'shock', caption: 'จริงดิ!', captionColor: Color(0xFF1E7A53), pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFA8E6C9), expr: 'smug', caption: 'ก็ได้', captionColor: Color(0xFF1E7A53), pos: 'br'),
      PebbleStickerSpec(color: Color(0xFFA8E6C9), expr: 'laugh', caption: 'ตลก', captionColor: Color(0xFF1E7A53), pos: 'bl'),
      PebbleStickerSpec(color: Color(0xFFA8E6C9), expr: 'cry', caption: 'แย่จัง', captionColor: Color(0xFF1E7A53), pos: 'tl'),
    ],
  ),
  PebbleStickerPack(
    id: 'bubblegum',
    name: 'หมากฝรั่ง',
    iconColor: Color(0xFFF4B5C9),
    iconExpr: 'love',
    stickers: [
      PebbleStickerSpec(color: Color(0xFFF4B5C9), expr: 'love', caption: 'หวาน', captionColor: Color(0xFFA03056), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFF4B5C9), expr: 'happy', caption: 'หวัดดี', captionColor: Color(0xFFA03056), pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFF4B5C9), expr: 'wink', caption: 'จุ๊บๆ', captionColor: Color(0xFFA03056), pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFF4B5C9), expr: 'shy', caption: 'อาย', captionColor: Color(0xFFA03056), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFF4B5C9), expr: 'laugh', caption: 'ฮิๆ', captionColor: Color(0xFFA03056), pos: 'bl'),
      PebbleStickerSpec(color: Color(0xFFF4B5C9), expr: 'smug', caption: 'เก่ง', captionColor: Color(0xFFA03056), pos: 'br'),
      PebbleStickerSpec(color: Color(0xFFF4B5C9), expr: 'cry', caption: 'คิดถึง', captionColor: Color(0xFFA03056), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFF4B5C9), expr: 'sleepy', caption: 'ฝันดี', captionColor: Color(0xFFA03056), pos: 'tl'),
    ],
  ),
  PebbleStickerPack(
    id: 'sky',
    name: 'ฟ้า',
    iconColor: Color(0xFFB5D4F2),
    iconExpr: 'smug',
    stickers: [
      PebbleStickerSpec(color: Color(0xFFB5D4F2), expr: 'happy', caption: 'มาแล้ว', captionColor: Color(0xFF1F4A7A), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFB5D4F2), expr: 'smug', caption: 'ใช่ค่ะ', captionColor: Color(0xFF1F4A7A), pos: 'br'),
      PebbleStickerSpec(color: Color(0xFFB5D4F2), expr: 'shock', caption: 'อะ!', captionColor: Color(0xFF1F4A7A), pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFB5D4F2), expr: 'wink', caption: 'ลาก่อน', captionColor: Color(0xFF1F4A7A), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFB5D4F2), expr: 'cry', caption: 'ไม่อะ', captionColor: Color(0xFF1F4A7A), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFB5D4F2), expr: 'sleepy', caption: 'เพลีย', captionColor: Color(0xFF1F4A7A), pos: 'tl'),
      PebbleStickerSpec(color: Color(0xFFB5D4F2), expr: 'love', caption: 'รักนะ', captionColor: Color(0xFF1F4A7A), pos: 'tr'),
      PebbleStickerSpec(color: Color(0xFFB5D4F2), expr: 'laugh', caption: 'เฮ้', captionColor: Color(0xFF1F4A7A), pos: 'bl'),
    ],
  ),
];

/// Renders a [PebbleStickerSpec].
class PebbleStickerView extends StatelessWidget {
  const PebbleStickerView({super.key, required this.spec, this.size = 96});
  final PebbleStickerSpec spec;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PebblePainter(spec),
    );
  }
}

/// Rasterizes a sticker to a transparent PNG so it can be sent over Matrix.
Future<Uint8List> renderPebbleStickerPng(PebbleStickerSpec spec,
    {int px = 320}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _PebblePainter(spec).paint(canvas, Size(px.toDouble(), px.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

class _PebblePainter extends CustomPainter {
  _PebblePainter(this.s);
  final PebbleStickerSpec s;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale);

    final fill = Paint()..isAntiAlias = true;
    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void oval(double cx, double cy, double rx, double ry, Color c,
        {double opacity = 1}) {
      fill.color = c.withValues(alpha: c.a * opacity);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, cy), width: rx * 2, height: ry * 2),
          fill);
    }

    void quad(double x1, double y1, double cx, double cy, double x2,
        double y2, Color c, double w) {
      stroke
        ..color = c
        ..strokeWidth = w;
      canvas.drawPath(
          Path()
            ..moveTo(x1, y1)
            ..quadraticBezierTo(cx, cy, x2, y2),
          stroke);
    }

    void line(double x1, double y1, double x2, double y2, Color c, double w) {
      stroke
        ..color = c
        ..strokeWidth = w;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);
    }

    // Chef hat (drawn behind the head).
    if (s.expr == 'chef') {
      oval(50, 16, 22, 9, Colors.white);
    }
    // Ears.
    oval(26, 28, 9, 12, s.color);
    oval(74, 28, 9, 12, s.color);
    oval(26, 28, 4, 6.5, _accent);
    oval(74, 28, 4, 6.5, _accent);
    // Body.
    oval(50, 56, 32, 30, s.color);
    // Shine.
    oval(36, 40, 14, 10, Colors.white.withValues(alpha: 0.3));

    // Eyes.
    _eyes(canvas, fill, stroke, quad, line, oval);
    // Cheeks.
    oval(30, 58, 4, 4, _accent, opacity: 0.6);
    oval(70, 58, 4, 4, _accent, opacity: 0.6);
    // Mouth.
    _mouth(canvas, fill, quad);

    // Love hearts.
    if (s.expr == 'love') {
      _heart(canvas, fill, 14, 20, 6, const Color(0xFFF4859C));
      _heart(canvas, fill, 88, 82, 4, const Color(0xFFF4859C));
    }

    canvas.restore();

    // Caption (drawn unscaled, positioned in the 0..100 box).
    if (s.caption != null && s.caption!.isNotEmpty) {
      _caption(canvas, size, scale);
    }
  }

  void _eyes(
      Canvas canvas,
      Paint fill,
      Paint stroke,
      void Function(double, double, double, double, double, double, Color,
              double)
          quad,
      void Function(double, double, double, double, Color, double) line,
      void Function(double, double, double, double, Color, {double opacity})
          oval) {
    switch (s.expr) {
      case 'happy':
      case 'yummy':
        quad(30, 46, 35, 41, 40, 46, _ink, 2.6);
        quad(60, 46, 65, 41, 70, 46, _ink, 2.6);
      case 'wink':
        quad(30, 46, 35, 41, 40, 46, _ink, 2.6);
        oval(65, 46, 3.2, 4, _ink);
      case 'love':
        _heart(canvas, fill, 32, 47, 5, const Color(0xFFE86A8B));
        _heart(canvas, fill, 67, 47, 5, const Color(0xFFE86A8B));
      case 'sleepy':
        quad(28, 46, 35, 49, 42, 46, _ink, 2.4);
        quad(58, 46, 65, 49, 72, 46, _ink, 2.4);
      case 'laugh':
        line(28, 44, 42, 44, _ink, 3);
        line(58, 44, 72, 44, _ink, 3);
      case 'smug':
        line(30, 47, 42, 44, _ink, 2.4);
        line(58, 44, 70, 47, _ink, 2.4);
      case 'shock':
        oval(35, 46, 4.5, 4.5, Colors.white);
        oval(35, 46, 1.6, 1.6, _ink);
        oval(65, 46, 4.5, 4.5, Colors.white);
        oval(65, 46, 1.6, 1.6, _ink);
      case 'cry':
        oval(35, 46, 3.2, 4, _ink);
        oval(65, 46, 3.2, 4, _ink);
        _tear(canvas, fill, 30);
        _tear(canvas, fill, 70);
      default: // chef, shy
        oval(35, 46, 3.2, 4, _ink);
        oval(65, 46, 3.2, 4, _ink);
    }
  }

  void _mouth(
      Canvas canvas,
      Paint fill,
      void Function(double, double, double, double, double, double, Color,
              double)
          quad) {
    switch (s.expr) {
      case 'happy':
        quad(44, 60, 50, 65, 56, 60, _ink, 2.4);
      case 'wink':
        quad(44, 60, 50, 66, 56, 60, _ink, 2.4);
      case 'love':
        quad(44, 60, 50, 67, 56, 60, _ink, 2.4);
      case 'sleepy':
        fill.color = _ink.withValues(alpha: 0.7);
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(50, 62), width: 8, height: 4),
            fill);
      case 'yummy':
        quad(42, 58, 50, 66, 58, 58, _ink, 2.4);
      case 'laugh':
        fill.color = _ink;
        canvas.drawPath(
            Path()
              ..moveTo(40, 56)
              ..quadraticBezierTo(50, 70, 60, 56)
              ..close(),
            fill);
      case 'cry':
        quad(44, 65, 50, 60, 56, 65, _ink, 2.4);
      case 'smug':
        quad(42, 60, 50, 65, 58, 60, _ink, 2.4);
      case 'shock':
        fill.color = _ink;
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(50, 62), width: 6, height: 8),
            fill);
      default: // chef, shy
        quad(44, 60, 50, 64, 56, 60, _ink, 2.4);
    }
  }

  void _heart(Canvas canvas, Paint fill, double cx, double cy, double r,
      Color color) {
    fill.color = color;
    final p = Path()
      ..moveTo(cx, cy + r * 0.3)
      ..cubicTo(cx - r, cy - r, cx - r * 1.6, cy + r * 0.4, cx,
          cy + r * 1.2)
      ..cubicTo(cx + r * 1.6, cy + r * 0.4, cx + r, cy - r, cx,
          cy + r * 0.3)
      ..close();
    canvas.drawPath(p, fill);
  }

  void _tear(Canvas canvas, Paint fill, double x) {
    fill.color = const Color(0xFF6BB6E3);
    canvas.drawPath(
        Path()
          ..moveTo(x, 52)
          ..quadraticBezierTo(x + 3, 60, x, 64)
          ..quadraticBezierTo(x - 3, 60, x, 52)
          ..close(),
        fill);
  }

  void _caption(Canvas canvas, Size size, double scale) {
    final txt = s.caption!;
    final fontSize = (txt.characters.length > 4 ? 13.0 : 16.0) * scale;
    // Stroke (white outline) then fill.
    for (final layer in [true, false]) {
      final tp = TextPainter(
        text: TextSpan(
          text: txt,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            foreground: layer
                ? (Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3 * scale
                  ..color = Colors.white)
                : null,
            color: layer ? null : s.captionColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final right = s.pos == 'tr' || s.pos == 'br';
      final bottom = s.pos == 'bl' || s.pos == 'br';
      final x =
          right ? size.width - 6 * scale - tp.width : 6 * scale;
      final y = bottom
          ? size.height - 14 * scale - tp.height
          : 10 * scale;
      tp.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(_PebblePainter old) =>
      old.s.expr != s.expr ||
      old.s.color != s.color ||
      old.s.caption != s.caption;
}

/// Inline Pebble sticker tray — sticker grid + character pack-tab strip.
class PebbleStickerPanel extends StatefulWidget {
  const PebbleStickerPanel({super.key, required this.onPick});
  final void Function(PebbleStickerSpec) onPick;

  @override
  State<PebbleStickerPanel> createState() => _PebbleStickerPanelState();
}

class _PebbleStickerPanelState extends State<PebbleStickerPanel> {
  int _pack = 0;

  @override
  Widget build(BuildContext context) {
    final pack = pebbleStickerPacks[_pack];
    return Container(
      height: 268,
      decoration: const BoxDecoration(
        color: Color(0x06000000),
        border: Border(top: BorderSide(color: Color(0x14000000), width: 0.5)),
      ),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: pack.stickers.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemBuilder: (_, i) {
                final s = pack.stickers[i];
                return InkWell(
                  onTap: () => widget.onPick(s),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: PebbleStickerView(spec: s, size: 70),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                for (var i = 0; i < pebbleStickerPacks.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _pack = i),
                    child: Container(
                      width: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _pack
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: PebbleStickerView(
                        spec: PebbleStickerSpec(
                          color: pebbleStickerPacks[i].iconColor,
                          expr: pebbleStickerPacks[i].iconExpr,
                        ),
                        size: 30,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
