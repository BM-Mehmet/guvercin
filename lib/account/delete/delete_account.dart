import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guvercin/load_page/load.dart';
import 'package:http/http.dart' as http;

class DeleteAccount extends StatefulWidget {
  @override
  _DeleteAccountState createState() => _DeleteAccountState();
}

class _DeleteAccountState extends State<DeleteAccount> {
  String generatedCode = '';
  final TextEditingController codeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();

  String? username; // Kullanıcı adı

  @override
  void initState() {
    super.initState();
    generateCode();
    _getUsernameFromToken(); // Kullanıcı adını token'dan al
  }

  @override
  void dispose() {
    codeController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void generateCode() {
    final random = Random();
    setState(() {
      generatedCode = (100000 + random.nextInt(900000)).toString();
    });
  }

  // JWT token'dan username'i almak
  Future<void> _getUsernameFromToken() async {
    String? token = await secureStorage.read(key: 'auth_token');
    if (token != null) {
      // Token'dan username'i çözümleyelim (payload kısmı)
      var decodedToken = _decodeJWT(token);
      setState(() {
        username = decodedToken['username'];
      });
    }
  }

  // JWT çözümleme işlemi
  Map<String, dynamic> _decodeJWT(String token) {
    final parts = token.split('.');
    final payload = base64Url.decode(base64Url.normalize(parts[1]));
    return json.decode(utf8.decode(payload));
  }

  Future<void> deleteAccount() async {
    if (codeController.text == generatedCode &&
        passwordController.text.isNotEmpty) {
      print(username);

      if (username == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kullanıcı adı bulunamadı.')),
        );
        return;
      }

      // API'ye hesap silme isteği gönder
      try {
        final response = await http.delete(
          Uri.parse(
              'http://98.66.234.35:5005/delete_user/$username'), // Kullanıcı adını dinamik olarak kullan
        );

        if (response.statusCode == 200) {
          // API'den başarıyla yanıt alındı
          await secureStorage.deleteAll(); // Secure storage temizleniyor

          await secureStorage.delete(key: '_privateKey');
          await secureStorage.delete(key: '_publicKey');


          // Kullanıcıyı giriş ekranına yönlendirme
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoadPage()),
            );
          }
        } else {
          // API'den hata alınmışsa
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hesap silme işlemi başarısız.')),
          );
        }
      } catch (e) {
        // Hata durumunda
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kod veya şifre hatalı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hesap Sil'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.person,
                size: 100, // İkon boyutu
                color: Colors.grey, // İkon rengi
              ),
              SizedBox(height: 20), // İkon ile metin arasında boşluk
              Text(
                'Kod: $generatedCode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration:
                    InputDecoration(labelText: 'Doğrulama Kodunu Girin'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Şifrenizi Girin'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: deleteAccount,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                child: const Text('Hesabı Sil',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
