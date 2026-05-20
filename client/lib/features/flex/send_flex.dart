import 'package:matrix/matrix.dart';
import 'flex_event.dart';

/// Send a Flex bubble to [room]. Strategy: send a `m.room.message` with
/// `msgtype: m.text` plus a sidecar `app.majoin.flex` key in the same content,
/// AND emit an `app.majoin.flex` event so clients that key off type can match.
///
/// To keep things simple in MVP we send a *single* event of custom type
/// `app.majoin.flex` and stuff the textual `body` field in the same content so
/// vanilla clients still see a readable line.
Future<String?> sendFlex(Room room, FlexBubble bubble) {
  final content = <String, dynamic>{
    'msgtype': 'm.text',
    'body': bubble.altText,
    'app.majoin.flex': bubble.toJson(),
  };
  return room.sendEvent(content, type: kFlexEventType);
}
