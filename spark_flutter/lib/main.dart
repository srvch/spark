import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_persistence_service.dart';
import 'core/auth/auth_state.dart';
import 'features/spark/presentation/controllers/spark_controller.dart';
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

/// Initialises the deep-link listener after the widget tree is mounted.
/// Call this once from SparkApp's [ConsumerState.initState].
void initDeepLinks(WidgetRef ref) {
  final appLinks = AppLinks();

  // Handle the link that launched the app cold
  appLinks.getInitialLink().then((uri) {
    if (uri != null) _handleDeepLink(uri, ref);
  });

  // Handle links while app is running
  appLinks.uriLinkStream.listen((uri) {
    _handleDeepLink(uri, ref);
  });
}

void _handleDeepLink(Uri uri, WidgetRef ref) {
  // scheme: spark  host: sparks  path: /{sparkId}
  if (uri.scheme == 'spark' && uri.host == 'sparks') {
    final sparkId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    if (sparkId != null && sparkId.isNotEmpty) {
      debugPrint('[DeepLink] Opening spark: $sparkId');
      ref.read(pendingDeepLinkSparkIdProvider.notifier).state = sparkId;
    }
  }
}
