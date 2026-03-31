import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_state.dart';
import '../network/dio_provider.dart';

class PushRegistrationService {
  PushRegistrationService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<void> registerDeviceToken(AuthSession session) async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      final platform = kIsWeb
          ? 'web'
          : Platform.isIOS
          ? 'ios'
          : 'android';

      await _dio.post<void>(
        '/api/v1/push/devices',
        data: {
          'token': token,
          'platform': platform,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.token}',
          },
        ),
      );
    } catch (_) {
      // Firebase may be unconfigured in local dev. Ignore quietly.
    }
  }
}

final pushRegistrationServiceProvider = Provider<PushRegistrationService>((ref) {
  return PushRegistrationService(dio: ref.watch(dioProvider));
});
