import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class AesEncryption {
  // AES GCM Modu Şifreleme
  static Map<String, String> encrypt(String plainText, String key) {
    final keyBytes = base64.decode(key); // Base64 çözüldü.
    final iv = _generateRandomBytes(12); // GCM için 12 byte IV önerilir

    final gcmBlockCipher = _initCipher(true, keyBytes, iv);
    final inputBytes = Uint8List.fromList(utf8.encode(plainText));

    final cipherText = gcmBlockCipher.process(inputBytes);

    return {
      "cipherText": base64.encode(cipherText),
      "iv": base64.encode(iv), // IV'yi birlikte iletmelisiniz
    };
  }

  static GCMBlockCipher _initCipher(
      bool forEncryption, Uint8List key, Uint8List iv) {
    final keyParam = KeyParameter(key);
    final ivParam = ParametersWithIV(keyParam, iv);

    final gcm = GCMBlockCipher(AESEngine());
    gcm.init(forEncryption, ivParam);

    return gcm;
  }

  static Uint8List _generateRandomBytes(int length) {
    final random = SecureRandom("Fortuna")..seed(KeyParameter(Uint8List(32)));
    return random.nextBytes(length);
  }
}
