class PillProgress {
  final String id;
  final String userId;
  final String pillId;
  final int currentScreen;
  final int? selfAssessmentScore;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  PillProgress({
    required this.id,
    required this.userId,
    required this.pillId,
    required this.currentScreen,
    this.selfAssessmentScore,
    required this.isCompleted,
    this.completedAt,
    this.updatedAt,
  });

  factory PillProgress.fromJson(Map<String, dynamic> json) {
    return PillProgress(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      pillId: json['pill_id'] ?? '',
      currentScreen: json['current_screen'] ?? 1,
      selfAssessmentScore: json['self_assessment_score'],
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pill_id': pillId,
      'current_screen': currentScreen,
      'self_assessment_score': selfAssessmentScore,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
