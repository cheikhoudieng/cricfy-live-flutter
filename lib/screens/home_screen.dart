import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sport_event.dart';
import '../services/cricfy_api.dart';
import '../theme/app_theme.dart';
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
  String _filter = 'ALL';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
      if (mounted) {
        setState(() {
          _allEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_soccer, color: AppTheme.primaryOrange),
            SizedBox(width: 8),
            Text(
              'CRICFY LIVE',
              style: TextStyle(
                color: AppTheme.primaryOrange,
                fontSize: 19,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryOrange),
            tooltip: 'Rafraîchir les matchs',
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de filtres dynamiques
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceWhite,
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              children: [
                _buildFilterButton('Tous (${_allEvents.length})', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterButton('En Direct ($liveCount)', 'LIVE', isLiveBadge: true),
                const SizedBox(width: 8),
                _buildFilterButton('À Venir ($upcomingCount)', 'UPCOMING'),
              ],
            ),
          ),

          // Zone d'affichage avec Pull-To-Refresh dynamique
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primaryOrange,
              onRefresh: _loadEvents,
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primaryOrange),
                          SizedBox(height: 16),
                          Text(
                            'Connexion à cfynew1.top & Déchiffrement AES...',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          )
                        ],
                      ),
                    )
                  : _error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    const Icon(Icons.cloud_off, color: AppTheme.liveRed, size: 54),
                                    const SizedBox(height: 12),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryOrange,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Réessayer'),
                                      onPressed: _loadEvents,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Tirez vers le bas pour actualiser à tout moment',
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : _filteredEvents.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                                const Center(
                                  child: Text(
                                    'Aucun match trouvé pour ce filtre.\nTirez vers le bas pour actualiser.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
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

  Widget _buildFilterButton(String label, String key, {bool isLiveBadge = false}) {
    final isSelected = _filter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isLiveBadge ? AppTheme.liveRed : AppTheme.primaryOrange)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? (isLiveBadge ? AppTheme.liveRed : AppTheme.primaryOrange)
                  : AppTheme.borderLight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
