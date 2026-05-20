import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import '../client/matrix_client.dart';

class RegisterController extends ChangeNotifier {
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
      final c = MatrixClientService.instance.client;
      await c.checkHomeserver(Uri.parse(homeserver));
      await c.register(
        username: user,
        password: password,
        initialDeviceDisplayName:
            'majoin (${defaultTargetPlatform.name})',
        auth: AuthenticationData(type: AuthenticationTypes.dummy),
      );
      return true;
    } catch (e) {
      // Matrix often replies 401 with `flows` requiring m.login.dummy.
      // The block above already supplies dummy; if more flows demanded,
      // server admin must adjust enable_registration_without_verification.
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
