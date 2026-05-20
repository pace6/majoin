import 'package:matrix/matrix.dart';

/// A reliable room title.
///
/// Matrix's [Room.getLocalizedDisplayname] names an un-flagged 2-person room
/// "Group with X" — which happens whenever the `m.direct` account data
/// hasn't synced. Treat any room with a single other participant as a 1:1
/// chat and name it after that peer.
String roomTitle(Room room) {
  if (!room.isDirectChat) {
    final me = room.client.userID;
    final others =
        room.getParticipants().where((u) => u.id != me).toList();
    if (others.length == 1) {
      final name = others.first.calcDisplayname();
      if (name.isNotEmpty) return name;
    }
  }
  return room.getLocalizedDisplayname();
}
