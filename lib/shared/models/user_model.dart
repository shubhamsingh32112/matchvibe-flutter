import 'package:equatable/equatable.dart';

import '../../core/images/image_asset_view.dart';

class UserModel extends Equatable {
  final String id;
  final String? email;
  final String? phone;
  final String? gender; // 'male', 'female', or 'other'
  final String? username;

  /// Cloudflare Images avatar payload (variants + blurhash + dims).
  /// Source of truth for all avatar rendering via [AppAvatar].
  /// Legacy preset / Firebase URL string fields were removed in Phase E.
  final AvatarAssetView? avatarAsset;
  final List<String>? categories;
  final int usernameChangeCount;
  final int coins;
  /// Promo-only intro call credits (server; not real wallet / IAP).
  final int introFreeCallCredits;
  /// Server-derived: show welcome-free call UI until first qualifying billed intro call.
  final bool welcomeFreeCallEligible;
  final int freeTextUsed; // Legacy; server uses ChatMessageQuota per creator
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
  final DateTime? onboardingWelcomeSeenAt;
  final DateTime? onboardingBonusSeenAt;
  final DateTime? onboardingPermissionSeenAt;
  final DateTime? onboardingCompletedAt;
  final DateTime? onboardingPermissionsIntroAcceptedAt;
  final DateTime? onboardingPermissionsLastCheckedAt;
  final String onboardingCameraMicStatus;
  final String onboardingNotificationStatus;

  const UserModel({
    required this.id,
    this.email,
    this.phone,
    this.gender,
    this.username,
    this.avatarAsset,
    this.categories,
    this.usernameChangeCount = 0,
    required this.coins,
    this.introFreeCallCredits = 0,
    this.welcomeFreeCallEligible = false,
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
    this.onboardingWelcomeSeenAt,
    this.onboardingBonusSeenAt,
    this.onboardingPermissionSeenAt,
    this.onboardingCompletedAt,
    this.onboardingPermissionsIntroAcceptedAt,
    this.onboardingPermissionsLastCheckedAt,
    this.onboardingCameraMicStatus = 'unknown',
    this.onboardingNotificationStatus = 'unknown',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final onboarding = json['onboarding'] as Map<String, dynamic>?;
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      username: json['username'] as String?,
      avatarAsset: AvatarAssetView.fromJson(
            json['avatarAsset'] as Map<String, dynamic>?,
          ) ??
          AvatarAssetView.fromJson(
            json['avatar'] as Map<String, dynamic>?,
          ),
      categories: json['categories'] != null
          ? List<String>.from(json['categories'] as List)
          : null,
      usernameChangeCount: json['usernameChangeCount'] as int? ?? 0,
      coins: json['coins'] as int? ?? 0,
      introFreeCallCredits: (json['introFreeCallCredits'] as num?)?.toInt() ?? 0,
      welcomeFreeCallEligible: json['welcomeFreeCallEligible'] == true,
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
      onboardingStage: onboarding?['stage'] as String?,
      onboardingWelcomeSeenAt: onboarding?['welcomeSeenAt'] != null
          ? DateTime.tryParse(onboarding!['welcomeSeenAt'] as String)
          : null,
      onboardingBonusSeenAt: onboarding?['bonusSeenAt'] != null
          ? DateTime.tryParse(onboarding!['bonusSeenAt'] as String)
          : null,
      onboardingPermissionSeenAt: onboarding?['permissionSeenAt'] != null
          ? DateTime.tryParse(onboarding!['permissionSeenAt'] as String)
          : null,
      onboardingCompletedAt: onboarding?['completedAt'] != null
          ? DateTime.tryParse(onboarding!['completedAt'] as String)
          : null,
      onboardingPermissionsIntroAcceptedAt:
          onboarding?['permissionsIntroAcceptedAt'] != null
          ? DateTime.tryParse(onboarding!['permissionsIntroAcceptedAt'] as String)
          : null,
      onboardingPermissionsLastCheckedAt:
          onboarding?['permissionsLastCheckedAt'] != null
          ? DateTime.tryParse(onboarding!['permissionsLastCheckedAt'] as String)
          : null,
      onboardingCameraMicStatus:
          (onboarding?['cameraMicStatus'] as String?) ?? 'unknown',
      onboardingNotificationStatus:
          (onboarding?['notificationStatus'] as String?) ?? 'unknown',
    );
  }

  /// Coins that can be admitted to start a call (wallet + unused intro credits).
  int get spendableCallCoins => coins + introFreeCallCredits;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'gender': gender,
      'username': username,
      if (avatarAsset != null) 'avatarAsset': {'imageId': avatarAsset!.imageId},
      'categories': categories,
      'usernameChangeCount': usernameChangeCount,
      'coins': coins,
      'introFreeCallCredits': introFreeCallCredits,
      'welcomeFreeCallEligible': welcomeFreeCallEligible,
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
      'onboarding': onboardingStage != null
          ? {
              'stage': onboardingStage,
              'welcomeSeenAt': onboardingWelcomeSeenAt?.toIso8601String(),
              'bonusSeenAt': onboardingBonusSeenAt?.toIso8601String(),
              'permissionSeenAt': onboardingPermissionSeenAt?.toIso8601String(),
              'completedAt': onboardingCompletedAt?.toIso8601String(),
              'permissionsIntroAcceptedAt':
                  onboardingPermissionsIntroAcceptedAt?.toIso8601String(),
              'permissionsLastCheckedAt':
                  onboardingPermissionsLastCheckedAt?.toIso8601String(),
              'cameraMicStatus': onboardingCameraMicStatus,
              'notificationStatus': onboardingNotificationStatus,
            }
          : null,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? gender,
    String? username,
    AvatarAssetView? avatarAsset,
    List<String>? categories,
    int? usernameChangeCount,
    int? coins,
    int? introFreeCallCredits,
    bool? welcomeFreeCallEligible,
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
    DateTime? onboardingWelcomeSeenAt,
    DateTime? onboardingBonusSeenAt,
    DateTime? onboardingPermissionSeenAt,
    DateTime? onboardingCompletedAt,
    DateTime? onboardingPermissionsIntroAcceptedAt,
    DateTime? onboardingPermissionsLastCheckedAt,
    String? onboardingCameraMicStatus,
    String? onboardingNotificationStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      username: username ?? this.username,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      categories: categories ?? this.categories,
      usernameChangeCount: usernameChangeCount ?? this.usernameChangeCount,
      coins: coins ?? this.coins,
      introFreeCallCredits:
          introFreeCallCredits ?? this.introFreeCallCredits,
      welcomeFreeCallEligible:
          welcomeFreeCallEligible ?? this.welcomeFreeCallEligible,
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
      onboardingWelcomeSeenAt:
          onboardingWelcomeSeenAt ?? this.onboardingWelcomeSeenAt,
      onboardingBonusSeenAt: onboardingBonusSeenAt ?? this.onboardingBonusSeenAt,
      onboardingPermissionSeenAt:
          onboardingPermissionSeenAt ?? this.onboardingPermissionSeenAt,
      onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
      onboardingPermissionsIntroAcceptedAt:
          onboardingPermissionsIntroAcceptedAt ??
          this.onboardingPermissionsIntroAcceptedAt,
      onboardingPermissionsLastCheckedAt:
          onboardingPermissionsLastCheckedAt ??
          this.onboardingPermissionsLastCheckedAt,
      onboardingCameraMicStatus:
          onboardingCameraMicStatus ?? this.onboardingCameraMicStatus,
      onboardingNotificationStatus:
          onboardingNotificationStatus ?? this.onboardingNotificationStatus,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        phone,
        gender,
        username,
        avatarAsset,
        categories,
        usernameChangeCount,
        coins,
        introFreeCallCredits,
        welcomeFreeCallEligible,
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
        onboardingWelcomeSeenAt,
        onboardingBonusSeenAt,
        onboardingPermissionSeenAt,
        onboardingCompletedAt,
        onboardingPermissionsIntroAcceptedAt,
        onboardingPermissionsLastCheckedAt,
        onboardingCameraMicStatus,
        onboardingNotificationStatus,
      ];
}
