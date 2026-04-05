import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_persistence_service.dart';
import 'core/auth/auth_state.dart';
import 'shared/app/spark_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('APP_STARTING: main()');

  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  final savedSession = await AuthPersistenceService.load();

  runApp(
    ProviderScope(
      overrides: [
        if (savedSession != null)
          authSessionProvider.overrideWith((ref) => savedSession),
      ],
      child: const SparkApp(),
    ),
  );
}
