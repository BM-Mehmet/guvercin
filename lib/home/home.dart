import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guvercin/chat_page/chat.dart';
import 'package:guvercin/search/search.dart';
import 'package:guvercin/settings/settings_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomePage> {
  // final bool _isSearching = false;
  // final TextEditingController _searchController = TextEditingController();
  String? _username;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _getUsernameFromToken();
  }

  // JWT token'dan username'i al
  Future<void> _getUsernameFromToken() async {
    String? token = await _secureStorage.read(key: 'auth_token');
    if (token != null) {
      // Token'dan username'i çözümleyelim (payload kısmı)
      var decodedToken = _decodeJWT(token);
      setState(() {
        _username = decodedToken['username'];
      });
    }
  }

  // JWT çözümleme işlemi
  Map<String, dynamic> _decodeJWT(String token) {
    final parts = token.split('.');
    final payload = base64Url.decode(base64Url.normalize(parts[1]));
    return json.decode(utf8.decode(payload));
  }

  // Sunucudan sohbetleri al
  Future<List<Map<String, dynamic>>> _fetchChats() async {
    String? token = await _secureStorage.read(key: 'auth_token');
    if (token == null || _username == null) return [];

    var response = await http.get(
      Uri.parse('http://98.66.234.35:5002/chats/$_username'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      var jsonData = json.decode(response.body);

      if (jsonData is Map<String, dynamic> && jsonData.containsKey('users')) {
        List<dynamic> users = jsonData['users'];
        return users
            .map((username) => {'receiver': username}) // Listeye dönüştür
            .toList();
      } else {
        throw Exception('Geçersiz API formatı');
      }
    } else {
      throw Exception('Sohbetler alınamadı');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvercin'),
      ),
      body: Column(
        children: [
          if (_username != null) ...[
            GestureDetector(
              onTap: () {
                // Kullanıcı adına tıklanınca yönlendirme yapılır
                print("Kullanıcı adı tıklandı: $_username");
                // Chat sayfasına yönlendirme
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      senderUsername: _username!,
                      receiverUsername: _username!,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hoşgeldiniz, $_username',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchChats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Hata: ${snapshot.error}'));
                  } else if (snapshot.data == null || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Henüz sohbet yok.'));
                  } else {
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        var chat = snapshot.data![index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.blueAccent,
                            child: Text(
                              chat['receiver'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(chat['receiver']),
                          onTap: () {
                            // Sohbet sayfasına yönlendirme
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  senderUsername: _username!,
                                  receiverUsername: chat['receiver'],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
       bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.settings, size: 30),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            // Yeni mesaj başlatma butonu
            IconButton(
              icon: const Icon(Icons.message, size: 30),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
