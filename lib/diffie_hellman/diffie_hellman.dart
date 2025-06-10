import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/export.dart';

class DiffieHellman {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static BigInt modExp(BigInt base, BigInt exponent, BigInt modulus) {
    BigInt result = BigInt.one;
    base = base % modulus;
    while (exponent > BigInt.zero) {
      if (exponent.isOdd) {
        result = (result * base) % modulus;
      }
      exponent = exponent >> 1;
      base = (base * base) % modulus;
    }
    return result;
  }

  static BigInt generateRandomBigInt(int bitLength) {
    final random = Random.secure();
    final bytes =
        List<int>.generate((bitLength / 8).ceil(), (_) => random.nextInt(256));
    return BigInt.parse(
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16);
  }

  // Private key'i okuma ve gerekirse oluşturma
  Future<BigInt> getPrivateKey() async {
    String? privateKeyHex = await _storage.read(key: '_privateKey');
    if (privateKeyHex != null) {
      // Private key zaten varsa, onu döndür
      return BigInt.parse(privateKeyHex, radix: 16);
    } else {
      // Private key yoksa, yeni bir key oluştur ve kaydet
      BigInt privateKey = generateRandomBigInt(256);
      await _storage.write(
          key: '_privateKey', value: privateKey.toRadixString(16));
      return privateKey;
    }
  }

  // Public key'i hesapla ve sakla
  Future<void> savePublicKey(BigInt publicKey) async {
    await _storage.write(key: '_publicKey', value: publicKey.toRadixString(16));
  }

  Future<BigInt> generatePublicKey(BigInt base, BigInt prime) async {
    BigInt privateKey = await getPrivateKey(); // Private key'i al
    BigInt publicKey = modExp(base, privateKey, prime); // Public key hesapla
    await savePublicKey(publicKey); // Public key'i sakla
    return publicKey;
  }

  // Ortak anahtar (shared secret) üretip, AES anahtarına dönüştürür
  Future<Uint8List> computeSharedSecret(
      BigInt otherPublicKey, BigInt prime) async {
    BigInt privateKey = await getPrivateKey(); // Benim private key'im
    BigInt sharedSecret = modExp(otherPublicKey, privateKey, prime);
    print("sharedsecret: {$sharedSecret}");
    print("public: {$otherPublicKey}");
    print("private: {$privateKey}");
    // Ortak sır bilgisinden AES anahtarı üretmek için SHA-256 kullan
    final sharedSecretBytes = utf8.encode(sharedSecret.toString());
    final digest =
        SHA256Digest().process(Uint8List.fromList(sharedSecretBytes));

    return digest; // AES anahtarı (32 byte) olarak kullan
  }
}
