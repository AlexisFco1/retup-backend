class Pildora {
  final String id;
  final String retoId;
  final int? pillNumber;
  final String title;
  final String? keySkill;
  final String? description;
  final int? durationMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Propiedades compatibles para mantener el código existente
  String get titulo => title;
  String get descripcion => description ?? '';
  String get contenido => description ?? '';

  Pildora({
    required this.id,
    required this.retoId,
    this.pillNumber,
    required this.title,
    this.keySkill,
    this.description,
    this.durationMinutes,
    this.createdAt,
    this.updatedAt,
  });

  factory Pildora.fromJson(Map<String, dynamic> json) {
    return Pildora(
      id: json['id'] ?? '',
      retoId: json['reto_id'] ?? '',
      pillNumber: json['pill_number'],
      title: json['title'] ?? '',
      keySkill: json['key_skill'],
      description: json['description'],
      durationMinutes: json['duration_minutes'],
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
      'reto_id': retoId,
      'pill_number': pillNumber,
      'title': title,
      'key_skill': keySkill,
      'description': description,
      'duration_minutes': durationMinutes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
