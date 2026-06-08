import '../../../shared/models/creator_model.dart';

/// ISO 3166-1 alpha-2 and common country names → flag emoji.
const _countryFlagByKey = <String, String>{
  'in': '🇮🇳',
  'india': '🇮🇳',
  'us': '🇺🇸',
  'usa': '🇺🇸',
  'united states': '🇺🇸',
  'gb': '🇬🇧',
  'uk': '🇬🇧',
  'united kingdom': '🇬🇧',
  'ca': '🇨🇦',
  'canada': '🇨🇦',
  'au': '🇦🇺',
  'australia': '🇦🇺',
  'de': '🇩🇪',
  'germany': '🇩🇪',
  'fr': '🇫🇷',
  'france': '🇫🇷',
  'jp': '🇯🇵',
  'japan': '🇯🇵',
  'br': '🇧🇷',
  'brazil': '🇧🇷',
  'mx': '🇲🇽',
  'mexico': '🇲🇽',
  'ae': '🇦🇪',
  'uae': '🇦🇪',
  'sg': '🇸🇬',
  'singapore': '🇸🇬',
  'pk': '🇵🇰',
  'pakistan': '🇵🇰',
  'bd': '🇧🇩',
  'bangladesh': '🇧🇩',
  'np': '🇳🇵',
  'nepal': '🇳🇵',
  'lk': '🇱🇰',
  'sri lanka': '🇱🇰',
};

String creatorLocationFlagEmoji(String? location) {
  final trimmed = location?.trim();
  if (trimmed == null || trimmed.isEmpty) return '🇮🇳';
  final key = trimmed.toLowerCase();
  if (_countryFlagByKey.containsKey(key)) return _countryFlagByKey[key]!;
  for (final entry in _countryFlagByKey.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return '🌍';
}

String creatorDisplayCountry(CreatorModel creator) {
  final trimmed = creator.location?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  return 'India';
}
