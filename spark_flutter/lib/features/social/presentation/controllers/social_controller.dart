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
final outgoingFriendRequestsProvider =
    StateProvider<List<OutgoingFriendRequest>>((ref) => const []);
final friendSuggestionsProvider =
    StateProvider<List<FriendSuggestion>>((ref) => const []);
final groupsProvider = StateProvider<List<SparkGroup>>((ref) => const []);
final incomingGroupInvitesProvider =
    StateProvider<List<GroupInviteInboxItem>>((ref) => const []);
final socialLoadingProvider = StateProvider<bool>((ref) => false);
final socialErrorProvider = StateProvider<String?>((ref) => null);
final myAvailabilityProvider = StateProvider<String>((ref) => 'NONE');
final friendSortProvider = StateProvider<FriendSort>((ref) => FriendSort.recent);
final groupSortProvider = StateProvider<GroupSort>((ref) => GroupSort.recent);

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
        api.fetchOutgoingFriendRequests(),
        api.fetchGroups(),
        api.fetchIncomingGroupInvites(),
        api.fetchFriendSuggestions(),
      ]);
      ref.read(friendsProvider.notifier).state = results[0] as List<FriendUser>;
      ref.read(incomingFriendRequestsProvider.notifier).state =
          results[1] as List<IncomingFriendRequest>;
      ref.read(outgoingFriendRequestsProvider.notifier).state =
          results[2] as List<OutgoingFriendRequest>;
      ref.read(groupsProvider.notifier).state = results[3] as List<SparkGroup>;
      ref.read(incomingGroupInvitesProvider.notifier).state =
          results[4] as List<GroupInviteInboxItem>;
      ref.read(friendSuggestionsProvider.notifier).state =
          results[5] as List<FriendSuggestion>;
    } catch (e) {
      ref.read(socialErrorProvider.notifier).state = '$e';
    } finally {
      ref.read(socialLoadingProvider.notifier).state = false;
    }
  }

  Future<void> sendFriendRequest(String phoneNumber, {String? message}) async {
    await ref.read(socialApiRepositoryProvider).sendFriendRequest(
          phoneNumber: phoneNumber,
          message: message,
        );
    await refreshAll();
  }

  Future<void> cancelFriendRequest({required String requestId}) async {
    ref.read(outgoingFriendRequestsProvider.notifier).update(
      (list) => list.where((r) => r.requestId != requestId).toList(),
    );
    try {
      await ref.read(socialApiRepositoryProvider).cancelFriendRequest(requestId: requestId);
    } finally {
      await refreshAll();
    }
  }

  Future<void> respondFriendRequest({
    required String requestId,
    required InviteDecision decision,
  }) async {
    ref.read(incomingFriendRequestsProvider.notifier).update(
      (list) => list.where((r) => r.requestId != requestId).toList(),
    );
    try {
      await ref.read(socialApiRepositoryProvider).respondFriendRequest(
            requestId: requestId,
            decision: decision,
          );
      await refreshAll();
    } catch (e) {
      await refreshAll();
      rethrow;
    }
  }

  Future<void> unfriend({required String userId}) async {
    ref.read(friendsProvider.notifier).update(
      (list) => list.where((f) => f.userId != userId).toList(),
    );
    try {
      await ref.read(socialApiRepositoryProvider).unfriend(userId: userId);
      await refreshAll();
    } catch (e) {
      await refreshAll();
      rethrow;
    }
  }

  Future<void> setAvailability(String status) async {
    ref.read(myAvailabilityProvider.notifier).state = status;
    try {
      await ref.read(socialApiRepositoryProvider).setAvailability(status: status);
    } catch (_) {
      ref.read(myAvailabilityProvider.notifier).state =
          status == 'OPEN' ? 'NONE' : 'OPEN';
    }
  }

  Future<void> blockUser({required String userId}) async {
    await ref.read(socialApiRepositoryProvider).blockUser(userId: userId);
    ref.read(friendsProvider.notifier).update(
      (list) => list.where((f) => f.userId != userId).toList(),
    );
  }

  Future<void> reportUser({required String userId, String? reason}) async {
    await ref.read(socialApiRepositoryProvider).reportUser(userId: userId, reason: reason);
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

  Future<void> updateGroup({
    required String groupId,
    required String name,
    required String description,
  }) async {
    await ref.read(socialApiRepositoryProvider).updateGroup(
          groupId: groupId,
          name: name,
          description: description,
        );
    await refreshAll();
  }

  Future<void> archiveGroup({required String groupId}) async {
    ref.read(groupsProvider.notifier).update(
      (list) => list.where((g) => g.groupId != groupId).toList(),
    );
    try {
      await ref.read(socialApiRepositoryProvider).archiveGroup(groupId: groupId);
    } finally {
      await refreshAll();
    }
  }

  Future<void> unarchiveGroup({required String groupId}) async {
    try {
      await ref.read(socialApiRepositoryProvider).unarchiveGroup(groupId: groupId);
    } finally {
      await refreshAll();
    }
  }

  Future<void> leaveGroup({required String groupId}) async {
    ref.read(groupsProvider.notifier).update(
      (list) => list.where((g) => g.groupId != groupId).toList(),
    );
    try {
      await ref.read(socialApiRepositoryProvider).leaveGroup(groupId: groupId);
      await refreshAll();
    } catch (e) {
      await refreshAll();
      rethrow;
    }
  }

  Future<void> inviteFriendToGroup({
    required String groupId,
    required String userId,
  }) async {
    await ref.read(socialApiRepositoryProvider).inviteFriendToGroup(
          groupId: groupId,
          userId: userId,
        );
    await refreshAll();
  }

  Future<void> removeMemberFromGroup({
    required String groupId,
    required String userId,
  }) async {
    await ref.read(socialApiRepositoryProvider).removeMemberFromGroup(
          groupId: groupId,
          userId: userId,
        );
    await refreshAll();
  }

  Future<void> promoteToAdmin({
    required String groupId,
    required String userId,
  }) async {
    await ref.read(socialApiRepositoryProvider).promoteToAdmin(
          groupId: groupId,
          userId: userId,
        );
  }

  Future<void> demoteToMember({
    required String groupId,
    required String userId,
  }) async {
    await ref.read(socialApiRepositoryProvider).demoteToMember(
          groupId: groupId,
          userId: userId,
        );
  }

  Future<void> nudgePendingMember({
    required String groupId,
    required String userId,
  }) async {
    await ref.read(socialApiRepositoryProvider).nudgePendingMember(
          groupId: groupId,
          userId: userId,
        );
  }

  Future<void> respondGroupInvite({
    required String groupId,
    required String inviteId,
    required InviteDecision decision,
  }) async {
    ref.read(incomingGroupInvitesProvider.notifier).update(
      (list) => list.where((i) => i.inviteId != inviteId).toList(),
    );
    try {
      await ref.read(socialApiRepositoryProvider).respondGroupInvite(
            groupId: groupId,
            inviteId: inviteId,
            decision: decision,
          );
      await refreshAll();
    } catch (e) {
      await refreshAll();
      rethrow;
    }
  }
}
