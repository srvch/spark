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

  Map<String, dynamic> toJson() => {
        'token': token,
        'userId': userId,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'hidePhoneNumber': hidePhoneNumber,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: '${json['token']}',
        userId: '${json['userId']}',
        phoneNumber: '${json['phoneNumber']}',
        displayName: '${json['displayName']}',
        hidePhoneNumber: json['hidePhoneNumber'] == true,
      );
}

final authSessionProvider = StateProvider<AuthSession?>((ref) => null);
