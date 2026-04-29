import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_persistence_service.dart';
import 'core/auth/auth_state.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'features/spark/presentation/controllers/spark_controller.dart';
import 'shared/app/spark_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseInitError;
  try {
    await ensureFirebaseInitialized();
    if (!kReleaseMode && Platform.isIOS) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }
  } catch (e) {
    firebaseInitError = e;
  }

  final savedSession = await AuthPersistenceService.load();

  if (firebaseInitError != null) {
    runApp(_FirebaseInitErrorApp(error: firebaseInitError.toString()));
    return;
  }

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

class _FirebaseInitErrorApp extends StatelessWidget {
  const _FirebaseInitErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0C1829),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFCA5A5),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Firebase failed to initialize',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Fix iOS Firebase config (GoogleService-Info.plist) and restart the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _handleDeepLink(Uri uri, WidgetRef ref) {
  // scheme: spark  host: sparks  path: /{sparkId}
  if (uri.scheme == 'spark' && uri.host == 'sparks') {
    final sparkId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    if (sparkId != null && sparkId.isNotEmpty) {
      ref.read(pendingDeepLinkSparkIdProvider.notifier).state = sparkId;
    }
  }
}
