import 'dart:io';

import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';

/// Download an event's attachment — decrypting it for E2EE rooms — into a
/// cached temp file and return it. Works for plain and encrypted rooms;
/// players/viewers can then read straight off the local file.
Future<File> attachmentFile(Event event) async {
  final dir = await getTemporaryDirectory();
  final safe = (event.body.isEmpty ? 'attachment' : event.body)
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final f = File('${dir.path}/majoin_${event.eventId.hashCode}_$safe');
  if (await f.exists() && await f.length() > 0) return f;
  final matrixFile = await event.downloadAndDecryptAttachment();
  await f.writeAsBytes(matrixFile.bytes);
  return f;
}
