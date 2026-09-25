import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/retry_policy.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Release builds keep nothing in the device log (errors carry URLs and
  // server details).
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  // Keep the native splash until the first Flutter frame (the brand loader
  // takes over while the session is restored).
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(retry: providerRetry, child: DizzoApp()));
  binding.addPostFrameCallback((_) => FlutterNativeSplash.remove());
}
