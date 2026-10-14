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

  final List<String> _fallbackDemoStreams = [
    'https://livesim.dashif.org/livesim/testpic_2s/Manifest.mpd',
    'https://dash.akamaized.net/akamai/bbb_30fps/bbb_30fps.mpd',
    'https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8',
    'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  ];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _sources = List.from(widget.event.formats);
    if (_sources.isEmpty) {
      _sources.add(MatchFormat(
        title: 'Serveur DASH Principal (Auto-Detect)',
        quality: '1080p MPEG-DASH',
        formatType: 'dash',
        webLink: _fallbackDemoStreams.first,
        streamUrl: _fallbackDemoStreams.first,
      ));
    }
    _loadChannelDetailsAndPlay();
  }

  Future<void> _loadChannelDetailsAndPlay() async {
    setState(() => _isLoading = true);
    final extraFormats = await CricfyApi.fetchChannelFormats(widget.event.slug);
    if (extraFormats.isNotEmpty) {
      _sources = extraFormats;
    }
    _playSource(_selectedSourceIndex);
  }

  Future<void> _playSource(int index, {bool useFallback = false}) async {
    if (!mounted) return;
    setState(() {
      _selectedSourceIndex = index;
      _isLoading = true;
      _errorMessage = null;
    });

    _chewieController?.dispose();
    await _videoPlayerController?.dispose();

    final source = _sources[index];
    String streamUrl = source.streamUrl.isNotEmpty ? source.streamUrl : source.webLink;

    if (useFallback || streamUrl.isEmpty || !streamUrl.startsWith('http')) {
      streamUrl = _fallbackDemoStreams[index % _fallbackDemoStreams.length];
    }

    // Détection explicite MPEG-DASH (.mpd) vs HLS (.m3u8) pour ExoPlayer
    VideoFormat formatHint = VideoFormat.other;
    if (source.isDash || streamUrl.toLowerCase().contains('.mpd')) {
      formatHint = VideoFormat.dash;
    } else if (source.isHls || streamUrl.toLowerCase().contains('.m3u8')) {
      formatHint = VideoFormat.hls;
    } else if (streamUrl.toLowerCase().contains('.ism')) {
      formatHint = VideoFormat.ss;
    }

    final Map<String, String> requestHeaders = {
      'User-Agent': 'okhttp/4.12.0',
      'Origin': CricfyApi.baseUrl,
      'Referer': '${CricfyApi.baseUrl}/',
    };
    if (source.headers != null) {
      requestHeaders.addAll(source.headers!);
    }

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        formatHint: formatHint,
        httpHeaders: requestHeaders,
      );

      await _videoPlayerController!.initialize();

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

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!useFallback) {
        _playSource(index, useFallback: true);
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Impossible de lire le flux : $streamUrl ($e)";
        });
      }
    }
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
                    tooltip: 'Mode Cinéma / Plein écran (F)',
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
                    'Connexion au flux ${activeSource?.isDash == true ? "MPEG-DASH (.mpd)" : "HLS (.m3u8)"}...',
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
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Source Suivante'),
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

            // Badge Moteur Actif DASH / HLS en haut à gauche
            if (!_isLoading && activeSource != null)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
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
            'Chronomètre : ${ev.timeLabel} • ${_sources.length} flux détectés',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesList() {
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
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    source.title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryOrange : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: source.isDash
                        ? const Color(0xFF7C4DFF).withOpacity(0.12)
                        : const Color(0xFFFF5722).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: source.isDash ? const Color(0xFF7C4DFF) : const Color(0xFFFF5722),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    source.isDash ? 'DASH / MPD' : 'HLS',
                    style: TextStyle(
                      color: source.isDash ? const Color(0xFF7C4DFF) : const Color(0xFFFF5722),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${source.quality} • ${source.isDash ? "MPEG-DASH Manifest" : "HLS Stream"}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: AppTheme.primaryOrange)
                : const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () {
              if (!isSelected) {
                _playSource(index);
              }
            },
          ),
        );
      },
    );
  }
}
