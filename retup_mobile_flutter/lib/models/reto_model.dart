class Reto {
  final String id;
  final String companyId;
  final String title;
  final String? description;
  final String? category;
  final String? difficulty;
  final int? totalPills;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Reto({
    required this.id,
    required this.companyId,
    required this.title,
    this.description,
    this.category,
    this.difficulty,
    this.totalPills,
    this.createdAt,
    this.updatedAt,
  });

  factory Reto.fromJson(Map<String, dynamic> json) {
    return Reto(
      id: json['id'] ?? '',
      companyId: json['company_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      category: json['category'],
      difficulty: json['difficulty'],
      totalPills: json['total_pills'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'title': title,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'total_pills': totalPills,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
