import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guvercin/settings/settings_page.dart';

const storage = FlutterSecureStorage();

class QRCodeScannerPage extends StatefulWidget {
  const QRCodeScannerPage({super.key});

  @override
  State<QRCodeScannerPage> createState() => _QRCodeScannerPageState();
}

class _QRCodeScannerPageState extends State<QRCodeScannerPage> {
  String qrCodeResult = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    scanQRCode(); // Sayfa yüklendiğinde taramayı başlat
  }

  // QR koddan gelen veriyi Secure Storage'a kaydetme
  Future<void> saveKeysFromQRCode(String qrCodeData) async {
    try {
      // QR koddan gelen JSON verisini çözümle
      Map<String, dynamic> keysMap = jsonDecode(qrCodeData);
      String publicKey = keysMap['publicKey'];
      String privateKey = keysMap['privateKey'];

      // Secure Storage'a kaydet
      await storage.write(key: '_publicKey', value: publicKey);
      await storage.write(key: '_privateKey', value: privateKey);

      // Başarılı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anahtarlar güvenli depolamaya kaydedildi.')),
      );

      // Anahtarlar kaydedildikten sonra ayarlar sayfasına dön
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage()),
      );
    } catch (e) {
      // Hata durumunda kullanıcıya bilgi ver
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: Anahtarlar kaydedilemedi. $e')),
      );
    } finally {
      setState(() {
        isLoading = false; // Yükleme durumunu kapat
      });
    }
  }

  // QR kodu tarama işlemi
  Future<void> scanQRCode() async {
    try {
      var scanResult = await BarcodeScanner.scan();
      qrCodeResult = scanResult.rawContent; // Tarama sonucunu al

      if (qrCodeResult.isNotEmpty) {
        await saveKeysFromQRCode(qrCodeResult); // Veriyi kaydet
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarama sonucu boş.')),
        );
      }
    } catch (e) {
      // Tarama hatası durumunda kullanıcıya bilgi ver
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR kod tarama hatası: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Geri tuşu basıldığında ayarlar sayfasına yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
        return false; // Varsayılan geri dönüş davranışını engelle
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('QR Kod Tarayıcı')),
        body: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : const Text('Tarama tamamlandı ve anahtarlar kaydedildi!'),
        ),
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(
    home: QRCodeScannerPage(),
  ));
}
