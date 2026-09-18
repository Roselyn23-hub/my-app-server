class AppUser {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final String role; // 'admin', 'faculty', 'staff'
  final String department;

  AppUser({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    this.department = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'fullName': fullName,
      'role': role,
      'department': department,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      fullName: map['fullName'] as String,
      role: map['role'] as String,
      department: map['department'] as String? ?? '',
    );
  }
}
