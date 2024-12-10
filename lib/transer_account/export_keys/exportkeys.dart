import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guvercin/settings/settings_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

const storage = FlutterSecureStorage();

class ExportKeysPage extends StatelessWidget {
  const ExportKeysPage({super.key});

  // Anahtarları Secure Storage'dan al
  Future<String> exportKeys() async {
    String? publicKey = await storage.read(key: '_publicKey');
    String? privateKey = await storage.read(key: '_privateKey');
    
    if (publicKey == null || privateKey == null) {
      throw Exception('Anahtarlar bulunamadı');
    }

    Map<String, String> keys = {
      'publicKey': publicKey,
      'privateKey': privateKey,
    };
    String jsonKeys = jsonEncode(keys);
    return jsonKeys;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Geri tuşuna basıldığında SettingsPage'e yönlendir
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
        return false; // Varsayılan davranışı iptal et
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('QR Kodu Oluştur')),
        body: Center(
          child: FutureBuilder<String>(
            future: exportKeys(), // Anahtarları dışa aktar
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Bir hata oluştu: ${snapshot.error}');
              } else if (snapshot.hasData) {
                String qrCodeData = snapshot.data ?? '';
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    QrImageView(
                      data: qrCodeData, // JSON verisini QR koduna dönüştür
                      version: QrVersions.auto, // Otomatik versiyon
                      size: 250.0,
                    ),
                    const SizedBox(height: 20),
                    const Text('QR Kodu Tarayarak Anahtarları Alabilirsiniz'),
                  ],
                );
              } else {
                return const Text('Veri Bulunamadı');
              }
            },
          ),
        ),
      ),
    );
  }
}


