import 'package:flutter/material.dart';

enum SparkCategory {
  sports('Sports', Icons.sports_soccer),
  study('Study', Icons.menu_book_outlined),
  ride('Ride', Icons.directions_car_filled_outlined),
  events('Events', Icons.event_outlined),
  hangout('Hangout', Icons.groups_2_outlined);

  const SparkCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  Color get accentColor {
    switch (this) {
      case SparkCategory.sports:
        return const Color(0xFF16A34A);
      case SparkCategory.study:
        return const Color(0xFF7C3AED);
      case SparkCategory.ride:
        return const Color(0xFF2563EB);
      case SparkCategory.events:
        return const Color(0xFFEA580C);
      case SparkCategory.hangout:
        return const Color(0xFF0EA5E9);
    }
  }
}

enum SparkSort {
  nearest('Nearest'),
  startingSoon('Starting soon'),
  mostJoined('Most joined');

  const SparkSort(this.label);
  final String label;
}

class Spark {
  const Spark({
    required this.id,
    required this.category,
    required this.title,
    required this.startsInMinutes,
    required this.timeLabel,
    required this.distanceKm,
    required this.distanceLabel,
    required this.spotsLeft,
    required this.maxSpots,
    required this.location,
    required this.createdBy,
    required this.participants,
    this.hostPhoneNumber,
    this.note,
  });

  final String id;
  final SparkCategory category;
  final String title;
  final int startsInMinutes;
  final String timeLabel;
  final double distanceKm;
  final String distanceLabel;
  final int spotsLeft;
  final int maxSpots;
  final String location;
  final String createdBy;
  final List<String> participants;
  final String? hostPhoneNumber;
  final String? note;

  int get joinedCount => participants.length;

  bool get isHappeningSoon => startsInMinutes <= 30;

  bool get isLaterToday => startsInMinutes > 30;
}
