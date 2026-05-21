import 'package:matrix/matrix.dart';
import 'mxid.dart';

/// Localparts of known Majoin bot accounts (server-agnostic).
const botLocalparts = {'weather'};

/// The other party of a 1:1 room — its `m.direct` peer, or the sole hero.
/// Null for group rooms.
String? directPeerId(Room room) {
  if (!isOneToOne(room)) return null;
  final heroes = _heroes(room);
  return room.directChatMatrixID ?? (heroes.isEmpty ? null : heroes.first);
}

/// True if this 1:1 room's peer is a known Majoin bot.
bool isBotRoom(Room room) {
  final peer = directPeerId(room);
  return peer != null && botLocalparts.contains(localpartOf(peer));
}

/// When the chat started — the user's own join/invite event timestamp,
/// falling back to room creation. `getState` returns a StrippedStateEvent;
/// only joined-room state (the full [Event]) carries a timestamp.
DateTime? roomStartTime(Room room) {
  final myId = room.client.userID;
  final member =
      myId == null ? null : room.getState(EventTypes.RoomMember, myId);
  if (member is Event) return member.originServerTs;
  final create = room.getState(EventTypes.RoomCreate);
  if (create is Event) return create.originServerTs;
  return null;
}

/// Other-party user IDs from the room summary heroes — available even when
/// full member state hasn't loaded (unlike getParticipants()).
List<String> _heroes(Room room) {
  final me = room.client.userID;
  return (room.summary.mHeroes ?? const <String>[])
      .where((h) => h.isNotEmpty && h != me)
      .toList();
}

/// True for a 1:1 chat — the m.direct flag, or (when that hasn't synced) a
/// nameless room with exactly one other hero.
bool isOneToOne(Room room) {
  if (room.isDirectChat) return true;
  if (room.name.isNotEmpty) return false; // an explicitly named room = group
  return _heroes(room).length == 1;
}

/// An existing 1:1 room with [peerId], if any. Used to reuse a chat instead
/// of letting startDirectChat create a duplicate when m.direct hasn't synced.
Room? findDirectRoom(Client client, String peerId) {
  for (final r in client.rooms) {
    if (r.membership != Membership.join) continue;
    if (r.directChatMatrixID == peerId) return r;
    final heroes = _heroes(r);
    if (r.name.isEmpty && heroes.length == 1 && heroes.first == peerId) {
      return r;
    }
  }
  return null;
}

/// A reliable room title.
///
/// Matrix's [Room.getLocalizedDisplayname] names an un-flagged 2-person room
/// "Group with X" whenever the `m.direct` account data hasn't synced. Name
/// any nameless single-peer room after that peer instead.
String roomTitle(Room room) {
  if (room.name.isEmpty) {
    final heroes = _heroes(room);
    if (heroes.length == 1) {
      final name =
          room.unsafeGetUserFromMemoryOrFallback(heroes.first).calcDisplayname();
      if (name.isNotEmpty) return name;
    }
  }
  return room.getLocalizedDisplayname();
}

/// Like [roomTitle], but appends the joined-member count for group rooms —
/// e.g. "Weekend Trip (5)". 1:1 chats are returned unchanged.
String roomTitleWithCount(Room room) {
  final base = roomTitle(room);
  if (isOneToOne(room)) return base;
  final count = room.summary.mJoinedMemberCount ?? 0;
  return count > 0 ? '$base ($count)' : base;
}
