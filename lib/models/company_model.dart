class Company {
  final String id;
  final String name;
  final String code; // Código único de 6 dígitos
  final String plan; // 'free', 'pro', 'enterprise'
  final DateTime createdAt;
  final List<User> users;

  Company({
    required this.id,
    required this.name,
    required this.code,
    required this.plan,
    required this.createdAt,
    required this.users,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'plan': plan,
        'createdAt': createdAt.toIso8601String(),
        'users': users.map((u) => u.toJson()).toList(),
      };

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        id: json['id'],
        name: json['name'],
        code: json['code'],
        plan: json['plan'],
        createdAt: DateTime.parse(json['createdAt']),
        users: (json['users'] as List).map((u) => User.fromJson(u)).toList(),
      );
}

class User {
  final String id;
  final String email;
  final String name;
  final String role; // 'super_admin', 'admin', 'operator', 'auditor'
  final String passwordHash; // En producción, usar hash real
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.passwordHash,
    required this.isActive,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'passwordHash': passwordHash,
        'isActive': isActive,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        email: json['email'],
        name: json['name'],
        role: json['role'],
        passwordHash: json['passwordHash'],
        isActive: json['isActive'],
      );
}
