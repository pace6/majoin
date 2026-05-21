/// Majoin Flex Message — minimal subset of Line Flex Message spec.
///
/// Why custom event type: Matrix has no first-class rich-card primitive. We
/// serialize the bubble JSON as the content of an `app.majoin.flex` event.
/// We ALSO emit a plain `m.room.message` `body` fallback so vanilla Matrix
/// clients (Element, etc.) render a readable text summary.
///
/// Supported subset:
///   type: "bubble"
///     hero?:   image
///     body?:   box (vertical|horizontal) of {text, image, separator, spacer, box}
///     footer?: box of {button}
///   button.action: { type: "uri", label, uri } | { type: "postback", label, data }
library;

const kFlexEventType = 'app.majoin.flex';

/// Top-level bubble.
class FlexBubble {
  FlexBubble({this.hero, this.body, this.footer, this.altText = 'flex message'});
  final FlexImage? hero;
  final FlexBox? body;
  final FlexBox? footer;
  final String altText;

  Map<String, dynamic> toJson() => {
        'type': 'bubble',
        if (hero != null) 'hero': hero!.toJson(),
        if (body != null) 'body': body!.toJson(),
        if (footer != null) 'footer': footer!.toJson(),
        'altText': altText,
      };

  static FlexBubble fromJson(Map<String, dynamic> j) => FlexBubble(
        hero: j['hero'] == null
            ? null
            : FlexImage.fromJson(j['hero'] as Map<String, dynamic>),
        body: j['body'] == null
            ? null
            : FlexBox.fromJson(j['body'] as Map<String, dynamic>),
        footer: j['footer'] == null
            ? null
            : FlexBox.fromJson(j['footer'] as Map<String, dynamic>),
        altText: (j['altText'] as String?) ?? 'flex message',
      );
}

abstract class FlexComponent {
  String get type;
  Map<String, dynamic> toJson();

  static FlexComponent fromJson(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'box':
        return FlexBox.fromJson(j);
      case 'text':
        return FlexText.fromJson(j);
      case 'image':
        return FlexImage.fromJson(j);
      case 'button':
        return FlexButton.fromJson(j);
      case 'separator':
        return FlexSeparator.fromJson(j);
      case 'spacer':
        return FlexSpacer.fromJson(j);
      default:
        return FlexText(text: '[unknown:${j['type']}]');
    }
  }
}

class FlexBox extends FlexComponent {
  FlexBox({
    required this.layout,
    required this.contents,
    this.spacing,
    this.paddingAll,
    this.backgroundColor,
    this.justifyContent,
  });
  /// "vertical" or "horizontal".
  final String layout;
  final List<FlexComponent> contents;
  final String? spacing; // "sm" | "md" | "lg"
  final String? paddingAll; // "sm" | "md" | "lg"
  final String? backgroundColor; // "#rrggbb"
  /// Main-axis distribution for a horizontal box:
  /// "start" | "center" | "end" | "space-between".
  final String? justifyContent;

  @override
  String get type => 'box';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'layout': layout,
        'contents': contents.map((e) => e.toJson()).toList(),
        if (spacing != null) 'spacing': spacing,
        if (paddingAll != null) 'paddingAll': paddingAll,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (justifyContent != null) 'justifyContent': justifyContent,
      };

  static FlexBox fromJson(Map<String, dynamic> j) => FlexBox(
        layout: j['layout'] as String? ?? 'vertical',
        contents: ((j['contents'] as List?) ?? const [])
            .map((e) => FlexComponent.fromJson(e as Map<String, dynamic>))
            .toList(),
        spacing: j['spacing'] as String?,
        paddingAll: j['paddingAll'] as String?,
        backgroundColor: j['backgroundColor'] as String?,
        justifyContent: j['justifyContent'] as String?,
      );
}

class FlexText extends FlexComponent {
  FlexText({
    required this.text,
    this.size,
    this.weight,
    this.color,
    this.wrap = true,
    this.align,
  });
  final String text;
  final String? size; // "xs"|"sm"|"md"|"lg"|"xl"
  final String? weight; // "regular" | "bold"
  final String? color; // "#rrggbb"
  final bool wrap;
  final String? align; // "start"|"center"|"end"

  @override
  String get type => 'text';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
        if (size != null) 'size': size,
        if (weight != null) 'weight': weight,
        if (color != null) 'color': color,
        'wrap': wrap,
        if (align != null) 'align': align,
      };

  static FlexText fromJson(Map<String, dynamic> j) => FlexText(
        text: j['text'] as String? ?? '',
        size: j['size'] as String?,
        weight: j['weight'] as String?,
        color: j['color'] as String?,
        wrap: j['wrap'] as bool? ?? true,
        align: j['align'] as String?,
      );
}

class FlexImage extends FlexComponent {
  FlexImage({
    required this.url,
    this.aspectRatio = '20:13',
    this.aspectMode = 'cover',
  });
  final String url; // http(s):// or mxc://
  final String aspectRatio; // "w:h"
  final String aspectMode; // "cover" | "fit"

  @override
  String get type => 'image';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'url': url,
        'aspectRatio': aspectRatio,
        'aspectMode': aspectMode,
      };

  static FlexImage fromJson(Map<String, dynamic> j) => FlexImage(
        url: j['url'] as String? ?? '',
        aspectRatio: j['aspectRatio'] as String? ?? '20:13',
        aspectMode: j['aspectMode'] as String? ?? 'cover',
      );
}

class FlexButton extends FlexComponent {
  FlexButton({required this.action, this.style = 'primary'});
  final FlexAction action;
  final String style; // "primary"|"secondary"|"link"

  @override
  String get type => 'button';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'style': style,
        'action': action.toJson(),
      };

  static FlexButton fromJson(Map<String, dynamic> j) => FlexButton(
        style: j['style'] as String? ?? 'primary',
        action: FlexAction.fromJson(j['action'] as Map<String, dynamic>? ?? {}),
      );
}

class FlexSeparator extends FlexComponent {
  FlexSeparator({this.color});
  final String? color;
  @override
  String get type => 'separator';
  @override
  Map<String, dynamic> toJson() => {'type': type, if (color != null) 'color': color};
  static FlexSeparator fromJson(Map<String, dynamic> j) =>
      FlexSeparator(color: j['color'] as String?);
}

class FlexSpacer extends FlexComponent {
  FlexSpacer({this.size = 'md'});
  final String size;
  @override
  String get type => 'spacer';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'size': size};
  static FlexSpacer fromJson(Map<String, dynamic> j) =>
      FlexSpacer(size: j['size'] as String? ?? 'md');
}

class FlexAction {
  FlexAction.uri({required this.label, required String uri})
      : type = 'uri',
        data = uri;
  FlexAction.postback({required this.label, required String data})
      : type = 'postback',
        // ignore: prefer_initializing_formals
        data = data;
  FlexAction._({required this.type, required this.label, required this.data});

  final String type; // "uri" | "postback"
  final String label;
  final String data; // uri or postback payload

  Map<String, dynamic> toJson() {
    if (type == 'uri') return {'type': type, 'label': label, 'uri': data};
    return {'type': type, 'label': label, 'data': data};
  }

  static FlexAction fromJson(Map<String, dynamic> j) {
    final t = j['type'] as String? ?? 'uri';
    return FlexAction._(
      type: t,
      label: j['label'] as String? ?? '',
      data: (t == 'uri' ? j['uri'] : j['data']) as String? ?? '',
    );
  }
}
