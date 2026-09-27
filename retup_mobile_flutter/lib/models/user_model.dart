class User {
  final String id;
  final String email;
  final String fullName;
  final String firstName;
  final String lastName1;
  final String lastName2;
  final int? age;
  final String? gender;
  final String? department;
  final int xp;
  final int level;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.firstName = '',
    this.lastName1 = '',
    this.lastName2 = '',
    this.age,
    this.gender,
    this.department,
    required this.xp,
    this.level = 1,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName1: json['last_name_1'] ?? '',
      lastName2: json['last_name_2'] ?? '',
      age: json['age'],
      gender: json['gender'],
      department: json['department'],
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'first_name': firstName,
      'last_name_1': lastName1,
      'last_name_2': lastName2,
      'age': age,
      'gender': gender,
      'department': department,
      'xp': xp,
      'level': level,
    };
  }
}
