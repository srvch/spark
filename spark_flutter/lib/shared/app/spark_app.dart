import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_persistence_service.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/screens/phone_login_screen.dart';
import '../navigation/root_shell.dart';

class SparkApp extends ConsumerWidget {
  const SparkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
