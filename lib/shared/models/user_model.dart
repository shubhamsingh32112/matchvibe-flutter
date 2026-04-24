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
  final String? role; // 'user', 'creator', 'admin', or 'agent' (app users are never 'agent')
  /// True when user signed up with an agent referral and is waiting for approval.
  final bool creatorApplicationPending;
  final bool creatorApplicationRejected;
  final String? creatorApplicationRejectionReason;
  // Creator-specific fields (only populated when role is 'creator')
  final String? name; // Creator name
  final String? about; // Creator about/bio
  final int? age; // Creator age
  final String? referralCode; // Unique code: legacy 6-char (JO4832) or 8-char (JOE48392)
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Incremented when admin updates profile; app shows a one-time toast when this increases.
  final int profileRevision;
  final String? onboardingStage;

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
    this.creatorApplicationPending = false,
    this.creatorApplicationRejected = false,
    this.creatorApplicationRejectionReason,
    this.name,
    this.about,
    this.age,
    this.referralCode,
    this.createdAt,
    this.updatedAt,
    this.profileRevision = 0,
    this.onboardingStage,
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
      creatorApplicationPending: json['creatorApplicationPending'] == true,
      creatorApplicationRejected: json['creatorApplicationRejected'] == true,
      creatorApplicationRejectionReason:
          json['creatorApplicationRejectionReason'] as String?,
      name: json['name'] as String?,
      about: json['about'] as String?,
      age: json['age'] != null ? json['age'] as int? : null,
      referralCode: json['referralCode'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      profileRevision: (json['profileRevision'] as num?)?.toInt() ?? 0,
      onboardingStage: (json['onboarding'] as Map<String, dynamic>?)?['stage']
          as String?,
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
      'creatorApplicationPending': creatorApplicationPending,
      'creatorApplicationRejected': creatorApplicationRejected,
      'creatorApplicationRejectionReason': creatorApplicationRejectionReason,
      'name': name,
      'about': about,
      'age': age,
      'referralCode': referralCode,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'profileRevision': profileRevision,
      'onboarding': onboardingStage != null ? {'stage': onboardingStage} : null,
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
    bool? creatorApplicationPending,
    bool? creatorApplicationRejected,
    String? creatorApplicationRejectionReason,
    String? name,
    String? about,
    int? age,
    String? referralCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? profileRevision,
    String? onboardingStage,
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
      creatorApplicationPending:
          creatorApplicationPending ?? this.creatorApplicationPending,
      creatorApplicationRejected:
          creatorApplicationRejected ?? this.creatorApplicationRejected,
      creatorApplicationRejectionReason: creatorApplicationRejectionReason ??
          this.creatorApplicationRejectionReason,
      name: name ?? this.name,
      about: about ?? this.about,
      age: age ?? this.age,
      referralCode: referralCode ?? this.referralCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileRevision: profileRevision ?? this.profileRevision,
      onboardingStage: onboardingStage ?? this.onboardingStage,
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
        creatorApplicationPending,
        creatorApplicationRejected,
        creatorApplicationRejectionReason,
        name,
        about,
        age,
        referralCode,
        createdAt,
        updatedAt,
        profileRevision,
        onboardingStage,
      ];
}
