import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_state.dart';
import '../firebase/firebase_bootstrap.dart';
import '../network/dio_provider.dart';

class PushRegistrationService {
  PushRegistrationService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<void> registerDeviceToken(AuthSession session) async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        await ensureFirebaseInitialized();
        final messaging = FirebaseMessaging.instance;

        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          final token = await messaging.getToken();
          if (token != null) {
            await _dio.post(
              '/api/v1/push/devices',
              data: {
                'token': token,
                'platform': Platform.isIOS ? 'ios' : 'android',
              },
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> unregisterDeviceToken() async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _dio.delete('/api/v1/push/devices', data: {'token': token});
        }
      }
    } catch (_) {}
  }
}

final pushRegistrationServiceProvider = Provider<PushRegistrationService>((
  ref,
) {
  return PushRegistrationService(dio: ref.watch(dioProvider));
});
