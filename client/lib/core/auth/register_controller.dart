import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import '../client/matrix_client.dart';
import '../config.dart';

/// Live availability state for the chosen username.
enum UsernameState { none, checking, available, taken, invalid, error }

class RegisterController extends ChangeNotifier {
  bool busy = false;
  String? error;

  UsernameState usernameState = UsernameState.none;
  Timer? _debounce;
  bool _homeserverReady = false;
  // Generation counter — drops results from stale (superseded) checks.
  int _gen = 0;

  /// Call on every keystroke in the username field. Debounces, then queries
  /// the homeserver for availability.
  void onUsernameChanged(String raw) {
    final user = raw.trim();
    _debounce?.cancel();
    if (user.isEmpty) {
      usernameState = UsernameState.none;
      notifyListeners();
      return;
    }
    usernameState = UsernameState.checking;
    notifyListeners();
    _debounce =
        Timer(const Duration(milliseconds: 450), () => _check(user));
  }

  Future<void> _check(String user) async {
    final gen = ++_gen;
    UsernameState result;
    try {
      final c = MatrixClientService.instance.client;
      if (!_homeserverReady) {
        await c.checkHomeserver(Uri.parse(AppConfig.homeserver));
        _homeserverReady = true;
      }
      final available = await c.checkUsernameAvailability(user);
      result = (available ?? false)
          ? UsernameState.available
          : UsernameState.taken;
    } on MatrixException catch (e) {
      result = switch (e.errcode) {
        'M_USER_IN_USE' => UsernameState.taken,
        'M_INVALID_USERNAME' => UsernameState.invalid,
        _ => UsernameState.error,
      };
    } catch (_) {
      result = UsernameState.error;
    }
    if (gen != _gen) return; // a newer keystroke superseded this check
    usernameState = result;
    notifyListeners();
  }

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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
