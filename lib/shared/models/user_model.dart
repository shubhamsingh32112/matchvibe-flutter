import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String? email;
  final String? phone;
  final String? gender; // 'male', 'female', or 'other'
  final String? username;
  final String? avatar; // e.g., 'a1.png' or 'fa1.png'
  final List<String>? categories;
  final int usernameChangeCount;
  final int coins;
  final bool welcomeBonusClaimed;
  final int freeTextUsed; // Count of free text messages used (first 3 are free)
  final String? role; // 'user', 'creator', or 'admin'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    this.email,
    this.phone,
    this.gender,
    this.username,
    this.avatar,
    this.categories,
    this.usernameChangeCount = 0,
    required this.coins,
    this.welcomeBonusClaimed = false,
    this.freeTextUsed = 0,
    this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      username: json['username'] as String?,
      avatar: json['avatar'] as String?,
      categories: json['categories'] != null
          ? List<String>.from(json['categories'] as List)
          : null,
      usernameChangeCount: json['usernameChangeCount'] as int? ?? 0,
      coins: json['coins'] as int? ?? 0,
      welcomeBonusClaimed: json['welcomeBonusClaimed'] as bool? ?? false,
      freeTextUsed: json['freeTextUsed'] as int? ?? 0,
      role: json['role'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'gender': gender,
      'username': username,
      'avatar': avatar,
      'categories': categories,
      'usernameChangeCount': usernameChangeCount,
      'coins': coins,
      'welcomeBonusClaimed': welcomeBonusClaimed,
      'freeTextUsed': freeTextUsed,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? gender,
    String? username,
    String? avatar,
    List<String>? categories,
    int? usernameChangeCount,
    int? coins,
    bool? welcomeBonusClaimed,
    int? freeTextUsed,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      categories: categories ?? this.categories,
      usernameChangeCount: usernameChangeCount ?? this.usernameChangeCount,
      coins: coins ?? this.coins,
      welcomeBonusClaimed: welcomeBonusClaimed ?? this.welcomeBonusClaimed,
      freeTextUsed: freeTextUsed ?? this.freeTextUsed,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        phone,
        gender,
        username,
        avatar,
        categories,
        usernameChangeCount,
        coins,
        welcomeBonusClaimed,
        freeTextUsed,
        role,
        createdAt,
        updatedAt,
      ];
}
