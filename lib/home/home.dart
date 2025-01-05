import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guvercin/search/search.dart';
import 'package:guvercin/settings/settings_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Page',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomePage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String? _username;
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvercin'),
        actions: const [],
      ),
      body: Column(
        children: [
          // Kullanıcı adı ve sohbet listesi
          if (_username != null) ...[
            Text('Hoşgeldiniz, $_username'),
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
                              chat['receiver'][0],
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(chat['receiver']),
                          onTap: () {
                            // Sohbete girme işlemi
                          },
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
          // Arama kutusunu burada yerleştiriyoruz
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Arama...',
                  hintStyle: TextStyle(color: Colors.black),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.black),
              ),
            ),
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

  // Sunucudan sohbetleri al
  Future<List<Map<String, dynamic>>> _fetchChats() async {
    String? token = await _secureStorage.read(key: 'auth_token');
    if (token == null || _username == null) return [];

    var response = await http.get(
      Uri.parse('http://192.168.210.249:5007/chats/$_username'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Sohbetler alınamadı');
    }
  }
}
