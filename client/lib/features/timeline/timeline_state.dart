import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Per-screen state shared between Composer + Timeline (reply target).
class TimelineUiState extends ChangeNotifier {
  Event? _replyTo;
  Event? get replyTo => _replyTo;

  void setReply(Event? e) {
    _replyTo = e;
    notifyListeners();
  }

  void clearReply() => setReply(null);
}
