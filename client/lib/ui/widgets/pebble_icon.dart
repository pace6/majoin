import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Pebble design's icon set — minimal 24×24 stroke icons (and a few
/// filled), ported from the design's icons.jsx. Use [PebbleIcon] in place
/// of Material `Icons.*` so the app matches the design.
enum PIcon {
  home,
  chat,
  person,
  gear,
  back,
  send,
  plus,
  close,
  search,
  edit,
  bell,
  lock,
  globe,
  moon,
  qr,
  camera,
  help,
  logout,
  phone,
  video,
  mic,
  image,
  film,
  smile,
  chevron,
  speaker,
  check,
}

class PebbleIcon extends StatelessWidget {
  const PebbleIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color = const Color(0xFF26241F),
    this.filled = false,
  });

  final PIcon icon;
  final double size;
  final Color color;

  /// Filled variant — only home / chat / person / gear define one.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg(icon, color, filled),
      width: size,
      height: size,
    );
  }
}

String _hex(Color c) {
  int ch(double v) => (v * 255).round();
  return '#'
      '${ch(c.r).toRadixString(16).padLeft(2, '0')}'
      '${ch(c.g).toRadixString(16).padLeft(2, '0')}'
      '${ch(c.b).toRadixString(16).padLeft(2, '0')}';
}

/// A stroked path icon.
String _stroke(String d, Color c, {double sw = 1.7}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="$d" fill="none" stroke="${_hex(c)}" stroke-width="$sw" '
    'stroke-linecap="round" stroke-linejoin="round"/></svg>';

/// A filled path icon.
String _fill(String d, Color c) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="$d" fill="${_hex(c)}"/></svg>';

const _homeD =
    'M4 11l8-7 8 7v9a1 1 0 0 1-1 1h-4v-7h-6v7H5a1 1 0 0 1-1-1v-9Z';
const _chatD =
    'M4 6.5C4 5.12 5.12 4 6.5 4h11C18.88 4 20 5.12 20 6.5v8c0 1.38-1.12 '
    '2.5-2.5 2.5H12l-4.5 3.5V17H6.5C5.12 17 4 15.88 4 14.5v-8Z';
const _gearD =
    'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z M19.4 12c0-.5-.05-1-.13-1.46l2-1.55'
    '-2-3.46-2.36.85a7.5 7.5 0 0 0-2.53-1.46L14 2.5h-4l-.38 2.42a7.5 7.5 0 0 '
    '0-2.53 1.46L4.73 5.53l-2 3.46 2 1.55c-.08.47-.13.96-.13 1.46s.05 1 .13 '
    '1.46l-2 1.55 2 3.46 2.36-.85a7.5 7.5 0 0 0 2.53 1.46L10 21.5h4l.38-2.42'
    'a7.5 7.5 0 0 0 2.53-1.46l2.36.85 2-3.46-2-1.55c.08-.47.13-.96.13-1.46Z';

String _svg(PIcon i, Color c, bool filled) {
  switch (i) {
    case PIcon.home:
      return filled ? _fill(_homeD, c) : _stroke(_homeD, c);
    case PIcon.chat:
      return filled ? _fill(_chatD, c) : _stroke(_chatD, c);
    case PIcon.person:
      return filled
          ? '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
              '<circle cx="12" cy="8.5" r="4" fill="${_hex(c)}"/>'
              '<path d="M4.5 20c1.4-3.2 4.3-5 7.5-5s6.1 1.8 7.5 5" '
              'stroke="${_hex(c)}" stroke-width="2" stroke-linecap="round" '
              'fill="none"/></svg>'
          : _stroke(
              'M12 12.5a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM4.5 20c1.4-3.2 4.3-5 '
              '7.5-5s6.1 1.8 7.5 5',
              c);
    case PIcon.gear:
      return filled
          ? '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
              '<path d="$_gearD" fill="${_hex(c)}"/>'
              '<circle cx="12" cy="12" r="3" fill="#FAF8F5"/></svg>'
          : _stroke(_gearD, c);
    case PIcon.back:
      return _stroke('M14 6l-6 6 6 6', c, sw: 2.1);
    case PIcon.send:
      return _fill('M3.5 11.5 20 4l-7.5 16.5-2-7.5-7-1.5Z', c);
    case PIcon.plus:
      return _stroke('M12 5v14M5 12h14', c, sw: 2.2);
    case PIcon.close:
      return _stroke('M6 6l12 12M18 6L6 18', c, sw: 2.2);
    case PIcon.search:
      return _stroke(
          'M10.5 17a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13ZM15.5 15.5 20 20',
          c);
    case PIcon.edit:
      return _stroke('M4 20h4l10-10-4-4L4 16v4ZM14 6l4 4', c);
    case PIcon.bell:
      return _stroke(
          'M6 16V11a6 6 0 1 1 12 0v5l1.5 2h-15L6 16ZM10 20a2 2 0 0 0 4 0', c);
    case PIcon.lock:
      return _stroke('M7 11V8a5 5 0 1 1 10 0v3M5 11h14v9H5z', c);
    case PIcon.globe:
      return _stroke(
          'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM3 12h18M12 3c2.5 3 2.5 15 '
          '0 18M12 3c-2.5 3-2.5 15 0 18',
          c);
    case PIcon.moon:
      return _stroke(
          'M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5Z', c);
    case PIcon.qr:
      return _stroke(
          'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2v2h-2zM18 14h2v2h-2z'
          'M14 18h2v2h-2zM18 18h2v2h-2z',
          c);
    case PIcon.camera:
      return _stroke(
          'M4 8h3l2-2h6l2 2h3v11H4zM12 17a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z',
          c);
    case PIcon.help:
      return _stroke(
          'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM9.5 9.5A2.5 2.5 0 1 1 12 13'
          'v1.5M12 17.5v.01',
          c);
    case PIcon.logout:
      return _stroke('M14 4h5v16h-5M10 8l-4 4 4 4M6 12h10', c);
    case PIcon.phone:
      return _stroke(
          'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A15 '
          '15 0 0 1 3 6a2 2 0 0 1 2-2Z',
          c);
    case PIcon.video:
      return _stroke('M3 7h12v10H3zM15 11l6-3v8l-6-3z', c);
    case PIcon.mic:
      return _stroke(
          'M12 4a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V7a3 3 0 0 0-3-3ZM5 12a7 7 0 '
          '0 0 14 0M12 19v3M8 22h8',
          c);
    case PIcon.image:
      return _stroke(
          'M4 5h16v14H4zM8 11a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM4 17l5-5 4 4 3-3 '
          '4 4',
          c);
    case PIcon.film:
      return _stroke('M4 5h16v14H4zM4 9h16M4 15h16M8 5v14M16 5v14', c);
    case PIcon.smile:
      return _stroke(
          'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM9 10v.01M15 10v.01M9 14c.7 '
          '1 1.8 1.7 3 1.7s2.3-.7 3-1.7',
          c);
    case PIcon.chevron:
      return _stroke('M9 6l6 6-6 6', c, sw: 1.9);
    case PIcon.speaker:
      return _stroke('M4 9h4l5-4v14l-5-4H4zM17 9a4 4 0 0 1 0 6M20 6a8 8 0 0 1 0 12', c);
    case PIcon.check:
      return _stroke('M5 12l4 4 10-10', c, sw: 2.2);
  }
}
