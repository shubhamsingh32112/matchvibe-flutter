import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../models/moments_models.dart';
import '../services/moments_api_service.dart';

class MomentShareService {
  MomentShareService({MomentsApiService? api}) : _api = api ?? MomentsApiService();

  final MomentsApiService _api;

  Future<void> shareMoment(String momentId) async {
    final info = await _api.fetchShareInfo(momentId);
    final storeUrl = _storeUrlForPlatform(info);
    final storeLabel = Platform.isIOS ? 'the App Store' : 'Google Play';
    final message = StringBuffer()
      ..writeln(info.title)
      ..writeln();
    if (info.deepLink.isNotEmpty) {
      message.writeln('Open in MatchVibe: ${info.deepLink}');
    }
    if (storeUrl.isNotEmpty) {
      message.write('Get MatchVibe on $storeLabel: $storeUrl');
    }
    await Share.share(message.toString());
  }

  String _storeUrlForPlatform(MomentShareInfo info) {
    if (Platform.isIOS) {
      if (info.appStoreUrl.isNotEmpty) return info.appStoreUrl;
      return AppConstants.appStoreUrl;
    }
    if (info.playStoreUrl.isNotEmpty) return info.playStoreUrl;
    return AppConstants.playStoreUrl;
  }
}
