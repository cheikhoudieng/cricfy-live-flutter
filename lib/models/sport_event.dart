import 'package:intl/intl.dart';

enum MatchStatus { live, startingSoon, upcoming, ended }

class MatchFormat {
  final String title;
  final String quality;
  final String webLink;
  final String streamUrl;
  final String formatType; // 'dash', 'mpd', 'hls', 'mp4', 'auto'
  final String? mimeType;
  final Map<String, String>? headers;

  MatchFormat({
    required this.title,
    this.quality = 'HD 1080p',
    required this.webLink,
    required this.streamUrl,
    this.formatType = 'auto',
    this.mimeType,
    this.headers,
  });

  bool get isDash {
    final lower = (formatType + ' ' + streamUrl + ' ' + (mimeType ?? '')).toLowerCase();
    return lower.contains('dash') || lower.contains('.mpd') || lower.contains('dash+xml');
  }

  bool get isHls {
    final lower = (formatType + ' ' + streamUrl + ' ' + (mimeType ?? '')).toLowerCase();
    return lower.contains('hls') || lower.contains('.m3u8') || lower.contains('mpegurl');
  }

  factory MatchFormat.fromJson(Map<String, dynamic> json) {
    final rawFormat = json['format'] ?? json['type'] ?? '';
    final url = json['streamUrl'] ?? json['webLink'] ?? json['url'] ?? '';
    final mime = json['mimeType'] ?? json['mime'];

    String detectedType = rawFormat.toString().toLowerCase();
    if (detectedType.isEmpty || detectedType == 'auto') {
      final u = url.toString().toLowerCase();
      if (u.contains('.mpd') || u.contains('dash')) {
        detectedType = 'dash';
      } else if (u.contains('.m3u8') || u.contains('hls')) {
        detectedType = 'hls';
      } else {
        detectedType = 'auto';
      }
    }

    Map<String, String>? hdrs;
    if (json['headers'] is Map) {
      hdrs = (json['headers'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    return MatchFormat(
      title: json['title'] ?? 'Serveur Principal',
      quality: json['quality'] ?? (detectedType == 'dash' ? '1080p MPEG-DASH' : 'Full HD'),
      webLink: json['webLink'] ?? url,
      streamUrl: url,
      formatType: detectedType,
      mimeType: mime,
      headers: hdrs,
    );
  }
}

class SportEvent {
  final String id;
  final String title;
  final String slug;
  final String teamA;
  final String teamB;
  final String? teamAFlag;
  final String? teamBFlag;
  final String sportCategory;
  final String tournament;
  final DateTime startDate;
  final DateTime endDate;
  final List<MatchFormat> formats;

  SportEvent({
    required this.id,
    required this.title,
    required this.slug,
    required this.teamA,
    required this.teamB,
    this.teamAFlag,
    this.teamBFlag,
    required this.sportCategory,
    required this.tournament,
    required this.startDate,
    required this.endDate,
    required this.formats,
  });

  factory SportEvent.fromJson(Map<String, dynamic> json) {
    final info = json['eventInfo'] as Map<String, dynamic>? ?? {};

    DateTime parseUtc(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return DateTime.now();
      try {
        final format = DateFormat('yyyy/MM/dd HH:mm:ss Z');
        return format.parse(dateStr, true).toLocal();
      } catch (_) {
        try {
          return DateTime.parse(dateStr).toLocal();
        } catch (_) {
          return DateTime.now();
        }
      }
    }

    final rawFormats = json['formats'] as List<dynamic>? ?? [];
    final parsedFormats = rawFormats
        .map((f) => MatchFormat.fromJson(f as Map<String, dynamic>))
        .toList();

    return SportEvent(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      slug: json['slug'] ?? 'default-match',
      teamA: info['teamA'] ?? json['teamA'] ?? 'Équipe A',
      teamB: info['teamB'] ?? json['teamB'] ?? 'Équipe B',
      teamAFlag: info['teamAFlag'] ?? json['teamAFlag'],
      teamBFlag: info['teamBFlag'] ?? json['teamBFlag'],
      sportCategory: info['eventCat'] ?? json['cat'] ?? 'Football',
      tournament: info['eventType'] ?? json['tournament'] ?? 'Championnat',
      startDate: parseUtc(info['startTime'] ?? json['startTime']),
      endDate: parseUtc(info['endTime'] ?? json['endTime']),
      formats: parsedFormats,
    );
  }

  MatchStatus get status {
    final now = DateTime.now();
    if (now.isAfter(startDate) && now.isBefore(endDate)) {
      return MatchStatus.live;
    } else if (now.isBefore(startDate)) {
      final diff = startDate.difference(now);
      if (diff.inMinutes <= 60) {
        return MatchStatus.startingSoon;
      }
      return MatchStatus.upcoming;
    } else {
      return MatchStatus.ended;
    }
  }

  String get timeLabel {
    final now = DateTime.now();
    switch (status) {
      case MatchStatus.live:
        final elapsed = now.difference(startDate);
        final hours = elapsed.inHours;
        final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
        return '$hours:$minutes:$seconds';

      case MatchStatus.startingSoon:
        final diff = startDate.difference(now);
        final minutes = diff.inMinutes.toString().padLeft(2, '0');
        final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
        return 'Début dans $minutes:$seconds';

      case MatchStatus.upcoming:
        final df = DateFormat('dd/MM à HH:mm');
        return df.format(startDate);

      case MatchStatus.ended:
        return 'Terminé';
    }
  }
}
