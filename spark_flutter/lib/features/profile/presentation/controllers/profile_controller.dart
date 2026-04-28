import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/profile_api_repository.dart';

export '../../data/profile_api_repository.dart' show UserProfile;

const _kHidePhoneKey = 'hide_phone_number';

final profileApiRepositoryProvider = Provider<ProfileApiRepository>((ref) {
  return ProfileApiRepository(dio: ref.watch(dioProvider));
});

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  ProfileNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref ref;

  void _init() {
    final session = ref.read(authSessionProvider);
    if (session != null) {
      load();
    }
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final profile = await ref.read(profileApiRepositoryProvider).fetchProfile();
      // Read the locally-persisted privacy pref (backend doesn't store this yet).
      final prefs = await SharedPreferences.getInstance();
      final hidePhone = prefs.getBool(_kHidePhoneKey) ?? true;
      state = AsyncValue.data(profile.copyWith(hidePhoneNumber: hidePhone));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final prev = state.valueOrNull;
    try {
      final updated = await ref
          .read(profileApiRepositoryProvider)
          .updateProfile(
            displayName: displayName,
            ageBand: prev?.ageBand.isNotEmpty == true ? prev!.ageBand : '25-34',
            gender: prev?.gender.isNotEmpty == true ? prev!.gender : 'OTHER',
          );
      state = AsyncValue.data(updated);
      final current = ref.read(authSessionProvider);
      if (current != null) {
        ref.read(authSessionProvider.notifier).state = AuthSession(
          token: current.token,
          userId: current.userId,
          phoneNumber: current.phoneNumber,
          displayName: updated.displayName,
          ageBand: updated.ageBand,
          gender: updated.gender,
          hidePhoneNumber: current.hidePhoneNumber,
        );
      }
    } catch (e) {
      if (prev != null) state = AsyncValue.data(prev);
      rethrow;
    }
  }

  Future<void> toggleHidePhoneNumber(bool hide) async {
    final prev = state.valueOrNull;
    if (prev == null) return;
    // Save locally — backend doesn't support this field yet so no API call.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHidePhoneKey, hide);
    final updated = prev.copyWith(hidePhoneNumber: hide);
    state = AsyncValue.data(updated);
    // Mirror into auth session.
    final current = ref.read(authSessionProvider);
    if (current != null) {
      ref.read(authSessionProvider.notifier).state = AuthSession(
        token: current.token,
        userId: current.userId,
        phoneNumber: current.phoneNumber,
        displayName: current.displayName,
        ageBand: current.ageBand,
        gender: current.gender,
        hidePhoneNumber: hide,
      );
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return ProfileNotifier(ref);
});
