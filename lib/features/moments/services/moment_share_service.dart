import 'package:share_plus/share_plus.dart';

import '../models/moments_models.dart';
import '../services/moments_api_service.dart';

class MomentShareService {
  MomentShareService({MomentsApiService? api}) : _api = api ?? MomentsApiService();

  final MomentsApiService _api;

  Future<void> shareMoment(String momentId) async {
    final info = await _api.fetchShareInfo(momentId);
    final message = StringBuffer()
      ..writeln(info.title)
      ..writeln()
      ..write('Watch on MatchVibe: ${info.shareUrl}');
    await Share.share(message.toString());
  }
}
