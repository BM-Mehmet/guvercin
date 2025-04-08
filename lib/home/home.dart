import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guvercin/chat_page/chat.dart';
import 'package:guvercin/search/search.dart';
import 'package:guvercin/settings/settings_page.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomePage> {
  String? _username;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late WebSocketChannel _channel;
  List<String> _chatUsers = [];
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _getUsernameAndInitWebSocket();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _channel.sink.close();
    super.dispose();
  }

  Future<void> _getUsernameAndInitWebSocket() async {
    String? token = await _secureStorage.read(key: 'auth_token');
    if (token != null) {
      var decodedToken = _decodeJWT(token);
      _username = decodedToken['username'];

      if (_username != null) {
        await _fetchChats(); // Başlangıçta sohbettekileri çek
        _initWebSocket();     // WebSocket bağlantısı kur
        setState(() {});
      }
    }
  }

  Map<String, dynamic> _decodeJWT(String token) {
    final parts = token.split('.');
    final payload = base64Url.decode(base64Url.normalize(parts[1]));
    return json.decode(utf8.decode(payload));
  }

  Future<void> _fetchChats() async {
    String? token = await _secureStorage.read(key: 'auth_token');
    if (token == null || _username == null) return;

    final response = await http.get(
      Uri.parse('http://98.66.234.35:5002/chats/$_username'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData is Map<String, dynamic> && jsonData.containsKey('users')) {
        final users = List<String>.from(jsonData['users']);
        setState(() {
          _chatUsers = users;
        });
      }
    }
  }

  void _initWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://98.66.234.35:5002/ws/$_username'),
    );

    _wsSubscription = _channel.stream.listen(
      (data) {
        final decoded = json.decode(data);
        if (decoded['type'] == 'new_message') {
          final sender = decoded['from'];
          if (!_chatUsers.contains(sender)) {
            setState(() {
              _chatUsers.insert(0, sender); // Yeni gelen kullanıcı en üste
            });
          }
        }
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
      },
      onDone: () {
        debugPrint('WebSocket closed');
        // Otomatik yeniden bağlanma istersen buraya eklenebilir
      },
    );
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
              child: _chatUsers.isEmpty
                  ? const Center(child: Text('Henüz sohbet yok.'))
                  : ListView.builder(
                      itemCount: _chatUsers.length,
                      itemBuilder: (context, index) {
                        final receiver = _chatUsers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.blueAccent,
                            child: Text(
                              receiver[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(receiver),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  senderUsername: _username!,
                                  receiverUsername: receiver,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ]
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
