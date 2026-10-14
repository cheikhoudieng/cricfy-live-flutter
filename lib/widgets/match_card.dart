import 'package:flutter/material.dart';
import '../models/sport_event.dart';
import '../screens/player_screen.dart';

class MatchCard extends StatelessWidget {
  final SportEvent event;

  const MatchCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final status = event.status;
    final isLive = status == MatchStatus.live;

    Color badgeColor;
    String badgeText;

    switch (status) {
      case MatchStatus.live:
        badgeColor = const Color(0xFFFF453A);
        badgeText = '● EN DIRECT';
        break;
      case MatchStatus.startingSoon:
        badgeColor = const Color(0xFFFFD60A);
        badgeText = 'BIENTÔT';
        break;
      case MatchStatus.upcoming:
        badgeColor = const Color(0xFF8E8E93);
        badgeText = 'À VENIR';
        break;
      case MatchStatus.ended:
        badgeColor = const Color(0xFF636366);
        badgeText = 'TERMINÉ';
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161A26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLive ? const Color(0xFFFF453A).withOpacity(0.5) : const Color(0xFF1E2435),
          width: isLive ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(event: event),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête : Compétition & Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${event.sportCategory} | ${event.tournament}'.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFFFD60A),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor, width: 0.8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(color: Color(0xFF1E2435), height: 18),

                // Équipes et Chrono
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.teamA,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Column(
                        children: [
                          const Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            event.timeLabel,
                            style: TextStyle(
                              color: isLive ? const Color(0xFFFF5722) : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        event.teamB,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Footer : Sources disponibles
                Row(
                  children: [
                    const Icon(Icons.play_circle_fill, color: Color(0xFFFF5722), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${event.formats.length} serveurs / sources disponibles (Appuyer pour regarder)',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
