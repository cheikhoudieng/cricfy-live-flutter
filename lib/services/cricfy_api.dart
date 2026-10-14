import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sport_event.dart';
import 'crypto_service.dart';

class CricfyApi {
  static const String baseUrl = 'https://cfynew1.top';
  static const String liveEventsUrl = '$baseUrl/categories/live-events.txt';

  static const Map<String, String> defaultHeaders = {
    'User-Agent': 'okhttp/4.12.0',
    'Accept-Encoding': 'gzip, deflate',
  };

  /// Récupère et déchiffre la liste complète des événements sportifs en direct
  static Future<List<SportEvent>> fetchLiveEvents() async {
    try {
      final response = await http.get(
        Uri.parse(liveEventsUrl),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Erreur serveur HTTP ${response.statusCode}');
      }

      final encryptedText = response.body.trim();
      final decryptedJson = CryptoService.decrypt(encryptedText);

      if (decryptedJson == null || decryptedJson.isEmpty) {
        throw Exception('Échec du déchiffrement AES');
      }

      final List<dynamic> jsonList = jsonDecode(decryptedJson);
      return jsonList.map((item) => SportEvent.fromJson(item)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Récupère la fiche détaillée d'un match (sources, flux, serveurs)
  static Future<Map<String, dynamic>?> fetchChannelDetails(String slug) async {
    try {
      final url = '$baseUrl/channels/$slug.txt';
      final response = await http.get(
        Uri.parse(url),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final encryptedText = response.body.trim();
      final decryptedJson = CryptoService.decrypt(encryptedText);
      if (decryptedJson == null) return null;

      return jsonDecode(decryptedJson);
    } catch (_) {
      return null;
    }
  }
}
