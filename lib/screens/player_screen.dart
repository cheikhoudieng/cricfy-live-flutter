import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/sport_event.dart';
import '../services/cricfy_api.dart';
import '../services/native_player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/team_logo.dart';

class PlayerScreen extends StatefulWidget {
  final SportEvent event;

  const PlayerScreen({super.key, required this.event});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int _selectedSourceIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  List<MatchFormat> _sources = [];
  bool _hasAutoLaunched = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _sources = List.from(widget.event.formats);
    _loadChannelDetailsAndPlay();
  }

  Future<void> _loadChannelDetailsAndPlay() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final extraFormats = await CricfyApi.fetchChannelFormats(widget.event.slug);
    if (!mounted) return;

    if (extraFormats.isNotEmpty) {
      // Prioriser les flux directs et DRM pour l'affichage
      final directStreams = extraFormats.where((f) => !f.isDash && f.drmKey == null).toList();
      final otherStreams = extraFormats.where((f) => f.isDash || f.drmKey != null).toList();

      setState(() {
        _sources = [...directStreams, ...otherStreams];
      });
    }

    setState(() {
      _isLoading = false;
    });

    if (_sources.isNotEmpty) {
      if (!_hasAutoLaunched) {
        _hasAutoLaunched = true;
        _openNativePlayerForSource(_sources[0]);
      }
    } else {
      setState(() {
        _errorMessage = "Aucun flux vidéo disponible pour cet événement.";
      });
    }
  }

  void _openNativePlayerForSource(MatchFormat source) {
    NativePlayerService.openNativePlayer(
      title: '${widget.event.teamA} vs ${widget.event.teamB} (${source.title})',
      streamUrl: source.streamUrl,
      drmKey: source.drmKey,
      headers: source.headers,
      allFormats: _sources,
    );
  }

  void _playSource(int index) {
    if (_sources.isEmpty) return;
    final safeIndex = index % _sources.length;
    setState(() {
      _selectedSourceIndex = safeIndex;
    });
    _openNativePlayerForSource(_sources[safeIndex]);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          '${widget.event.teamA} vs ${widget.event.teamB}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryOrange),
            tooltip: 'Actualiser les serveurs',
            onPressed: _loadChannelDetailsAndPlay,
          ),
        ],
      ),
      body: isDesktopOrTablet
          ? _buildSplitScreenDeX()
          : _buildMobileLayout(),
    );
  }

  Widget _buildSplitScreenDeX() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeroBroadcastCard(),
                _buildEventDetailsCard(),
              ],
            ),
          ),
        ),
        Container(width: 1, color: AppTheme.borderColor),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.dns, color: AppTheme.primaryOrange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'SERVEURS DISPONIBLES (${_sources.length})',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildSourcesList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildHeroBroadcastCard(),
        _buildEventDetailsCard(),
        Expanded(child: _buildSourcesList()),
      ],
    );
  }

  Widget _buildHeroBroadcastCard() {
    final ev = widget.event;
    final activeSource = _sources.isNotEmpty ? _sources[_selectedSourceIndex] : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF141926), Color(0xFF1E2538)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C354D), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête Match & Tournoi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${ev.sportCategory} • ${ev.tournament}'.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF453A).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFF453A), width: 0.8),
                ),
                child: const Text(
                  '● EN DIRECT',
                  style: TextStyle(
                    color: Color(0xFFFF453A),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Logos et Affrontement
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Column(
                  children: [
                    TeamLogoWidget(url: ev.teamAFlag, teamName: ev.teamA, size: 54),
                    const SizedBox(height: 8),
                    Text(
                      ev.teamA,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131D),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2C354D)),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: Color(0xFFFFD60A),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    TeamLogoWidget(url: ev.teamBFlag, teamName: ev.teamB, size: 54),
                    const SizedBox(height: 8),
                    Text(
                      ev.teamB,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Bouton Principal Lancement ExoPlayer Natif
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.play_circle_filled, size: 24),
              label: Text(
                activeSource != null
                    ? 'REGARDER SUR EXOPLAYER (${activeSource.title})'
                    : 'OUVRIR DANS EXOPLAYER',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                if (activeSource != null) {
                  _openNativePlayerForSource(activeSource);
                } else if (_sources.isNotEmpty) {
                  _openNativePlayerForSource(_sources[0]);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetailsCard() {
    final ev = widget.event;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppTheme.textSecondary, size: 16),
          const SizedBox(width: 6),
          Text(
            ev.timeLabel,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const Spacer(),
          Text(
            '${_sources.length} serveurs disponibles',
            style: const TextStyle(
              color: Color(0xFFFFD60A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryOrange),
            SizedBox(height: 14),
            Text(
              'Récupération des flux en direct...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                onPressed: _loadChannelDetailsAndPlay,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _sources.length,
      itemBuilder: (context, index) {
        final source = _sources[index];
        final isSelected = index == _selectedSourceIndex;
        final isDirect = !source.isDash && source.drmKey == null;
        final hasClearKey = source.drmKey != null;

        return Card(
          elevation: isSelected ? 2 : 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppTheme.primaryOrange : AppTheme.borderColor,
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          color: isSelected ? AppTheme.primaryOrange.withOpacity(0.08) : const Color(0xFF161A26),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? AppTheme.primaryOrange
                  : (hasClearKey
                      ? Colors.amber.shade900.withOpacity(0.2)
                      : (isDirect ? Colors.green.shade900.withOpacity(0.2) : Colors.deepPurple.shade900.withOpacity(0.2))),
              foregroundColor: isSelected
                  ? Colors.white
                  : (hasClearKey
                      ? Colors.amberAccent
                      : (isDirect ? Colors.greenAccent : Colors.lightBlueAccent)),
              child: Icon(
                hasClearKey ? Icons.lock_open : (isSelected ? Icons.play_arrow : Icons.live_tv),
                size: 20,
              ),
            ),
            title: Text(
              source.title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppTheme.primaryOrange : AppTheme.textPrimary,
                fontSize: 14,
              ),
            ),
            subtitle: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasClearKey
                        ? Colors.amber.shade900.withOpacity(0.2)
                        : (isDirect ? Colors.green.shade900.withOpacity(0.2) : Colors.deepPurple.shade900.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hasClearKey
                        ? '⚡ CLEARKEY DASH'
                        : (isDirect ? '🟢 DIRECT HLS' : 'MPEG-DASH'),
                    style: TextStyle(
                      color: hasClearKey
                          ? Colors.amberAccent
                          : (isDirect ? Colors.greenAccent : Colors.lightBlueAccent),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  source.quality,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline, color: AppTheme.primaryOrange, size: 26),
              tooltip: 'Lire dans ExoPlayer',
              onPressed: () => _playSource(index),
            ),
            onTap: () => _playSource(index),
          ),
        );
      },
    );
  }
}
