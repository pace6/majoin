import 'package:flutter/material.dart';
import 'app.dart';
import 'core/client/matrix_client.dart';
import 'core/i18n/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleController.init();
  await MatrixClientService.instance.init();
  runApp(const MajoinApp());
}
