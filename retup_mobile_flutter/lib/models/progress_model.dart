class UserProgress {
  final String id;
  final String userId;
  final int xp;
  final int streak;
  final DateTime? lastActivityDate;

  UserProgress({
    required this.id,
    required this.userId,
    required this.xp,
    required this.streak,
    this.lastActivityDate,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      xp: json['xp'] ?? 0,
      streak: json['streak'] ?? 0,
      lastActivityDate: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'xp': xp,
      'streak': streak,
      'created_at': lastActivityDate?.toIso8601String(),
    };
  }
}
