import 'package:intl/intl.dart';

enum MatchStatus { live, startingSoon, upcoming, ended }

class MatchFormat {
  final String title;
  final String webLink;
  final String streamUrl;

  MatchFormat({
    required this.title,
    required this.webLink,
    required this.streamUrl,
  });

  factory MatchFormat.fromJson(Map<String, dynamic> json) {
    return MatchFormat(
      title: json['title'] ?? 'Serveur Inconnu',
      webLink: json['webLink'] ?? '',
      streamUrl: json['streamUrl'] ?? json['webLink'] ?? '',
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
        return DateTime.now();
      }
    }

    final rawFormats = json['formats'] as List<dynamic>? ?? [];
    final parsedFormats = rawFormats
        .map((f) => MatchFormat.fromJson(f as Map<String, dynamic>))
        .toList();

    return SportEvent(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      teamA: info['teamA'] ?? 'Équipe A',
      teamB: info['teamB'] ?? 'Équipe B',
      teamAFlag: info['teamAFlag'],
      teamBFlag: info['teamBFlag'],
      sportCategory: info['eventCat'] ?? json['cat'] ?? 'Sport',
      tournament: info['eventType'] ?? '',
      startDate: parseUtc(info['startTime']),
      endDate: parseUtc(info['endTime']),
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
