import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Per-screen state shared between Composer + Timeline.
/// Holds the reply target and the edit target — mutually exclusive.
class TimelineUiState extends ChangeNotifier {
  Event? _replyTo;
  Event? get replyTo => _replyTo;

  Event? _editTarget;
  Event? get editTarget => _editTarget;

  void setReply(Event? e) {
    _replyTo = e;
    if (e != null) _editTarget = null;
    notifyListeners();
  }

  void clearReply() => setReply(null);

  void setEdit(Event? e) {
    _editTarget = e;
    if (e != null) _replyTo = null;
    notifyListeners();
  }

  void clearEdit() => setEdit(null);
}
