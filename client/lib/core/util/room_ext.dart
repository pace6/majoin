import 'package:matrix/matrix.dart';

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
