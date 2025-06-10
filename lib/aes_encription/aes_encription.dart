import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';

class AesEncryption {
  // --- Metin Şifreleme ---
  static String encryptText(String plainText, String base64Key) {
    final key = base64.decode(base64Key);
    final iv = _generateRandomBytes(12);
    final cipher = _initCipher(true, key, iv);

    final input = Uint8List.fromList(utf8.encode(plainText));
    final encrypted = cipher.process(input);

    // IV + CipherText birleştirilip base64 encode edilir
    final combined = Uint8List(iv.length + encrypted.length)
      ..setRange(0, iv.length, iv)
      ..setRange(iv.length, iv.length + encrypted.length, encrypted);

    return base64.encode(combined);
  }

  // --- Metin Çözme ---
  static String decryptText(String base64Combined, String base64Key) {
    final key = base64.decode(base64Key);
    final combined = base64.decode(base64Combined);

    final iv = combined.sublist(0, 12);
    final cipherText = combined.sublist(12);

    final cipher = _initCipher(false, key, iv);
    final decrypted = cipher.process(cipherText);

    return utf8.decode(decrypted);
  }

  // --- Dosya Şifreleme ---
  static Uint8List encryptFile(Uint8List fileBytes, String base64Key) {
    final key = base64.decode(base64Key);
    final iv = _generateRandomBytes(12);
    final cipher = _initCipher(true, key, iv);

    final encrypted = cipher.process(fileBytes);

    // IV + Encrypted birleşimi
    final combined = Uint8List(iv.length + encrypted.length)
      ..setRange(0, iv.length, iv)
      ..setRange(iv.length, iv.length + encrypted.length, encrypted);

    return combined;
  }

  // --- Dosya Çözme ---
  static Uint8List decryptFile(Uint8List combinedCipherData, String base64Key) {
    final key = base64.decode(base64Key);

    final iv = combinedCipherData.sublist(0, 12);
    final cipherData = combinedCipherData.sublist(12);

    final cipher = _initCipher(false, key, iv);
    return cipher.process(cipherData);
  }

  // AES-GCM BlockCipher başlatıcı
  static GCMBlockCipher _initCipher(
      bool forEncryption, Uint8List key, Uint8List iv) {
    final keyParam = KeyParameter(key);
    final params = AEADParameters(
        keyParam, 128, iv, Uint8List(0)); // 128 bit tag, boş ek veri
    final gcm = GCMBlockCipher(AESEngine());
    gcm.init(forEncryption, params);
    return gcm;
  }

  // Rastgele IV üretici
  static Uint8List _generateRandomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }
}
