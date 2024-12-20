import 'package:flutter/material.dart';
import 'package:guvercin/chat_page/chat.dart';
import 'package:guvercin/settings/settings_page.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvercin'),
        actions: const [],
      ),
      body: Column(
        children: [
          // Sohbetler Listesi
          Expanded(
            child: ListView.builder(
              itemCount: 2, // Örnek sohbet sayısı
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      'U$index',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text('User $index'),
                  onTap: () {
                    // Sohbete girme işlemi
                  },
                );
              },
            ),
          ),
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
                  MaterialPageRoute(
                      builder: (context) => const SettingsPage()),
                );
              },
            ),
            // Arama butonunu burada, altta yerleştiriyoruz
            IconButton(
              icon: const Icon(Icons.search, size: 30),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                  }
                });
              },
            ),
            // Yeni mesaj başlatma butonu
            IconButton(
              icon: const Icon(Icons.message, size: 30),
              onPressed: () {
                        Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ChatPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
