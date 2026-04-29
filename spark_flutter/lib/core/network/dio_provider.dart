import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_state.dart';

final dioProvider = Provider<Dio>((ref) {
  final defineBase = const String.fromEnvironment('BACKEND_BASE_URL');
  final baseUrl =
      defineBase.isNotEmpty
          ? defineBase
          : kIsWeb
          ? 'http://localhost:8080'
          : Platform.isAndroid
          ? 'http://10.0.2.2:8080'
          : 'http://localhost:8080';

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = ref.read(authSessionProvider);
        if (session != null && session.token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${session.token}';
        }
        handler.next(options);
      },
    ),
  );
  return dio;
});
