import 'package:flutter/material.dart';
import '../models/sport_event.dart';
import '../screens/player_screen.dart';
import 'team_logo.dart';

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? const Color(0xFFFF453A).withOpacity(0.55) : const Color(0xFF1E2435),
          width: isLive ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
                // En-tête : Compétition & Badge statut
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${event.sportCategory} • ${event.tournament}'.toUpperCase(),
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

                // Équipes avec LOGOS / DRAPEAUX et Chrono
                Row(
                  children: [
                    // Équipe A (Logo + Nom)
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          TeamLogoWidget(
                            url: event.teamAFlag,
                            teamName: event.teamA,
                            size: 38,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event.teamA,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Centre : VS + Chrono
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22283A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'VS',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.timeLabel,
                            style: TextStyle(
                              color: isLive ? const Color(0xFFFF5722) : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Équipe B (Nom + Logo)
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              event.teamB,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          TeamLogoWidget(
                            url: event.teamBFlag,
                            teamName: event.teamB,
                            size: 38,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Footer : Sources disponibles
                Row(
                  children: [
                    const Icon(Icons.play_circle_fill, color: Color(0xFFFF5722), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${event.formats.length > 0 ? event.formats.length : "Multiples"} serveurs disponibles (Appuyer pour regarder)',
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
