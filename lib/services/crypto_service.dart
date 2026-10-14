import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoService {
  static const String primaryKey = "3hHzxYAgSGI8/ham";
  static const String primaryIv = "UqCvkvjecEIz842V";

  static const String fallbackKey = "MqeYGCT4AYKoHKrT";
  static const String fallbackIv = "oHKrTQuPx8zl8oJ+";

  /// Déchiffre un payload chiffré AES OU retourne le texte s'il est déjà en clair / JSON
  static String? decodeOrDecrypt(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Si c'est déjà du JSON clair (commence par [ ou {)
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return trimmed;
    }

    return decrypt(trimmed);
  }

  /// Déchiffre le payload AES-128-CBC encodé en Base64
  static String? decrypt(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return null;

    // Tentative 1 : Clé standard
    try {
      final key = enc.Key.fromUtf8(primaryKey);
      final iv = enc.IV.fromUtf8(primaryIv);
      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );
      final decrypted = encrypter.decrypt64(encryptedBase64);
      return decrypted;
    } catch (_) {}

    // Tentative 2 : Clé de secours
    try {
      final key = enc.Key.fromUtf8(fallbackKey);
      final iv = enc.IV.fromUtf8(fallbackIv);
      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );
      final decrypted = encrypter.decrypt64(encryptedBase64);
      return decrypted;
    } catch (_) {}

    return null;
  }
}
