class Seccion {
  final String id;
  final String pildoraId;
  final int screenNumber;
  final String screenName;
  final String screenType;
  final String screenContent;
  final String? sourceNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Seccion({
    required this.id,
    required this.pildoraId,
    required this.screenNumber,
    required this.screenName,
    required this.screenType,
    required this.screenContent,
    this.sourceNote,
    this.createdAt,
    this.updatedAt,
  });

  factory Seccion.fromJson(Map<String, dynamic> json) {
    return Seccion(
      id: json['id'] ?? '',
      pildoraId: json['pildora_id'] ?? '',
      screenNumber: json['screen_number'] ?? 1,
      screenName: json['screen_name'] ?? '',
      screenType: json['screen_type'] ?? '',
      screenContent: json['screen_content'] ?? '',
      sourceNote: json['source_note'],
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
      'pildora_id': pildoraId,
      'screen_number': screenNumber,
      'screen_name': screenName,
      'screen_type': screenType,
      'screen_content': screenContent,
      'source_note': sourceNote,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
