class AppUpdateModel {
  final String id;
  final String version;
  final String title;
  final List<String> points;
  final String updateUrl;
  final DateTime? publishedAt;

  const AppUpdateModel({
    required this.id,
    required this.version,
    required this.title,
    required this.points,
    required this.updateUrl,
    this.publishedAt,
  });

  factory AppUpdateModel.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final parsedPoints = rawPoints is List
        ? rawPoints.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return AppUpdateModel(
      id: (json['id'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      points: parsedPoints,
      updateUrl: (json['updateUrl'] ?? '').toString(),
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : null,
    );
  }
}
