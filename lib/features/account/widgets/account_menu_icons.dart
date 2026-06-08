import 'package:flutter/material.dart';

import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/decorative_asset_image.dart';
import '../constants/account_menu_assets.dart';

class AccountSettingsIcon extends StatelessWidget {
  final double size;

  const AccountSettingsIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return DecorativeAssetImage(
      assetPath: AccountMenuAssets.accountSettings,
      width: size,
      height: size,
      fallbackIcon: Icons.settings_outlined,
      fallbackIconSize: size,
      fallbackIconColor: AppBrandGradients.accountMenuIconTint,
    );
  }
}

class ReloadProfileIcon extends StatelessWidget {
  final double size;

  const ReloadProfileIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return DecorativeAssetImage(
      assetPath: AccountMenuAssets.reloadProfile,
      width: size,
      height: size,
      fallbackIcon: Icons.refresh,
      fallbackIconSize: size,
      fallbackIconColor: AppBrandGradients.accountMenuIconTint,
    );
  }
}

class LogoutIcon extends StatelessWidget {
  final double size;

  const LogoutIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return DecorativeAssetImage(
      assetPath: AccountMenuAssets.logout,
      width: size,
      height: size,
      fallbackIcon: Icons.logout,
      fallbackIconSize: size,
      fallbackIconColor: Theme.of(context).colorScheme.error,
    );
  }
}
