import 'package:flutter/material.dart';
import 'lmis_app.dart';
import 'data/local/isar/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarService.instance.init();
  runApp(const LmisApp());
}
