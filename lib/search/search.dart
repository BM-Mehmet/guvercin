import 'package:flutter/material.dart';
import 'package:guvercin/chat_page/chat.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';  // JWT token çözümlemek için ekliyoruz
import 'package:flutter_secure_storage/flutter_secure_storage.dart';  // Güvenli depolama için ekliyoruz

// Güvenli depolama için _secureStorage değişkenini tanımlıyoruz
final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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
  bool _userExists = false;  // Kullanıcı mevcut olup olmadığını tutacak değişken
  String _username = '';  // Kullanıcı adını tutacak değişken

  // Kullanıcı adı kontrol fonksiyonu
  Future<void> checkUser(String username) async {
    final response = await http.get(
      Uri.parse('http://192.168.210.249:5005/check_user?username=$username'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      setState(() {
        _message = data['message'] ?? 'Veri alınamadı';  // Sunucudan gelen mesajı kullanıyoruz
        _userExists = data['exists'] ?? false;  // Kullanıcı var mı kontrolü
        _username = username;  // Kullanıcı adını alıyoruz
      });
    } else {
      setState(() {
        _message = 'Böyle bir kullanıcı yok';  // Sunucudan hata dönerse
        _userExists = false;  // Hata durumunda kullanıcı yok kabul edelim
        _username = '';  // Kullanıcı adı yok
      });
    }
  }

  // JWT token'ından username almak için yardımcı fonksiyon
  Future<String?> getUsernameFromToken() async {
    String? token = await _secureStorage.read(key: 'auth_token');  // Güvenli depolamadan token'ı alıyoruz
    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);  // JWT token'ını çözümlüyoruz
      return decodedToken['username'];  // username parametresini döndürüyoruz
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  await checkUser(username);  // Kullanıcıyı kontrol ediyoruz
                }
              },
              child: const Text('Kontrol Et'),
            ),
            const SizedBox(height: 20),
            Text(_message, style: const TextStyle(fontSize: 18)),  // Sunucudan gelen mesajı gösteriyoruz
            const SizedBox(height: 20),

            // Kullanıcı varsa avatar ve sohbet sayfasına yönlendir
            if (_userExists)
              Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      _username.isNotEmpty
                          ? _username[0].toUpperCase()  // Kullanıcı adının ilk harfi
                          : '',
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      // JWT token'ından senderUsername'ı alıyoruz
                      String? senderUsername = await getUsernameFromToken();
                      if (senderUsername != null) {
                        // Sohbete geçiş
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              senderUsername: senderUsername,  // Sender kullanıcı adı
                              receiverUsername: _username,  // Alıcı kullanıcı adı
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
    );
  }
}
