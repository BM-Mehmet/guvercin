import 'package:flutter/material.dart';
import 'package:guvercin/home/home.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'dart:convert'; // String'i byte dizisine çevirmek için gerekli
import 'package:http/http.dart' as http;

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
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // SHA256 ile string'i hashle
  String _hashPassword(String password) {
    final utf8Key = utf8.encode(password); // Şifreyi byte dizisine dönüştür
    final sha256 = SHA256Digest(); // SHA256 hash algoritması
    final hash = sha256.process(utf8Key); // Hashleme işlemi
    return base64.encode(hash); // Base64 formatında döndür
  }

  // Asenkron olarak sunucuya login isteği gönder
  Future<void> _login() async {
    String username = _usernameController.text;
    String password = _passwordController.text;

    // SHA256 ile şifreyi hashle
    String hashedPassword = _hashPassword(password);

    // HTTP POST isteği
    final response = await http.post(
      Uri.parse('http://192.168.220.249:5001/login'), // Sunucu adresinizi buraya yazın
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': hashedPassword,
      }),
    );

    // Sunucudan gelen cevaba göre işlem yap
    if (response.statusCode == 201) {
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
