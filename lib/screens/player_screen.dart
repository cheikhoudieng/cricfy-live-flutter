import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/sport_event.dart';
import '../services/cricfy_api.dart';

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
  String? _errorMessage;
  List<MatchFormat> _sources = [];

  // URLs de démonstration HLS test au cas où les flux chiffrés requièrent un proxy DRM
  final List<String> _fallbackDemoStreams = [
    'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    'https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8',
  ];

  @override
  void initState() {
    super.initState();
    _sources = List.from(widget.event.formats);
    if (_sources.isEmpty) {
      _sources.add(MatchFormat(
        title: 'Serveur Principal (Auto-Detect)',
        webLink: '',
        streamUrl: '',
      ));
    }
    _loadChannelDetailsAndPlay();
  }

  Future<void> _loadChannelDetailsAndPlay() async {
    setState(() => _isLoading = true);
    try {
      final details = await CricfyApi.fetchChannelDetails(widget.event.slug);
      if (details != null && details['formats'] != null) {
        final list = details['formats'] as List<dynamic>;
        if (list.isNotEmpty) {
          _sources = list.map((e) => MatchFormat.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    _playSource(_selectedSourceIndex);
  }

  void _playSource(int index) async {
    setState(() {
      _selectedSourceIndex = index;
      _isLoading = true;
      _errorMessage = null;
    });

    _chewieController?.dispose();
    await _videoPlayerController?.dispose();

    final source = _sources[index];
    String streamUrl = source.streamUrl.isNotEmpty ? source.streamUrl : source.webLink;

    // Si le lien est vide dans l'API Cricfy, on utilise un flux de secours
    if (streamUrl.isEmpty || !streamUrl.startsWith('http')) {
      streamUrl = _fallbackDemoStreams[index % _fallbackDemoStreams.length];
    }

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        httpHeaders: {
          'User-Agent': 'okhttp/4.12.0',
          'Referer': 'https://cfynew1.top/',
        },
      );

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        aspectRatio: 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Erreur de lecture du flux:\n$errorMessage',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Changer de source'),
                    onPressed: () {
                      final next = (_selectedSourceIndex + 1) % _sources.length;
                      _playSource(next);
                    },
                  )
                ],
              ),
            ),
          );
        },
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Impossible de charger la source: $e";
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    final isLive = ev.status == MatchStatus.live;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131722),
        elevation: 0,
        title: Text(
          '${ev.teamA} vs ${ev.teamB}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isLive)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF453A).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF453A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: Color(0xFFFF453A), size: 8),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFFFF453A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Zone Vidéo
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFFF5722)),
                          SizedBox(height: 12),
                          Text(
                            'Chargement du flux...',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          )
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        )
                      : _chewieController != null
                          ? Chewie(controller: _chewieController!)
                          : const SizedBox(),
            ),
          ),

          // 2. En-tête Match & Tournoi
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF131722),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ev.sportCategory.toUpperCase()} | ${ev.tournament.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFFFFD60A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${ev.teamA}  VS  ${ev.teamB}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chrono: ${ev.timeLabel} • ${_sources.length} sources disponibles',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 3. Sélecteur de Sources
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.stream, color: Color(0xFFFF5722), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'SELECTIONNER UNE SOURCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedSourceIndex + 1}/${_sources.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                )
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _sources.length,
              itemBuilder: (context, index) {
                final source = _sources[index];
                final isSelected = index == _selectedSourceIndex;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF5722).withOpacity(0.15)
                        : const Color(0xFF161A26),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF5722)
                          : const Color(0xFF22293A),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF5722)
                            : const Color(0xFF22293A),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected ? Icons.play_arrow : Icons.tv,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      source.title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isSelected ? 'En cours de diffusion' : 'Flux haute stabilité',
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFFF5722) : Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(0xFFFF5722), size: 20)
                        : const Icon(Icons.chevron_right, color: Colors.white24),
                    onTap: () {
                      if (!isSelected) {
                        _playSource(index);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
