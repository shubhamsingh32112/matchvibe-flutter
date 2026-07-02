import 'package:share_plus/share_plus.dart';

import '../models/moments_models.dart';
import '../services/moments_api_service.dart';

class MomentShareService {
  MomentShareService({MomentsApiService? api}) : _api = api ?? MomentsApiService();

  final MomentsApiService _api;

  static const _defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.matchvibe.app&pcampaignid=web_share';

  Future<void> shareMoment(String momentId) async {
    final info = await _api.fetchShareInfo(momentId);
    final storeUrl =
        info.playStoreUrl.isNotEmpty ? info.playStoreUrl : _defaultPlayStoreUrl;
    final message = StringBuffer()
      ..writeln(info.title)
      ..writeln();
    if (info.deepLink.isNotEmpty) {
      message.writeln('Open in MatchVibe: ${info.deepLink}');
    }
    message.write('Get MatchVibe on Google Play: $storeUrl');
    await Share.share(message.toString());
  }
}
