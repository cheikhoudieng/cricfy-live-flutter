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
  final String? drmKey; // Ex: KeyID:Key pour ClearKey DRM
  final String? streamType; // '7' (dash/cenc) ou '0' (hls/m3u8)

  MatchFormat({
    required this.title,
    this.quality = 'HD 1080p',
    required this.webLink,
    required this.streamUrl,
    this.formatType = 'auto',
    this.mimeType,
    this.headers,
    this.drmKey,
    this.streamType,
  });

  bool get isDash {
    final lower = (formatType + ' ' + streamUrl + ' ' + (mimeType ?? '')).toLowerCase();
    return streamType == '7' || lower.contains('dash') || lower.contains('.mpd') || lower.contains('cenc');
  }

  bool get isHls {
    final lower = (formatType + ' ' + streamUrl + ' ' + (mimeType ?? '')).toLowerCase();
    return streamType == '0' || lower.contains('hls') || lower.contains('.m3u8') || lower.contains('mpegurl');
  }

  factory MatchFormat.fromJson(Map<String, dynamic> json) {
    // Dans Cricfy TV, le lien est dans la clé 'link' (ou 'streamUrl' / 'webLink')
    final String rawLink = (json['link'] ?? json['streamUrl'] ?? json['webLink'] ?? json['url'] ?? '').toString().trim();
    final String rawType = (json['type'] ?? json['format'] ?? '').toString().trim();
    final String rawApi = (json['api'] ?? '').toString().trim();

    String cleanUrl = rawLink;
    final Map<String, String> parsedHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    };

    // Parser les headers délimités par '|' (Ex: "https://...m3u8?|Referer=https://...&Origin=...")
    if (rawLink.contains('|')) {
      final parts = rawLink.split('|');
      cleanUrl = parts[0].trim();
      if (parts.length > 1) {
        final queryHeaders = parts[1].split('&');
        for (final q in queryHeaders) {
          final eqIdx = q.indexOf('=');
          if (eqIdx != -1) {
            final key = q.substring(0, eqIdx).trim();
            final val = q.substring(eqIdx + 1).trim();
            if (key.isNotEmpty && val.isNotEmpty) {
              parsedHeaders[key] = val;
            }
          }
        }
      }
    }

    if (json['headers'] is Map) {
      (json['headers'] as Map).forEach((k, v) {
        parsedHeaders[k.toString()] = v.toString();
      });
    }

    String detectedType = 'auto';
    final lowerUrl = cleanUrl.toLowerCase();
    if (rawType == '7' || lowerUrl.contains('.mpd') || lowerUrl.contains('dash')) {
      detectedType = 'dash';
    } else if (rawType == '0' || lowerUrl.contains('.m3u8') || lowerUrl.contains('hls')) {
      detectedType = 'hls';
    } else if (lowerUrl.contains('.mp4')) {
      detectedType = 'mp4';
    }

    String qualityBadge = 'Full HD';
    if (detectedType == 'dash') {
      qualityBadge = '1080p DASH';
    } else if (detectedType == 'hls') {
      qualityBadge = 'Live HLS';
    }

    return MatchFormat(
      title: json['title'] ?? 'Serveur Principal',
      quality: json['quality'] ?? qualityBadge,
      webLink: rawLink,
      streamUrl: cleanUrl,
      formatType: detectedType,
      mimeType: json['mimeType'] ?? json['mime'],
      headers: parsedHeaders,
      drmKey: rawApi.isNotEmpty ? rawApi : null,
      streamType: rawType.isNotEmpty ? rawType : null,
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
