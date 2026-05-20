import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqf;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Singleton wrapper around Matrix [Client].
///
/// Why singleton: Matrix client holds the single /sync stream; multiple
/// instances would duplicate sync traffic and confuse encryption state.
class MatrixClientService extends ChangeNotifier {
  MatrixClientService._();
  static final instance = MatrixClientService._();

  Client? _client;
  Client get client => _client!;
  bool get hasClient => _client != null;
  bool get isLoggedIn => _client?.isLogged() ?? false;

  Future<void> init() async {
    if (_client != null) return;
    await Hive.initFlutter();
    final dir = await getApplicationSupportDirectory();

    final isFfi = !kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    if (isFfi) {
      ffi.sqfliteFfiInit();
    }
    final factory =
        isFfi ? ffi.databaseFactoryFfi : sqf.databaseFactory;
    final dbPath = p.join(dir.path, 'majoin.db');
    final sqfliteDatabase = await factory.openDatabase(dbPath);

    final db = await MatrixSdkDatabase.init(
      'majoin',
      database: sqfliteDatabase,
      sqfliteFactory: factory,
      fileStorageLocation: dir.uri,
    );

    _client = Client(
      'majoin',
      database: db,
      supportedLoginTypes: {AuthenticationTypes.password},
    );
    await _client!.init();
    notifyListeners();
  }

  Future<void> login({
    required String homeserver,
    required String user,
    required String password,
  }) async {
    final c = client;
    await c.checkHomeserver(Uri.parse(homeserver));
    await c.login(
      LoginType.mLoginPassword,
      identifier: AuthenticationUserIdentifier(user: user),
      password: password,
      initialDeviceDisplayName: 'majoin (${defaultTargetPlatform.name})',
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await client.logout();
    notifyListeners();
  }
}
