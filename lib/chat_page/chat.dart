import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ChatPage extends StatefulWidget {
  final String senderUsername;
  final String receiverUsername;

  const ChatPage({
    super.key,
    required this.senderUsername,
    required this.receiverUsername,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Map<String, dynamic>> messages = [];
  final TextEditingController _controller = TextEditingController();
  late Timer _messageTimer;

  @override
  void initState() {
    super.initState();
    _getMessages(); // İlk mesajları al
    _messageTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _getMessages(); // Her 5 saniyede bir yeni mesajları al
    });
  }

  @override
  void dispose() {
    _messageTimer.cancel(); // Timer'ı durdur
    super.dispose();
  }

  // Mesajları sunucudan almak için API isteği
  Future<void> _getMessages() async {
    final response = await http.get(
      Uri.parse('http://192.168.210.249:5006/get_messages/${widget.senderUsername}/${widget.receiverUsername}'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        // Yeni mesajları ekleyelim (eski mesajları sıfırlayalım)
        messages = data.map((msg) {
          return {
            'text': msg['message'],  // Mesajın metni
            'isSent': msg['sender'] == widget.senderUsername,  // Mesajın gönderilip gönderilmediği
            'timestamp': DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] * 1000), // Zaman damgası
          };
        }).toList();
      });
    } else {
      print('Mesajlar alınamadı');
    }
  }

  // Mesaj gönderme fonksiyonu
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final response = await http.post(
      Uri.parse('http://192.168.210.249:5006/send_message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': text,
        'sender': widget.senderUsername,  // Sender, widget'tan alınıyor
        'receiver': widget.receiverUsername,  // Receiver, widget'tan alınıyor
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        messages.add({
          'text': text,
          'isSent': true,
          'timestamp': DateTime.now(),
        });
      });
      _controller.clear();
    } else {
      print('Mesaj gönderilemedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Güvercin Sohbeti'),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                widget.receiverUsername.isNotEmpty
                    ? widget.receiverUsername
                    : 'Yükleniyor...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  return MessageBubble(
                    text: message['text'],
                    isSent: message['isSent'],
                    timestamp: message['timestamp'],
                  );
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => sendMessage(_controller.text),
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isSent;
  final DateTime timestamp;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isSent,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final time =
        '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: isSent ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Column(
          crossAxisAlignment:
              isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4.0),
            Text(
              text,
              style: TextStyle(
                color: isSent ? Colors.white : Colors.black,
                fontSize: 16.0,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              time,
              style: TextStyle(
                color: isSent ? Colors.white70 : Colors.black54,
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
