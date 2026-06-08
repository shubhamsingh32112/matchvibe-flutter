import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/brand_app_chrome.dart';

class MomentsHeader {
  MomentsHeader._();

  static AppBar appBar(BuildContext context, WidgetRef ref) {
    return buildBrandAppBar(
      context,
      title: 'Moments ✨',
    );
  }
}
