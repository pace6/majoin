import 'package:flutter/foundation.dart';
import '../client/matrix_client.dart';

class LoginController extends ChangeNotifier {
  bool busy = false;
  String? error;

  Future<bool> submit({
    required String homeserver,
    required String user,
    required String password,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await MatrixClientService.instance.login(
        homeserver: homeserver,
        user: user,
        password: password,
      );
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
