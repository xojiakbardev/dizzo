import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Every test runs on an Uzbek device (the app's source language), so the
/// app's default language is Uzbek, as in production for uz devices.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.localesTestValue = const [Locale('uz')];
  binding.platformDispatcher.localeTestValue = const Locale('uz');
  await initializeDateFormatting();
  await testMain();
}
