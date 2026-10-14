import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sport_event.dart';
import '../services/cricfy_api.dart';
import '../widgets/match_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SportEvent> _allEvents = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'ALL'; // 'ALL', 'LIVE', 'UPCOMING'
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    // Rafraîchir les compteurs chaque seconde
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final events = await CricfyApi.fetchLiveEvents();
      setState(() {
        _allEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<SportEvent> get _filteredEvents {
    if (_filter == 'LIVE') {
      return _allEvents.where((e) => e.status == MatchStatus.live).toList();
    } else if (_filter == 'UPCOMING') {
      return _allEvents.where((e) =>
          e.status == MatchStatus.upcoming || e.status == MatchStatus.startingSoon).toList();
    }
    return _allEvents;
  }

  @override
  Widget build(BuildContext context) {
    final liveCount = _allEvents.where((e) => e.status == MatchStatus.live).length;
    final upcomingCount = _allEvents.where((e) =>
        e.status == MatchStatus.upcoming || e.status == MatchStatus.startingSoon).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131722),
        elevation: 0,
        title: const Text(
          'CRICFY LIVE',
          style: TextStyle(
            color: Color(0xFFFF5722),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de filtres
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF131722),
            child: Row(
              children: [
                _buildFilterButton('Tous (${_allEvents.length})', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterButton('En Direct ($liveCount)', 'LIVE', badgeColor: const Color(0xFFFF453A)),
                const SizedBox(width: 8),
                _buildFilterButton('À Venir ($upcomingCount)', 'UPCOMING'),
              ],
            ),
          ),

          // Contenu principal
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFFF5722)),
                        SizedBox(height: 16),
                        Text(
                          'Déchiffrement AES & Récupération des flux...',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        )
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi_off, color: Colors.redAccent, size: 54),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5722),
                                ),
                                onPressed: _loadEvents,
                                child: const Text('Réessayer'),
                              )
                            ],
                          ),
                        ),
                      )
                    : _filteredEvents.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun match trouvé pour ce filtre.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFFF5722),
                            onRefresh: _loadEvents,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(top: 8, bottom: 24),
                              itemCount: _filteredEvents.length,
                              itemBuilder: (context, index) {
                                return MatchCard(event: _filteredEvents[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String key, {Color? badgeColor}) {
    final isSelected = _filter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF5722) : const Color(0xFF1E2435),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
