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
