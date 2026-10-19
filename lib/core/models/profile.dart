// lib/core/models/profile.dart

import 'user_role.dart';

class Profile {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final List<UserRole> roles;
  final bool isActive;
  final String? pushToken;
  final String? plainPassword;
  final String themePreference;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.roles,
    required this.isActive,
    this.pushToken,
    this.plainPassword,
    this.themePreference = 'light',
    required this.createdAt,
    required this.updatedAt,
  });

  UserRole get primaryRole {
    if (roles.isEmpty) return UserRole.customer;
    if (roles.contains(UserRole.admin)) return UserRole.admin;
    if (roles.contains(UserRole.manager)) return UserRole.manager;
    if (roles.contains(UserRole.salesHead)) return UserRole.salesHead;
    if (roles.contains(UserRole.serviceHead)) return UserRole.serviceHead;
    if (roles.contains(UserRole.installation)) return UserRole.installation;
    if (roles.contains(UserRole.sales)) return UserRole.sales;
    if (roles.contains(UserRole.purchase)) return UserRole.purchase;
    if (roles.contains(UserRole.factory)) return UserRole.factory;
    if (roles.contains(UserRole.boq)) return UserRole.boq;
    if (roles.contains(UserRole.technician)) return UserRole.technician;
    if (roles.contains(UserRole.crmStaff)) return UserRole.crmStaff;
    return roles.first;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    List<UserRole> parsedRoles = [];
    if (json['roles'] != null && json['roles'] is List) {
      parsedRoles = (json['roles'] as List)
          .map((r) => UserRole.fromString(r.toString()))
          .toList();
    } else if (json['role'] != null) {
      // Legacy support for single role
      parsedRoles = [UserRole.fromString(json['role'].toString())];
    } else {
      parsedRoles = [UserRole.customer];
    }

    return Profile(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      roles: parsedRoles,
      isActive: json['is_active'] as bool? ?? true,
      pushToken: json['push_token'] as String?,
      plainPassword: (json['plain_password'] ?? json['password']) as String?,
      themePreference: json['theme_preference'] as String? ?? 'light',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'roles': roles.map((r) => r.name).toList(),
    'is_active': isActive,
    'push_token': pushToken,
    if (plainPassword != null) ...{
      'plain_password': plainPassword,
      'password': plainPassword,
    },
    'theme_preference': themePreference,
  };

  Profile copyWith({
    String? fullName,
    String? phone,
    List<UserRole>? roles,
    bool? isActive,
    String? pushToken,
    String? plainPassword,
    String? themePreference,
  }) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      isActive: isActive ?? this.isActive,
      pushToken: pushToken ?? this.pushToken,
      plainPassword: plainPassword ?? this.plainPassword,
      themePreference: themePreference ?? this.themePreference,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Profile) return false;
    if (id != other.id ||
        fullName != other.fullName ||
        email != other.email ||
        phone != other.phone ||
        isActive != other.isActive ||
        themePreference != other.themePreference ||
        roles.length != other.roles.length) {
      return false;
    }
    for (int i = 0; i < roles.length; i++) {
      if (roles[i] != other.roles[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, fullName, email, phone, isActive, themePreference);
}

