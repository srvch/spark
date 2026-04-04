import 'package:flutter/material.dart';

enum SparkCategory {
  sports('Sports', Icons.directions_run_rounded),
  study('Study', Icons.auto_stories_rounded),
  ride('Ride', Icons.drive_eta_rounded),
  events('Events', Icons.confirmation_number_outlined),
  hangout('Hangout', Icons.coffee_outlined);

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

enum SparkVisibility {
  publicSpark,
  circle,
  invite,
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
    this.visibility = SparkVisibility.publicSpark,
    this.hostPhoneNumber,
    this.hideHostPhoneNumber = false,
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
  final SparkVisibility visibility;
  final String? hostPhoneNumber;
  final bool hideHostPhoneNumber;
  final String? note;

  int get joinedCount => participants.length;

  bool get isHappeningSoon => startsInMinutes <= 30;

  bool get isLaterToday => startsInMinutes > 30;
}
