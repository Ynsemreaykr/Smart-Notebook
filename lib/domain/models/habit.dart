class Habit {
  final String id;
  final String name;
  final String type; // 'star' or 'timer'
  final DateTime createdAt;
  final Map<String, int> starRatings; // Key format: "yyyy-MM-dd", Value: 1..5
  final Map<String, int> trackedTime; // Key format: "yyyy-MM-dd", Value: seconds
  final String? linkedNoteId;
  final int? targetDays; // Toplam hedef gün sayısı
  final String? startTime; // "HH:mm" e.g., "09:00"
  final String? endTime; // "HH:mm" e.g., "10:30"

  Habit({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.starRatings = const {},
    this.trackedTime = const {},
    this.linkedNoteId,
    this.targetDays,
    this.startTime,
    this.endTime,
  });

  // Determines if the habit is schedule-based or free
  bool get isScheduled => startTime != null && endTime != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'starRatings': starRatings,
      'trackedTime': trackedTime,
      'linkedNoteId': linkedNoteId,
      'targetDays': targetDays,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory Habit.fromJson(Map<dynamic, dynamic> json) {
    // Legacy support: if history is present, it was a star habit.
    final rawHistory = json['history'] ?? {};
    final Map<String, int> parsedStarRatings = {};
    rawHistory.forEach((key, val) {
      if (val is bool) {
        parsedStarRatings[key as String] = val ? 5 : 0;
      } else if (val is int) {
        parsedStarRatings[key as String] = val;
      }
    });

    final rawStarRatings = json['starRatings'] ?? {};
    final Map<String, int> starRatingsMap = {};
    rawStarRatings.forEach((k, v) {
      starRatingsMap[k as String] = v as int;
    });

    if (parsedStarRatings.isNotEmpty && starRatingsMap.isEmpty) {
      starRatingsMap.addAll(parsedStarRatings);
    }

    final rawTrackedTime = json['trackedTime'] ?? {};
    final Map<String, int> trackedTimeMap = {};
    rawTrackedTime.forEach((k, v) {
      trackedTimeMap[k as String] = v as int;
    });

    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'star',
      createdAt: DateTime.parse(json['createdAt'] as String),
      starRatings: starRatingsMap,
      trackedTime: trackedTimeMap,
      linkedNoteId: json['linkedNoteId'] as String?,
      targetDays: json['targetDays'] as int?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
    );
  }

  Habit copyWith({
    String? id,
    String? name,
    String? type,
    DateTime? createdAt,
    Map<String, int>? starRatings,
    Map<String, int>? trackedTime,
    String? linkedNoteId,
    int? targetDays,
    String? startTime,
    String? endTime,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      starRatings: starRatings ?? this.starRatings,
      trackedTime: trackedTime ?? this.trackedTime,
      linkedNoteId: linkedNoteId ?? this.linkedNoteId,
      targetDays: targetDays ?? this.targetDays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
