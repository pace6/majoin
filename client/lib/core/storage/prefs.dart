import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static const _kHomeserver = 'homeserver';
  static const _kLastUser = 'last_user';

  static Future<String?> homeserver() async =>
      (await SharedPreferences.getInstance()).getString(_kHomeserver);
  static Future<void> setHomeserver(String v) async =>
      (await SharedPreferences.getInstance()).setString(_kHomeserver, v);

  static Future<String?> lastUser() async =>
      (await SharedPreferences.getInstance()).getString(_kLastUser);
  static Future<void> setLastUser(String v) async =>
      (await SharedPreferences.getInstance()).setString(_kLastUser, v);
}
