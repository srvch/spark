import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.phoneNumber,
    required this.displayName,
    this.hidePhoneNumber = true,
  });

  final String token;
  final String userId;
  final String phoneNumber;
  final String displayName;
  final bool hidePhoneNumber;
}

final authSessionProvider = StateProvider<AuthSession?>((ref) => null);
