import 'package:flutter/material.dart';
import 'package:guvercin/chat_page/chat.dart';
import 'package:guvercin/home/home.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kullanıcı Kontrol',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const UserCheckPage(),
    );
  }
}

class UserCheckPage extends StatefulWidget {
  const UserCheckPage({super.key});

  @override
  _UserCheckPageState createState() => _UserCheckPageState();
}

class _UserCheckPageState extends State<UserCheckPage> {
  final TextEditingController _controller = TextEditingController();
  String _message = '';
  bool _userExists = false;
  String _username = '';

  Future<void> checkUser(String username) async {
    final response = await http.get(
      Uri.parse('http://98.66.234.35:5003/check_user?username=$username'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        _message = data['message'] ?? 'Veri alınamadı';
        _userExists = data['exists'] ?? false;
        _username = username;
      });
    } else {
      setState(() {
        _message = 'Böyle bir kullanıcı yok';
        _userExists = false;
        _username = '';
      });
    }
  }

  Future<String?> getUsernameFromToken() async {
    String? token = await _secureStorage.read(key: 'auth_token');
    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      return decodedToken['username'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => const HomePage()), // Ana sayfaya yönlendir
          (route) => false, // Geri dönüş yığınındaki tüm sayfaları kaldır
        );
        return false; // Varsayılan geri tuşu davranışını engelle
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kullanıcı Kontrol'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final username = _controller.text.trim();
                  if (username.isNotEmpty) {
                    await checkUser(username);
                  }
                },
                child: const Text('Kontrol Et'),
              ),
              const SizedBox(height: 20),
              Text(_message, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              if (_userExists)
                Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blueAccent,
                      child: Text(
                        _username.isNotEmpty ? _username[0].toUpperCase() : '',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        String? senderUsername = await getUsernameFromToken();
                        if (senderUsername != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                senderUsername: senderUsername,
                                receiverUsername: _username,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Sohbete Başla'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
