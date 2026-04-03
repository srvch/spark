import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../data/social_api_repository.dart';
import '../../domain/social.dart';

final socialApiRepositoryProvider = Provider<SocialApiRepository>((ref) {
  return SocialApiRepository(dio: ref.watch(dioProvider));
});

final friendsProvider = StateProvider<List<FriendUser>>((ref) => const []);
final incomingFriendRequestsProvider =
    StateProvider<List<IncomingFriendRequest>>((ref) => const []);
final groupsProvider = StateProvider<List<SparkGroup>>((ref) => const []);
final incomingGroupInvitesProvider = StateProvider<List<GroupInviteInboxItem>>(
  (ref) => const [],
);
final socialLoadingProvider = StateProvider<bool>((ref) => false);
final socialErrorProvider = StateProvider<String?>((ref) => null);

final socialControllerProvider = Provider<SocialController>((ref) {
  return SocialController(ref);
});

class SocialController {
  SocialController(this.ref);

  final Ref ref;

  Future<void> refreshAll() async {
    ref.read(socialLoadingProvider.notifier).state = true;
    ref.read(socialErrorProvider.notifier).state = null;
    try {
      final api = ref.read(socialApiRepositoryProvider);
      final results = await Future.wait([
        api.fetchFriends(),
        api.fetchIncomingFriendRequests(),
        api.fetchGroups(),
        api.fetchIncomingGroupInvites(),
      ]);
      ref.read(friendsProvider.notifier).state = results[0] as List<FriendUser>;
      ref.read(incomingFriendRequestsProvider.notifier).state =
          results[1] as List<IncomingFriendRequest>;
      ref.read(groupsProvider.notifier).state = results[2] as List<SparkGroup>;
      ref.read(incomingGroupInvitesProvider.notifier).state =
          results[3] as List<GroupInviteInboxItem>;
    } catch (e) {
      ref.read(socialErrorProvider.notifier).state = '$e';
    } finally {
      ref.read(socialLoadingProvider.notifier).state = false;
    }
  }

  Future<void> sendFriendRequest(String phoneNumber) async {
    await ref
        .read(socialApiRepositoryProvider)
        .sendFriendRequest(phoneNumber: phoneNumber);
    await refreshAll();
  }

  Future<void> respondFriendRequest({
    required String requestId,
    required FriendRequestDecision decision,
  }) async {
    await ref
        .read(socialApiRepositoryProvider)
        .respondFriendRequest(requestId: requestId, decision: decision);
    await refreshAll();
  }

  Future<GroupSummary> createGroup({
    required String name,
    required String description,
  }) async {
    final summary = await ref
        .read(socialApiRepositoryProvider)
        .createGroup(name: name, description: description);
    await refreshAll();
    return summary;
  }

  Future<void> inviteFriendToGroup({
    required String groupId,
    required String userId,
  }) async {
    await ref
        .read(socialApiRepositoryProvider)
        .inviteFriendToGroup(groupId: groupId, userId: userId);
    await refreshAll();
  }

  Future<void> respondGroupInvite({
    required String groupId,
    required String inviteId,
    required FriendRequestDecision decision,
  }) async {
    await ref
        .read(socialApiRepositoryProvider)
        .respondGroupInvite(
          groupId: groupId,
          inviteId: inviteId,
          decision: decision,
        );
    await refreshAll();
  }
}
