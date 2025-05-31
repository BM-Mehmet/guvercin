import 'package:flutter/material.dart';
import 'package:guvercin/home/home.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'dart:convert'; // String'i byte dizisine çevirmek için gerekli
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart'; // Cihaz bilgisi almak için
import 'package:guvercin/env.dart';
void main() {
  runApp(const LoginPage());
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Güvercin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CheckTokenScreen(),
    );
  }
}

// Token doğrulama ekranı
class CheckTokenScreen extends StatefulWidget {
  const CheckTokenScreen({super.key});

  @override
  _CheckTokenScreenState createState() => _CheckTokenScreenState();
}

class _CheckTokenScreenState extends State<CheckTokenScreen> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> _checkToken() async {
    String? token = await _secureStorage.read(key: 'auth_token');

    if (token   != null) {
      // Token geçerli mi kontrol et
      final response = await http.post(
        Uri.parse('http://$Url:5001/check-session'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );

      if (response.statusCode == 200) {
        // Token geçerli -> Ana ekrana yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        // Token geçersiz -> Login ekranına yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      // Token yok -> Login ekranına yönlendir
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _checkToken(); // Token kontrolü başlat
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Yükleniyor animasyonu
      ),
    );
  }
}

// Login ekranı
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin(); // Cihaz bilgisi almak için

  // SHA256 ile string'i hashle
  String _hashPassword(String password) {
    final utf8Key = utf8.encode(password); // Şifreyi byte dizisine dönüştür
    final sha256 = SHA256Digest(); // SHA256 hash algoritması
    final hash = sha256.process(utf8Key); // Hashleme işlemi
    return base64.encode(hash); // Base64 formatında döndür
  }

  // Cihaz bilgisini almak
  Future<String> _getDeviceInfo() async {
    String deviceName = 'Bilinmeyen Cihaz';
    try {
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceName = iosInfo.name;
      } else if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceName = androidInfo.model;
      }
    } catch (e) {
      deviceName = 'Cihaz Bilgisi Alınamadı';
    }
    return deviceName;
  }

  // Asenkron olarak sunucuya login isteği gönder
  Future<void> _login() async {
    String username = _usernameController.text;
    String password = _passwordController.text;

    // SHA256 ile şifreyi hashle
    String hashedPassword = _hashPassword(password);

    // Cihaz bilgisini al
    String deviceName = await _getDeviceInfo();

    // HTTP POST isteği
    final response = await http.post(
      Uri.parse('http://$Url:5001/login'), // Sunucu adresinizi buraya yazın
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': hashedPassword,
        'device': deviceName, // Cihaz bilgisini ekle
      }),
    );

    // Sunucudan gelen cevaba göre işlem yap
    if (response.statusCode == 201) {
      // Token'ı kaydet
      final responseData = json.decode(response.body);
      await _secureStorage.write(key: 'auth_token', value: responseData['token']);

      // Ana ekrana yönlendir
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      final responseData = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(responseData['error'])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Güvercin logosu
              Image.asset(
                'lib/img/Logo.png',  // Burada logonun yolunu belirtin
                height: 150,
                width: 150,
              ),
              const SizedBox(height: 30),

              // Kullanıcı adı ve şifre formu
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  maxWidth: 600,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Kullanıcı adı
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          prefixIcon: Icon(Icons.person, size: 30),
                          labelStyle: TextStyle(fontSize: 20),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Kullanıcı adı boş olamaz!';
                          }
                          return null;
                        },
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 20),

                      // Şifre
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: Icon(Icons.lock, size: 30),
                          labelStyle: TextStyle(fontSize: 20),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre boş olamaz!';
                          }
                          return null;
                        },
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 20),

                      // Giriş butonu
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _login(); // Giriş işlemi başlat
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Giriş Yap', style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
