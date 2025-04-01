import 'package:flutter/material.dart';
import 'package:guvercin/account/delete/delete_account.dart';
import 'package:guvercin/home/home.dart';
import 'package:guvercin/transer_account/export_keys/exportkeys.dart';
import 'package:guvercin/transer_account/import_keys/import_keys.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Geri tuşuna basıldığında HomePage'e yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        return false; // Varsayılan geri dönüş davranışını iptal et
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ayarlar'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ExportKeysPage()),
                  );
                },
                child: const Text('Anahtarları Dışa Aktar'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const QRCodeScannerPage()),
                  );
                },
                child: const Text('Anahtarları İçe Aktar'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DeleteAccount()),
                  );
                },
                child: const Text('Hesabı sil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
