import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.phoneNumber,
    required this.displayName,
    this.ageBand,
    this.gender,
    this.hidePhoneNumber = true,
  });

  final String token;
  final String userId;
  final String phoneNumber;
  final String displayName;
  final String? ageBand;
  final String? gender;
  final bool hidePhoneNumber;

  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'phoneNumber': phoneNumber,
    'displayName': displayName,
    'ageBand': ageBand,
    'gender': gender,
    'hidePhoneNumber': hidePhoneNumber,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: '${json['token']}',
    userId: '${json['userId']}',
    phoneNumber: '${json['phoneNumber']}',
    displayName: '${json['displayName']}',
    ageBand: json['ageBand']?.toString(),
    gender: json['gender']?.toString(),
    hidePhoneNumber: json['hidePhoneNumber'] == true,
  );

  bool get isGuestShowcase =>
      token == guestShowcaseToken || userId == guestShowcaseUserId;

  bool get hasCompletedMandatoryProfile {
    if (isGuestShowcase) return true;
    final age = (ageBand ?? '').trim();
    final gen = (gender ?? '').trim();
    return displayName.trim().length >= 2 && age.isNotEmpty && gen.isNotEmpty;
  }
}

final authSessionProvider = StateProvider<AuthSession?>((ref) => null);

const String guestShowcaseToken = 'guest-showcase-local-token';
const String guestShowcaseUserId = 'guest-showcase-user';

AuthSession buildGuestShowcaseSession() {
  return const AuthSession(
    token: guestShowcaseToken,
    userId: guestShowcaseUserId,
    phoneNumber: 'Guest',
    displayName: 'Guest user',
  );
}

/// True when user explicitly enters demo mode via "Continue as guest".
final guestShowcaseModeProvider = StateProvider<bool>((ref) => false);
