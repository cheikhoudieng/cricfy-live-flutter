import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/sport_event.dart';
import '../services/cricfy_api.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final SportEvent event;

  const PlayerScreen({super.key, required this.event});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  int _selectedSourceIndex = 0;
  bool _isLoading = true;
  bool _isCanvasFullscreen = false;
  String? _errorMessage;
  List<MatchFormat> _sources = [];
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _sources = List.from(widget.event.formats);
    _loadChannelDetailsAndPlay();
  }

  Future<void> _loadChannelDetailsAndPlay() async {
    setState(() => _isLoading = true);
    final extraFormats = await CricfyApi.fetchChannelFormats(widget.event.slug);
    if (!mounted) return;

    if (extraFormats.isNotEmpty) {
      setState(() {
        _sources = extraFormats;
      });
    }

    if (_sources.isNotEmpty) {
      _playSource(0);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Aucun flux vidéo disponible pour cet événement.";
      });
    }
  }

  Future<void> _playSource(int index, {int autoTryCount = 0}) async {
    if (!mounted || _sources.isEmpty) return;

    final safeIndex = index % _sources.length;
    final source = _sources[safeIndex];

    setState(() {
      _selectedSourceIndex = safeIndex;
      _isLoading = true;
      _errorMessage = null;
    });

    _chewieController?.dispose();
    _chewieController = null;
    await _videoPlayerController?.dispose();
    _videoPlayerController = null;

    final streamUrl = source.streamUrl.trim();
    if (streamUrl.isEmpty || !streamUrl.startsWith('http')) {
      _handleSourceError(safeIndex, "Lien de flux vide ou invalide", autoTryCount: autoTryCount);
      return;
    }

    // Détection du protocole : MPEG-DASH (.mpd) vs HLS (.m3u8) vs SmoothStreaming vs standard
    VideoFormat formatHint = VideoFormat.other;
    if (source.isDash || streamUrl.toLowerCase().contains('.mpd')) {
      formatHint = VideoFormat.dash;
    } else if (source.isHls || streamUrl.toLowerCase().contains('.m3u8')) {
      formatHint = VideoFormat.hls;
    } else if (streamUrl.toLowerCase().contains('.ism')) {
      formatHint = VideoFormat.ss;
    }

    final Map<String, String> requestHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    };
    if (source.headers != null) {
      requestHeaders.addAll(source.headers!);
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        formatHint: formatHint,
        httpHeaders: requestHeaders,
      );

      await controller.initialize().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw Exception("Délai de connexion dépassé (12s)"),
      );

      if (!mounted) {
        controller.dispose();
        return;
      }

      _videoPlayerController = controller;
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio > 0
            ? _videoPlayerController!.value.aspectRatio
            : 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryOrange,
          handleColor: AppTheme.primaryOrange,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white54,
        ),
      );

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Failed to load stream (${source.title}): $e");
      _handleSourceError(safeIndex, e.toString(), autoTryCount: autoTryCount);
    }
  }

  void _handleSourceError(int failedIndex, String errorMsg, {int autoTryCount = 0}) {
    if (!mounted) return;

    // Si le premier serveur échoue et qu'il y a d'autres serveurs, essayer automatiquement le suivant jusqu'à 2 fois
    if (autoTryCount < 2 && _sources.length > 1) {
      final nextIndex = (failedIndex + 1) % _sources.length;
      debugPrint("Auto-trying next stream: server $nextIndex");
      _playSource(nextIndex, autoTryCount: autoTryCount + 1);
      return;
    }

    final failedSource = _sources[failedIndex];
    setState(() {
      _isLoading = false;
      _errorMessage = "Impossible de lire la source \"${failedSource.title}\".\nVeuillez choisir un autre serveur dans la liste ci-dessous.";
    });
  }

  void _toggleFullscreenMode() {
    setState(() {
      _isCanvasFullscreen = !_isCanvasFullscreen;
    });
    if (_isCanvasFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      _toggleFullscreenMode();
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      if (_videoPlayerController != null) {
        if (_videoPlayerController!.value.isPlaying) {
          _videoPlayerController!.pause();
        } else {
          _videoPlayerController!.play();
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_videoPlayerController != null) {
        final pos = _videoPlayerController!.value.position;
        _videoPlayerController!.seekTo(pos + const Duration(seconds: 10));
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_videoPlayerController != null) {
        final pos = _videoPlayerController!.value.position;
        _videoPlayerController!.seekTo(pos - const Duration(seconds: 10));
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape && _isCanvasFullscreen) {
      _toggleFullscreenMode();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _keyboardFocusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = MediaQuery.of(context).size.width >= 900;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: _isCanvasFullscreen ? Colors.black : AppTheme.scaffoldBg,
        appBar: _isCanvasFullscreen
            ? null
            : AppBar(
                title: Text(
                  '${widget.event.teamA} vs ${widget.event.teamB}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      _isCanvasFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: AppTheme.primaryOrange,
                    ),
                    tooltip: 'Mode Plein écran (F)',
                    onPressed: _toggleFullscreenMode,
                  ),
                ],
              ),
        body: _isCanvasFullscreen
            ? _buildPlayerView()
            : isDesktopOrTablet
                ? _buildSplitScreenDeX()
                : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildPlayerView() {
    final activeSource = _sources.isNotEmpty ? _sources[_selectedSourceIndex] : null;

    return GestureDetector(
      onDoubleTap: _toggleFullscreenMode,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isLoading)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryOrange),
                  const SizedBox(height: 16),
                  Text(
                    'Connexion à ${activeSource?.title ?? "la source"} (${activeSource?.isDash == true ? "MPEG-DASH" : "HLS"})...',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              )
            else if (_errorMessage != null)
              Padding(
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
                    if (_sources.length > 1)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Essayer la Source Suivante'),
                        onPressed: () {
                          final next = (_selectedSourceIndex + 1) % _sources.length;
                          _playSource(next);
                        },
                      ),
                  ],
                ),
              )
            else if (_chewieController != null)
              Chewie(controller: _chewieController!)
            else
              const SizedBox(),

            // Badge Protocole (DASH / HLS / DRM)
            if (!_isLoading && activeSource != null)
              Positioned(
                top: 12,
                left: 12,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: activeSource.isDash
                              ? const Color(0xFF7C4DFF)
                              : const Color(0xFFFF5722),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.stream,
                            color: activeSource.isDash
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFFFF5722),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            activeSource.isDash ? 'MPEG-DASH (.MPD)' : 'HLS (.M3U8)',
                            style: TextStyle(
                              color: activeSource.isDash
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (activeSource.drmKey != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade900.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'ClearKey DRM',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitScreenDeX() {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: _buildPlayerView(),
        ),
        Container(width: 1, color: AppTheme.borderColor),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildEventHeaderCard(),
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
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildPlayerView(),
        ),
        _buildEventHeaderCard(),
        Expanded(child: _buildSourcesList()),
      ],
    );
  }

  Widget _buildEventHeaderCard() {
    final ev = widget.event;
    final isLive = ev.status == MatchStatus.live;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${ev.sportCategory.toUpperCase()} • ${ev.tournament.toUpperCase()}',
                  style: const TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.liveBadgeRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '● EN DIRECT',
                    style: TextStyle(
                      color: AppTheme.liveBadgeRed,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${ev.teamA}   VS   ${ev.teamB}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chronomètre : ${ev.timeLabel} • ${_sources.length} sources réelles disponibles',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesList() {
    if (_sources.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.live_tv, color: AppTheme.textSecondary, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Chargement des serveurs en direct...',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadChannelDetailsAndPlay,
                child: const Text('Rafraîchir les flux'),
              )
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _sources.length,
      itemBuilder: (context, index) {
        final source = _sources[index];
        final isSelected = index == _selectedSourceIndex;

        return Card(
          elevation: isSelected ? 2 : 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? AppTheme.primaryOrange : AppTheme.borderColor,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          color: isSelected ? AppTheme.primaryOrange.withOpacity(0.06) : AppTheme.cardBg,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: isSelected ? AppTheme.primaryOrange : const Color(0xFFF0F2F6),
              foregroundColor: isSelected ? Colors.white : AppTheme.textPrimary,
              child: Icon(
                isSelected ? Icons.play_arrow : Icons.tv,
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
                    color: source.isDash ? Colors.deepPurple.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    source.isDash ? 'MPEG-DASH' : 'HLS (.m3u8)',
                    style: TextStyle(
                      color: source.isDash ? Colors.deepPurple.shade700 : Colors.blue.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (source.drmKey != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ClearKey',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: isSelected
                ? const Icon(Icons.volume_up, color: AppTheme.primaryOrange)
                : const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
            onTap: () {
              if (!isSelected || _errorMessage != null) {
                _playSource(index);
              }
            },
          ),
        );
      },
    );
  }
}
