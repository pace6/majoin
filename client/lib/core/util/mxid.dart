import '../config.dart';

/// Matrix user IDs are `@localpart:server`. Users only ever type the localpart
/// (`chatchai`) — these helpers convert to and from the full MXID so the
/// Matrix format never leaks into the UI.

/// Server name of an MXID — the host of the configured homeserver.
String get matrixServerName => Uri.parse(AppConfig.homeserver).host;

/// Normalize a user-typed contact identifier into a full MXID.
/// Accepts `chatchai`, `@chatchai`, or an already-full `@chatchai:server`.
String mxidFromInput(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return s;
  if (s.startsWith('@') && s.contains(':')) return s;
  final local = s.startsWith('@') ? s.substring(1) : s;
  return '@$local:$matrixServerName';
}

/// The localpart of an MXID for display — `@chatchai:server` -> `chatchai`.
String localpartOf(String mxid) =>
    mxid.startsWith('@') && mxid.contains(':')
        ? mxid.substring(1, mxid.indexOf(':'))
        : mxid;

/// True when [raw] looks like a usable contact id (non-empty localpart).
bool isValidContactInput(String raw) {
  final local = localpartOf(mxidFromInput(raw));
  return local.isNotEmpty;
}

/// Parse a Matrix user identifier out of a scanned QR payload.
///
/// Accepts a `matrix.to` share URL — the canonical Matrix format we render
/// in "My QR" — as well as a bare mxid or a raw localpart, so users can
/// scan QRs produced by other Matrix clients too.
///
/// Returns the full `@local:server` mxid on success, or `null` if the
/// payload doesn't look like a user identifier (e.g. a room link, an
/// arbitrary URL).
String? mxidFromShareUrl(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;

  // matrix.to URLs put the mxid (percent-encoded) after `#/`. The path may
  // include `?via=` query params; ignore those.
  final lower = s.toLowerCase();
  final hashIdx = s.indexOf('#/');
  if ((lower.startsWith('https://matrix.to/') ||
          lower.startsWith('http://matrix.to/') ||
          lower.startsWith('matrix:')) &&
      hashIdx != -1) {
    s = s.substring(hashIdx + 2);
    final q = s.indexOf('?');
    if (q != -1) s = s.substring(0, q);
    s = Uri.decodeComponent(s);
  }

  // matrix.to also encodes rooms (`!id:server`, `#alias:server`). We only
  // care about user identifiers here.
  if (s.startsWith('!') || s.startsWith('#')) return null;

  final mxid = mxidFromInput(s);
  return isValidContactInput(mxid) && mxid.startsWith('@') ? mxid : null;
}
