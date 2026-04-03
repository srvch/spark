import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/profile_api_repository.dart';

export '../../data/profile_api_repository.dart' show UserProfile;

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
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final prev = state.valueOrNull;
    try {
      final updated = await ref
          .read(profileApiRepositoryProvider)
          .updateProfile(displayName: displayName);
      state = AsyncValue.data(updated);
      final current = ref.read(authSessionProvider);
      if (current != null) {
        ref.read(authSessionProvider.notifier).state = AuthSession(
          token: current.token,
          userId: current.userId,
          phoneNumber: current.phoneNumber,
          displayName: updated.displayName,
        );
      }
    } catch (e, st) {
      if (prev != null) state = AsyncValue.data(prev);
      rethrow;
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return ProfileNotifier(ref);
});
