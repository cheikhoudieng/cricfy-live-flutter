import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sport_event.dart';
import 'crypto_service.dart';

class CricfyApi {
  // Le serveur réel extrait du code décompilé de l'application Crickfy TV
  static const String baseUrl = 'https://cfynew1.top';
  static const String liveEventsUrl = '$baseUrl/categories/live-events.txt';

  static Map<String, String> get defaultHeaders => {
        'User-Agent': 'okhttp/4.12.0',
        'Accept': '*/*',
      };

  /// Récupère dynamiquement les événements en direct depuis le serveur réel de l'APK
  static Future<List<SportEvent>> fetchLiveEvents() async {
    final response = await http
        .get(Uri.parse(liveEventsUrl), headers: defaultHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Erreur HTTP ${response.statusCode} lors de la connexion au serveur Cricfy');
    }

    final encryptedText = response.body.trim();
    final decryptedJson = CryptoService.decodeOrDecrypt(encryptedText);

    if (decryptedJson == null || decryptedJson.isEmpty) {
      throw Exception('Échec du déchiffrement AES du flux Cricfy');
    }

    final dynamic parsed = jsonDecode(decryptedJson);
    final List<dynamic> jsonList = parsed is List ? parsed : (parsed['events'] ?? []);
    return jsonList.map((item) => SportEvent.fromJson(item)).toList();
  }

  /// Récupère dynamiquement les flux réels d'un événement (streamUrls avec DASH/HLS, liens et headers)
  static Future<List<MatchFormat>> fetchChannelFormats(String slug) async {
    try {
      final url = '$baseUrl/channels/$slug.txt';
      final response = await http
          .get(Uri.parse(url), headers: defaultHeaders)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final encryptedText = response.body.trim();
        final decryptedJson = CryptoService.decodeOrDecrypt(encryptedText);
        if (decryptedJson != null && decryptedJson.isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(decryptedJson);

          // Clé exacte dans Cricfy TV : 'streamUrls'
          final dynamic list = data['streamUrls'] ?? data['formats'] ?? data['streams'];
          if (list is List) {
            return list
                .whereType<Map<String, dynamic>>()
                .map((e) => MatchFormat.fromJson(e))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching channel formats for $slug: $e");
    }
    return [];
  }
}
