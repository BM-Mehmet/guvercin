import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(seachPage());
}

class seachPage extends StatelessWidget {
  const seachPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kullanıcı Kontrol',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: UserCheckPage(),
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

  // Kullanıcı adı kontrol fonksiyonu
  Future<void> checkUser(String username) async {
    final response = await http.get(
      Uri.parse('http://192.168.210.249:5005/check_user?username=$username'),
    );

    if (response.statusCode == 200) {
      setState(() {
        _message = json.decode(response.body)['message'];
      });
    } else {
      setState(() {
        _message = json.decode(response.body)['message'];
      });
    }
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
              onPressed: () {
                final username = _controller.text.trim();
                if (username.isNotEmpty) {
                  checkUser(username);
                }
              },
              child: const Text('Kontrol Et'),
            ),
            const SizedBox(height: 20),
            Text(_message, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
