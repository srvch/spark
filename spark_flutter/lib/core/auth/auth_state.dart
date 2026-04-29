import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.phoneNumber,
    required this.displayName,
    this.handle,
    this.ageBand,
    this.gender,
    this.hidePhoneNumber = true,
  });

  final String token;
  final String userId;
  final String phoneNumber;
  final String displayName;
  final String? handle;
  final String? ageBand;
  final String? gender;
  final bool hidePhoneNumber;

  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'phoneNumber': phoneNumber,
    'displayName': displayName,
    'handle': handle,
    'ageBand': ageBand,
    'gender': gender,
    'hidePhoneNumber': hidePhoneNumber,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: '${json['token']}',
    userId: '${json['userId']}',
    phoneNumber: '${json['phoneNumber']}',
    displayName: '${json['displayName']}',
    handle: json['handle']?.toString(),
    ageBand: json['ageBand']?.toString(),
    gender: json['gender']?.toString(),
    hidePhoneNumber: json['hidePhoneNumber'] == true,
  );

  bool get isGuestShowcase =>
      token == guestShowcaseToken || userId == guestShowcaseUserId;

  bool get hasCompletedMandatoryProfile {
    if (isGuestShowcase) return true;
    final name = displayName.trim();
    final userHandle = (handle ?? '').trim().toLowerCase();
    final age = (ageBand ?? '').trim().toUpperCase();
    final gen = (gender ?? '').trim().toUpperCase();
    const validAgeBands = {'18-24', '25-34', '35-44', '45+'};
    const validGenders = {'MALE', 'FEMALE', 'OTHER'};
    final hasValidHandle = RegExp(r'^[a-z0-9_]{3,32}$').hasMatch(userHandle);
    final hasValidName = name.length >= 2 && name.toLowerCase() != 'spark user';
    return hasValidName &&
        hasValidHandle &&
        validAgeBands.contains(age) &&
        validGenders.contains(gen);
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
    handle: 'guest',
  );
}

/// True when user explicitly enters demo mode via "Continue as guest".
final guestShowcaseModeProvider = StateProvider<bool>((ref) => false);
