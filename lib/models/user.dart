class User {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String role;
  final bool monthlyBilling;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.monthlyBilling,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      monthlyBilling: json['monthlyBilling'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role,
      'monthlyBilling': monthlyBilling,
    };
  }
}
