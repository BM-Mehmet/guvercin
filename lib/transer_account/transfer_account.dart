import 'package:flutter/material.dart';
import 'package:guvercin/transer_account/export_keys/exportkeys.dart';
import 'package:guvercin/transer_account/import_keys/import_keys.dart';

void main() {
  runApp(const transferPage());
}

class transferPage extends StatelessWidget {
  const transferPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hesabı Taşı')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Logo ekleme
            Image.asset(
              'lib/img/Logo.png',
              height: 150,
              width: 150,
            ), // 'assets/logo.png' dosyasını projenize eklediğinizden emin olun

            const SizedBox(height: 40), // Butonlar arasında boşluk

            // Import butonu
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QRCodeScannerPage()),
                );
                // Import işlemi
              },
              child: const Text('Anahtarları içe aktar'),
            ),

            const SizedBox(height: 20), // Butonlar arasında boşluk

            // Export butonu
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExportKeysPage()),
                );
                // Export işlemi
              },
              child: const Text('Anahtarları dışa aktar'),
            ),
          ],
        ),
      ),
    );
  }
}
