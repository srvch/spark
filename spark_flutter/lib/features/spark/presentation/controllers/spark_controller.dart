import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/plan_parse_api_repository.dart';
import '../../data/places_autocomplete_service.dart';
import '../../data/spark_api_repository.dart';
import '../../domain/spark.dart';
import '../../domain/spark_invite.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/auth_state.dart';

final selectedCategoryProvider = StateProvider<SparkCategory?>((ref) => null);
final selectedRadiusProvider = StateProvider<int>((ref) => 5);
final selectedSortProvider = StateProvider<SparkSort>(
  (ref) => SparkSort.nearest,
);
final selectedLocationProvider = StateProvider<String>((ref) => 'Indiranagar');

/// Holds an optional groupId for pre-filling "Create Spark" from a group screen
final sparkCreationContextProvider = StateProvider<String?>((ref) => null);

final savedLocationsProvider = Provider<List<String>>((ref) {
  return const [
    'Current location',
    'Home',
    'Office',
    'Campus',
    'Downtown',
    'City Center',
  ];
});

final recentLocationsProvider = Provider<List<String>>((ref) {
  return const ['Indiranagar', 'Koramangala', 'City Center'];
});

final locationCatalogProvider = Provider<List<String>>((ref) {
  return const [
    'Indiranagar',
    'Koramangala',
    'HSR Layout',
    'Whitefield',
    'Electronic City',
    'MG Road',
    'Church Street',
    'Marathahalli',
    'Bellandur',
    'JP Nagar',
    'Jayanagar',
    'Yelahanka',
    'Hebbal',
    'Sarjapur Road',
    'Central Park',
    'Library Circle',
    'Main Gate',
    'Hostel Area',
    'Metro Exit Gate',
    'City Center',
    'Downtown',
    'Airport Terminal 3',
  ];
});

final placesApiKeyProvider = Provider<String>((ref) {
  return const String.fromEnvironment('GOOGLE_PLACES_API_KEY');
});

final placesAutocompleteServiceProvider = Provider<PlacesAutocompleteService>((
  ref,
) {
  return PlacesAutocompleteService(apiKey: ref.watch(placesApiKeyProvider));
});

final joinedSparkIdsProvider = StateProvider<Set<String>>((ref) => <String>{});
final createdSparksProvider = StateProvider<List<Spark>>((ref) => const []);
final remoteSparksProvider = StateProvider<List<Spark>>((ref) => const []);
final sparksLoadingProvider = StateProvider<bool>((ref) => false);
final sparksLoadingMoreProvider = StateProvider<bool>((ref) => false);
final sparksErrorProvider = StateProvider<String?>((ref) => null);
final nearbyPageProvider = StateProvider<int>((ref) => 0);
final nearbyHasMoreProvider = StateProvider<bool>((ref) => false);
final sparkInvitesProvider = StateProvider<List<SparkInvite>>(
  (ref) => const [],
);
final sparkInvitesLoadingProvider = StateProvider<bool>((ref) => false);
final sparkInvitesLoadingMoreProvider = StateProvider<bool>((ref) => false);
final sparkInvitesErrorProvider = StateProvider<String?>((ref) => null);
final invitePageProvider = StateProvider<int>((ref) => 0);
final inviteHasMoreProvider = StateProvider<bool>((ref) => false);

/// IDs of sparks where current user has tapped "On my way"
final onMyWaySparkIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

/// IDs of sparks the current user has checked in to
final checkedInSparkIdsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

final sparkParticipantsProvider = StateNotifierProvider.family<
  SparkParticipantsNotifier,
  List<String>,
  String
>((ref, sparkId) {
  return SparkParticipantsNotifier(
    ref.watch(sparkApiRepositoryProvider),
    sparkId,
  );
});

class SparkParticipantsNotifier extends StateNotifier<List<String>> {
  SparkParticipantsNotifier(this._repository, this._sparkId) : super([]) {
    fetch();
  }
  final SparkApiRepository _repository;
  final String _sparkId;

  Future<void> fetch() async {
    try {
      state = await _repository.fetchParticipants(_sparkId);
    } catch (_) {}
  }
}

/// Tracks how many chat conversations the user has "seen" (for unread badge)
final seenChatCountProvider = StateProvider<int>((ref) => 0);
final currentUserIdProvider = Provider<String>((ref) {
  return ref.watch(authSessionProvider)?.userId ?? 'anonymous';
});
final currentUserInitialsProvider = Provider<String>((ref) {
  final name = ref.watch(authSessionProvider)?.displayName.trim();
  if (name == null || name.isEmpty) return 'ME';
  final parts = name.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    final single = parts.first;
    return single.isEmpty ? 'ME' : single.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
});

final allSparksProvider = Provider<List<Spark>>((ref) {
  final remote = ref.watch(remoteSparksProvider);
  final repoSparks = remote;
  final created = ref.watch(createdSparksProvider);
  final merged =
      [...created, ...repoSparks]
          .where(
            (spark) =>
                spark.startsInMinutes > 0 && spark.startsInMinutes <= 24 * 60,
          )
          .toList();
  final deduped = <String, Spark>{};
  for (final spark in merged) {
    deduped.putIfAbsent(spark.id, () => spark);
  }
  return deduped.values.toList();
});

final sparksProvider = Provider<List<Spark>>((ref) {
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final radius = ref.watch(selectedRadiusProvider);
  final sort = ref.watch(selectedSortProvider);

  Iterable<Spark> sparks = ref
      .watch(allSparksProvider)
      .where((spark) => spark.distanceKm <= radius);

  if (selectedCategory != null) {
    sparks = sparks.where((spark) => spark.category == selectedCategory);
  }

  final result = sparks.toList();
  switch (sort) {
    case SparkSort.nearest:
      result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    case SparkSort.startingSoon:
      result.sort((a, b) => a.startsInMinutes.compareTo(b.startsInMinutes));
    case SparkSort.mostJoined:
      result.sort((a, b) => b.joinedCount.compareTo(a.joinedCount));
  }
  return result;
});

final happeningNowSparksProvider = Provider<List<Spark>>((ref) {
  return ref
      .watch(sparksProvider)
      .where((spark) => spark.isHappeningSoon)
      .toList();
});

final laterTodaySparksProvider = Provider<List<Spark>>((ref) {
  return ref
      .watch(sparksProvider)
      .where((spark) => spark.isLaterToday)
      .toList();
});

final joinedSparksProvider = Provider<List<Spark>>((ref) {
  final joinedIds = ref.watch(joinedSparkIdsProvider);
  final all = ref.watch(allSparksProvider);
  return all.where((spark) => joinedIds.contains(spark.id)).toList();
});

final myCreatedSparksProvider = Provider<List<Spark>>((ref) {
  return ref.watch(createdSparksProvider);
});

final myActiveCreatedSparksProvider = Provider<List<Spark>>((ref) {
  return ref
      .watch(createdSparksProvider)
      .where((s) => s.startsInMinutes > 0 && s.startsInMinutes <= 24 * 60)
      .toList();
});

final sparkApiRepositoryProvider = Provider<SparkApiRepository>((ref) {
  return SparkApiRepository(dio: ref.watch(dioProvider));
});

final planParseApiRepositoryProvider = Provider<PlanParseApiRepository>((ref) {
  return PlanParseApiRepository(dio: ref.watch(dioProvider));
});

final sparkDataControllerProvider = Provider<SparkDataController>((ref) {
  return SparkDataController(ref);
});

/// Holds a sparkId received via deep link — consumed by RootShell to open the detail screen.
final pendingDeepLinkSparkIdProvider = StateProvider<String?>((ref) => null);

class SparkDataController {
  SparkDataController(this.ref);

  final Ref ref;
  static const int _nearbyPageSize = 10;
  static const int _invitePageSize = 20;

  Future<void> refreshNearby({double? radiusKm}) async {
    ref.read(sparksLoadingProvider.notifier).state = true;
    ref.read(sparksErrorProvider.notifier).state = null;
    ref.read(nearbyPageProvider.notifier).state = 0;
    ref.read(nearbyHasMoreProvider.notifier).state = false;
    try {
      final location = ref.read(selectedLocationProvider);
      final (lat, lng) = _coordsFor(location);
      final radius = radiusKm ?? ref.read(selectedRadiusProvider).toDouble();
      final page = await ref
          .read(sparkApiRepositoryProvider)
          .fetchNearby(
            lat: lat,
            lng: lng,
            radiusKm: radius,
            page: 0,
            size: _nearbyPageSize,
          );
      ref.read(remoteSparksProvider.notifier).state = page.items;
      ref.read(nearbyHasMoreProvider.notifier).state = page.hasMore;
      ref.read(nearbyPageProvider.notifier).state = page.page;
      ref
          .read(analyticsServiceProvider)
          .track(
            'nearby_refresh',
            properties: {
              'location': location,
              'radius_km': radius,
              'count': page.items.length,
            },
          );
    } catch (e) {
      final message = _readableSparkFetchError(e);
      ref.read(sparksErrorProvider.notifier).state = message;
    } finally {
      ref.read(sparksLoadingProvider.notifier).state = false;
    }
  }

  Future<void> fetchNextNearbyPage({double? radiusKm}) async {
    if (ref.read(sparksLoadingMoreProvider)) return;
    if (!ref.read(nearbyHasMoreProvider)) return;
    ref.read(sparksLoadingMoreProvider.notifier).state = true;
    try {
      final location = ref.read(selectedLocationProvider);
      final (lat, lng) = _coordsFor(location);
      final radius = radiusKm ?? ref.read(selectedRadiusProvider).toDouble();
      final nextPage = ref.read(nearbyPageProvider) + 1;
      final page = await ref
          .read(sparkApiRepositoryProvider)
          .fetchNearby(
            lat: lat,
            lng: lng,
            radiusKm: radius,
            page: nextPage,
            size: _nearbyPageSize,
          );
      ref.read(remoteSparksProvider.notifier).state = [
        ...ref.read(remoteSparksProvider),
        ...page.items,
      ];
      ref.read(nearbyPageProvider.notifier).state = page.page;
      ref.read(nearbyHasMoreProvider.notifier).state = page.hasMore;
      ref
          .read(analyticsServiceProvider)
          .track(
            'nearby_next_page',
            properties: {'page': page.page, 'items': page.items.length},
          );
    } catch (e) {
      final message = _readableSparkFetchError(e);
      ref.read(sparksErrorProvider.notifier).state = message;
    } finally {
      ref.read(sparksLoadingMoreProvider.notifier).state = false;
    }
  }

  Future<void> refreshInvites() async {
    ref.read(sparkInvitesLoadingProvider.notifier).state = true;
    ref.read(sparkInvitesErrorProvider.notifier).state = null;
    ref.read(invitePageProvider.notifier).state = 0;
    ref.read(inviteHasMoreProvider.notifier).state = false;
    try {
      final page = await ref
          .read(sparkApiRepositoryProvider)
          .fetchInvites(page: 0, size: _invitePageSize);
      ref.read(sparkInvitesProvider.notifier).state = page.items;
      ref.read(inviteHasMoreProvider.notifier).state = page.hasMore;
      ref.read(invitePageProvider.notifier).state = page.page;
    } catch (e) {
      ref.read(sparkInvitesErrorProvider.notifier).state = '$e';
    } finally {
      ref.read(sparkInvitesLoadingProvider.notifier).state = false;
    }
  }

  Future<void> fetchNextInvitePage() async {
    if (ref.read(sparkInvitesLoadingMoreProvider)) return;
    if (!ref.read(inviteHasMoreProvider)) return;
    ref.read(sparkInvitesLoadingMoreProvider.notifier).state = true;
    try {
      final nextPage = ref.read(invitePageProvider) + 1;
      final page = await ref
          .read(sparkApiRepositoryProvider)
          .fetchInvites(page: nextPage, size: _invitePageSize);
      ref.read(sparkInvitesProvider.notifier).state = [
        ...ref.read(sparkInvitesProvider),
        ...page.items,
      ];
      ref.read(invitePageProvider.notifier).state = page.page;
      ref.read(inviteHasMoreProvider.notifier).state = page.hasMore;
    } catch (e) {
      ref.read(sparkInvitesErrorProvider.notifier).state = '$e';
    } finally {
      ref.read(sparkInvitesLoadingMoreProvider.notifier).state = false;
    }
  }

  Future<void> respondToInvite({
    required SparkInvite invite,
    required SparkInviteStatus status,
  }) async {
    final previous = ref.read(sparkInvitesProvider);
    ref.read(sparkInvitesProvider.notifier).state =
        previous
            .map(
              (item) =>
                  item.inviteId == invite.inviteId
                      ? item.copyWith(status: status, actedAt: DateTime.now())
                      : item,
            )
            .toList();
    try {
      final confirmed = await ref
          .read(sparkApiRepositoryProvider)
          .respondToInvite(
            sparkId: invite.sparkId,
            inviteId: invite.inviteId,
            status: status,
          );
      ref.read(sparkInvitesProvider.notifier).state =
          ref
              .read(sparkInvitesProvider)
              .map(
                (item) =>
                    item.inviteId == invite.inviteId
                        ? item.copyWith(
                          status: confirmed,
                          actedAt: DateTime.now(),
                        )
                        : item,
              )
              .toList();
      if (confirmed == SparkInviteStatus.inStatus) {
        final joined = {...ref.read(joinedSparkIdsProvider)}
          ..add(invite.sparkId);
        ref.read(joinedSparkIdsProvider.notifier).state = joined;
        unawaited(refreshNearby());
      }
    } catch (e) {
      ref.read(sparkInvitesProvider.notifier).state = previous;
      ref.read(sparkInvitesErrorProvider.notifier).state = '$e';
      rethrow;
    }
  }

  Future<Spark> createSpark({
    required SparkCategory category,
    required String title,
    required String? note,
    required String locationName,
    required DateTime startsAt,
    required int maxSpots,
    SparkVisibility visibility = SparkVisibility.publicSpark,
    List<String> circleIds = const [],
    List<String> inviteUserIds = const [],
    String? recurrenceType,
    int? recurrenceDayOfWeek,
    String? recurrenceTime,
    DateTime? recurrenceEndDate,
  }) async {
    if (visibility == SparkVisibility.publicSpark &&
        (circleIds.isNotEmpty || inviteUserIds.isNotEmpty)) {
      throw Exception(
        'Public sparks cannot have specific circles or invitees. Change visibility to "Circle" or "Invite" first.',
      );
    }
    final myActive = ref.read(myActiveCreatedSparksProvider);
    if (myActive.length >= 5) {
      throw Exception(
        'You already have 5 active sparks. Please close one before creating another.',
      );
    }
    final location = ref.read(selectedLocationProvider);
    final (lat, lng) = _coordsFor(
      locationName == 'Nearby' ? location : locationName,
    );
    final created = await ref
        .read(sparkApiRepositoryProvider)
        .createSpark(
          category: category,
          title: title,
          note: note,
          locationName: locationName == 'Nearby' ? location : locationName,
          latitude: lat,
          longitude: lng,
          startsAt: startsAt,
          maxSpots: maxSpots,
          visibility: visibility,
          circleIds: circleIds,
          inviteUserIds: inviteUserIds,
          recurrenceType: recurrenceType,
          recurrenceDayOfWeek: recurrenceDayOfWeek,
          recurrenceTime: recurrenceTime,
          recurrenceEndDate: recurrenceEndDate,
        );
    ref.read(createdSparksProvider.notifier).state = [
      created,
      ...ref.read(createdSparksProvider),
    ];
    ref
        .read(analyticsServiceProvider)
        .track(
          'spark_created',
          properties: {
            'spark_id': created.id,
            'category': created.category.name,
            'spots': created.maxSpots,
            'recurring': recurrenceType ?? 'none',
          },
        );
    unawaited(refreshNearby());
    return created;
  }

  Future<Spark> updateSpark({
    required String sparkId,
    required SparkCategory category,
    required String title,
    required String? note,
    required String locationName,
    required DateTime startsAt,
    required int maxSpots,
    SparkVisibility visibility = SparkVisibility.publicSpark,
    List<String> circleIds = const [],
    List<String> inviteUserIds = const [],
    String? recurrenceType,
    int? recurrenceDayOfWeek,
    String? recurrenceTime,
    DateTime? recurrenceEndDate,
  }) async {
    final location = ref.read(selectedLocationProvider);
    final (lat, lng) = _coordsFor(
      locationName == 'Nearby' ? location : locationName,
    );
    final updated = await ref
        .read(sparkApiRepositoryProvider)
        .updateSpark(
          sparkId: sparkId,
          category: category,
          title: title,
          note: note,
          locationName: locationName == 'Nearby' ? location : locationName,
          latitude: lat,
          longitude: lng,
          startsAt: startsAt,
          maxSpots: maxSpots,
          visibility: visibility,
          circleIds: circleIds,
          inviteUserIds: inviteUserIds,
          recurrenceType: recurrenceType,
          recurrenceDayOfWeek: recurrenceDayOfWeek,
          recurrenceTime: recurrenceTime,
          recurrenceEndDate: recurrenceEndDate,
        );
    _mergeSpark(updated);
    ref.read(createdSparksProvider.notifier).state = [
      for (final spark in ref.read(createdSparksProvider))
        if (spark.id == updated.id) updated else spark,
    ];
    unawaited(refreshNearby());
    return updated;
  }

  Future<void> joinSpark(String sparkId) async {
    Spark? spark;
    for (final item in ref.read(allSparksProvider)) {
      if (item.id == sparkId) {
        spark = item;
        break;
      }
    }
    final user = ref.read(currentUserIdProvider);
    if (spark != null && spark.createdBy == user) {
      throw Exception('You cannot join your own spark.');
    }
    final joined = {...ref.read(joinedSparkIdsProvider)};
    joined.add(sparkId);
    ref.read(joinedSparkIdsProvider.notifier).state = joined;
    _applyOptimisticJoin(
      sparkId: sparkId,
      participantInitial: ref.read(currentUserInitialsProvider),
    );
    try {
      final updated = await ref
          .read(sparkApiRepositoryProvider)
          .joinSpark(sparkId: sparkId);
      _mergeSpark(updated);
      ref
          .read(analyticsServiceProvider)
          .track('spark_joined', properties: {'spark_id': sparkId});
      unawaited(refreshNearby());
    } catch (_) {
      // Optimistic UI kept for UX; backend retry can happen later.
    }
  }

  Future<void> fetchSparkDetail(String sparkId) async {
    try {
      final updated = await ref
          .read(sparkApiRepositoryProvider)
          .fetchSparkDetail(sparkId);
      _mergeSpark(updated);
    } catch (_) {}
  }

  Future<void> cancelSpark(String sparkId) async {
    // Remove from created list
    ref.read(createdSparksProvider.notifier).state =
        ref.read(createdSparksProvider).where((s) => s.id != sparkId).toList();
    // Remove from remote list too
    ref.read(remoteSparksProvider.notifier).state =
        ref.read(remoteSparksProvider).where((s) => s.id != sparkId).toList();
    // Remove any joined state for this spark
    final joined = {...ref.read(joinedSparkIdsProvider)}..remove(sparkId);
    ref.read(joinedSparkIdsProvider.notifier).state = joined;
    ref
        .read(analyticsServiceProvider)
        .track('spark_cancelled', properties: {'spark_id': sparkId});
    try {
      await ref.read(sparkApiRepositoryProvider).cancelSpark(sparkId: sparkId);
      unawaited(refreshNearby());
    } catch (_) {}
  }

  Future<void> leaveSpark(String sparkId) async {
    final joined = {...ref.read(joinedSparkIdsProvider)};
    joined.remove(sparkId);
    ref.read(joinedSparkIdsProvider.notifier).state = joined;
    _applyOptimisticLeave(
      sparkId: sparkId,
      participantInitial: ref.read(currentUserInitialsProvider),
    );
    try {
      final updated = await ref
          .read(sparkApiRepositoryProvider)
          .leaveSpark(sparkId: sparkId);
      _mergeSpark(updated);
      ref
          .read(analyticsServiceProvider)
          .track('spark_left', properties: {'spark_id': sparkId});
      unawaited(refreshNearby());
    } catch (_) {
      // Optimistic UI kept for UX.
    }
  }

  (double, double) _coordsFor(String location) {
    final lower = location.toLowerCase();
    if (lower.contains('koramangala')) return (12.9352, 77.6245);
    if (lower.contains('indiranagar')) return (12.9784, 77.6408);
    if (lower.contains('whitefield')) return (12.9698, 77.7499);
    if (lower.contains('electronic')) return (12.8456, 77.6603);
    if (lower.contains('hsr')) return (12.9116, 77.6474);
    return (12.9716, 77.5946);
  }

  void _mergeSpark(Spark updated) {
    _updateSparkInLists(sparkId: updated.id, transform: (_) => updated);
  }

  String _readableSparkFetchError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return 'Session expired. Please login again.';
      }
      if (status != null) {
        return 'Nearby fetch failed (HTTP $status)';
      }
      return error.message ?? 'Network request failed';
    }
    return error.toString();
  }

  void _applyOptimisticJoin({
    required String sparkId,
    required String participantInitial,
  }) {
    _updateSparkInLists(
      sparkId: sparkId,
      transform: (spark) {
        final participants = [...spark.participants];
        if (!participants.contains(participantInitial)) {
          participants.add(participantInitial);
        }
        final spotsLeft = spark.spotsLeft > 0 ? spark.spotsLeft - 1 : 0;
        return Spark(
          id: spark.id,
          category: spark.category,
          title: spark.title,
          startsInMinutes: spark.startsInMinutes,
          timeLabel: spark.timeLabel,
          distanceKm: spark.distanceKm,
          distanceLabel: spark.distanceLabel,
          spotsLeft: spotsLeft,
          maxSpots: spark.maxSpots,
          location: spark.location,
          createdBy: spark.createdBy,
          participants: participants,
          hostPhoneNumber: spark.hostPhoneNumber,
          note: spark.note,
        );
      },
    );
  }

  void _applyOptimisticLeave({
    required String sparkId,
    required String participantInitial,
  }) {
    _updateSparkInLists(
      sparkId: sparkId,
      transform: (spark) {
        final participants = [...spark.participants]
          ..remove(participantInitial);
        final spotsLeft =
            spark.spotsLeft < spark.maxSpots
                ? spark.spotsLeft + 1
                : spark.maxSpots;
        return Spark(
          id: spark.id,
          category: spark.category,
          title: spark.title,
          startsInMinutes: spark.startsInMinutes,
          timeLabel: spark.timeLabel,
          distanceKm: spark.distanceKm,
          distanceLabel: spark.distanceLabel,
          spotsLeft: spotsLeft,
          maxSpots: spark.maxSpots,
          location: spark.location,
          createdBy: spark.createdBy,
          participants: participants,
          hostPhoneNumber: spark.hostPhoneNumber,
          note: spark.note,
        );
      },
    );
  }

  void _updateSparkInLists({
    required String sparkId,
    required Spark Function(Spark spark) transform,
  }) {
    List<Spark> mapList(List<Spark> source) {
      return source.map((spark) {
        if (spark.id != sparkId) return spark;
        return transform(spark);
      }).toList();
    }

    ref.read(remoteSparksProvider.notifier).state = mapList(
      ref.read(remoteSparksProvider),
    );
    ref.read(createdSparksProvider.notifier).state = mapList(
      ref.read(createdSparksProvider),
    );
  }
}
