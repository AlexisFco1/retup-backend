class User {
  final String id;
  final String email;
  final String fullName;
  final int xp;
  final int level;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.xp,
    this.level = 1,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '', // ← Convertir a String
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'xp': xp,
      'level': level,
    };
  }
}
