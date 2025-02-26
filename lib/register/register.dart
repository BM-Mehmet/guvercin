import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guvercin/diffie_hellman/diffie_hellman.dart';
import 'package:guvercin/login/login.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/sha256.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Güvercin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RegisterScreen(),
    );
  }
}

class FirebaseApi {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<String?> initNotifications() async {
    final fcmToken = await _firebaseMessaging.getToken();
    print("FCM Token: $fcmToken");
    return fcmToken;
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? fcmToken;

  @override
  void initState() {
    super.initState();
    _generateUniqueUsername();
    _initFCM();
  }

  // Rastgele benzersiz kullanıcı adı oluşturma fonksiyonu
  void _generateUniqueUsername() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var random = Random();
    var username =
        List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();

    // Kullanıcı adını TextField'e yansıt
    setState(() {
      _usernameController.text = username;
    });
  }

  // Firebase FCM token alma
  Future<void> _initFCM() async {
    FirebaseApi firebaseApi = FirebaseApi();
    fcmToken = await firebaseApi.initNotifications();
  }

  // Diffie-Hellman anahtarlarını oluşturma fonksiyonu
  Future<void> _generateKeys() async {
    const storage = FlutterSecureStorage();
    final dh = DiffieHellman();
    final base = BigInt.from(2); // Base (g) değeri
    const primeHex =
        'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74C7A603AF3C704A8BB6A6E6E34F2A1F91EED6E9F75EECE6EFB134ABF38D49B582053246AC3E98C233569134D1B91A210060B42F3D722531AA5FE3E428BF29B9A1B5EE25A1A0171732C21D6CA4524F9AF6B52E8A4BB142BD02FD9F96E399EF906F27AF6A9A2854C4C520E5208E8AB603ED897CC4FD914F7A73D6FF3DF9E9459DC95A8E63A11AC83288F51EE5B6D14D2FE94F736AEBB9B529177BFB9F72D34005CB11D4AE7B8A8B768EA10F1FE93BB3A94D453C5471B571E44C2E98D858F265FE2CF2B5EE6A53E25B9F6D876AA2B18C07F7A0D57C91E';
    final prime = BigInt.parse(primeHex, radix: 16);

    // Private ve Public Key oluşturma
    final privateKey = dh.getPrivateKey();
    final publicKey = dh.generatePublicKey(base, prime);

    // Flutter Secure Storage'e anahtarları kaydetme
    await storage.write(key: '_privateKey', value: privateKey.toString());
    await storage.write(key: '_publicKey', value: publicKey.toString());
  }

  // Şifre doğrulama fonksiyonu
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre boş olamaz!';
    }
    if (value != _confirmPasswordController.text) {
      return 'Şifreler uyuşmuyor!';
    }
    return null;
  }

  // SHA-256 ile şifre hashleme
  String _hashPassword(String password) {
    final utf8Key = utf8.encode(password);
    final sha256 = SHA256Digest();
    final hash = sha256.process(utf8Key);
    return base64.encode(hash);
  }

  // Kayıt fonksiyonu
  Future<void> _registerUser() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    // Şifreyi hashleyelim
    final hashedPassword = _hashPassword(password);

    // Diffie-Hellman anahtarlarını kontrol et ve oluştur
    const storage = FlutterSecureStorage();
    String? privateKey = await storage.read(key: '_privateKey');
    String? publicKey = await storage.read(key: '_publicKey');

    if (privateKey == null || publicKey == null) {
      await _generateKeys();
      privateKey = await storage.read(key: '_privateKey');
      publicKey = await storage.read(key: '_publicKey');
    }
    // Sunucuya HTTP POST isteği gönderme
    final response = await http.post(
      Uri.parse('http://192.168.126.46:5000/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': hashedPassword,
        'fcm': fcmToken,
        'public_key': publicKey, // Public key sunucuya gönderiliyor
      }),
    );

    if (response.statusCode == 201) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } else {
      final responseData = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(responseData['message'])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'lib/img/Logo.png',
                height: 150,
                width: 150,
              ),
              const SizedBox(height: 20),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          prefixIcon: Icon(Icons.person, size: 30),
                          labelStyle: TextStyle(fontSize: 20),
                        ),
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: Icon(Icons.lock, size: 30),
                          labelStyle: TextStyle(fontSize: 20),
                        ),
                        validator: (value) {
                          return _validatePassword(value);
                        },
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Şifreyi Tekrarla',
                          prefixIcon: Icon(Icons.lock, size: 30),
                          labelStyle: TextStyle(fontSize: 20),
                        ),
                        validator: (value) {
                          return _validatePassword(value);
                        },
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _registerUser();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Kaydol',
                          style: TextStyle(fontSize: 18),
                        ),
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
