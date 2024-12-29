import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Sessions extends StatefulWidget {
  const Sessions({super.key});

  @override
  _OpenSessionsPageState createState() => _OpenSessionsPageState();
}

class _OpenSessionsPageState extends State<Sessions> {
  bool _isLoading = true;
  List<dynamic> _sessions = [];

  // Aktif oturumları sunucudan çek
  Future<void> _fetchSessions() async {
    final response = await http.get(Uri.parse('http://192.168.77.249:5003/active-sessions'));

    if (response.statusCode == 200) {
      setState(() {
        _sessions = json.decode(response.body);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturumlar alınırken bir hata oluştu!')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSessions(); // Oturumları çek
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Açık Oturumlar'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Yükleniyor animasyonu
          : ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                var session = _sessions[index];
                return ListTile(
                  subtitle: Text('Cihaz: ${session['device']}'),
                );
              },
            ),
    );
  }
}
