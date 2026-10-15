import 'package:flutter/services.dart';
import '../models/sport_event.dart';

class NativePlayerService {
  static const MethodChannel _channel = MethodChannel('com.cricfy.live/player');

  /// Ouvre le lecteur natif ExoPlayer avec décodage matériel et support ClearKey DRM
  static Future<bool> openNativePlayer({
    required String title,
    required String streamUrl,
    String? drmKey,
    Map<String, String>? headers,
    List<MatchFormat>? allFormats,
  }) async {
    try {
      final List<Map<String, dynamic>> formatsData = (allFormats ?? []).map((f) => {
        'title': f.title,
        'streamUrl': f.streamUrl,
        'drmKey': f.drmKey,
        'headers': f.headers ?? {},
        'isDash': f.isDash,
      }).toList();

      final res = await _channel.invokeMethod<bool>('openPlayer', {
        'title': title,
        'url': streamUrl,
        'drmKey': drmKey,
        'headers': headers ?? {},
        'servers': formatsData,
      });
      return res ?? true;
    } catch (e) {
      return false;
    }
  }
}
