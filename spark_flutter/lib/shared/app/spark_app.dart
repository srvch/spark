import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_persistence_service.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/screens/phone_login_screen.dart';
import '../../features/spark/presentation/controllers/spark_controller.dart';
import '../navigation/root_shell.dart';

class SparkApp extends ConsumerStatefulWidget {
  const SparkApp({super.key});

  @override
  ConsumerState<SparkApp> createState() => _SparkAppState();
}

class _SparkAppState extends ConsumerState<SparkApp> {
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    final appLinks = AppLinks();
    // Cold start link
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
    // Foreground links
    _deepLinkSub = appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'spark' && uri.host == 'sparks') {
      final sparkId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (sparkId != null && sparkId.isNotEmpty) {
        debugPrint('[DeepLink] Opening spark: $sparkId');
        ref.read(pendingDeepLinkSparkIdProvider.notifier).state = sparkId;
      }
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Persist / clear session whenever it changes
    ref.listen<AuthSession?>(authSessionProvider, (_, next) {
      if (next != null) {
        unawaited(AuthPersistenceService.save(next));
      } else {
        unawaited(AuthPersistenceService.clear());
      }
    });

    final session = ref.watch(authSessionProvider);
    return MaterialApp(
      title: 'Spark',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Keep visual styling consistent across emulator + physical devices.
      themeMode: ThemeMode.system,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      home: session == null ? const PhoneLoginScreen() : const RootShell(),
    );
  }
}
