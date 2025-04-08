import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatPage extends StatefulWidget {
  final String senderUsername;
  final String receiverUsername;

  ChatPage({required this.senderUsername, required this.receiverUsername});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Map<String, dynamic>> messages = [];
  final TextEditingController _controller = TextEditingController();
  late WebSocketChannel _channel;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _getMessages();
  }

  Future<void> _getMessages() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://98.66.234.35:5004/get_messages/${widget.senderUsername}/${widget.receiverUsername}'),
        // Uri.parse(
        //     'http://192.168.77.46:5004/get_messages/${widget.senderUsername}/${widget.receiverUsername}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API Response: $data');

        if (data is List) {
          setState(() {
            messages.clear(); // Önce listeyi temizleyelim ki tekrar eklenmesin
            for (var msg in data) {
              messages.add({
                'message_id': msg['message_id'],
                'text': msg['message'],
                'isSent': msg['sender'] == widget.senderUsername,
                'timestamp': DateTime.fromMillisecondsSinceEpoch(
                    msg['timestamp'] * 1000),
              });
            }
          });
        }
      } else {
        print('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Request error: $e');
    }
  }

  void _connectWebSocket() {
    final url = 'ws://98.66.234.35:5004/ws/${widget.senderUsername}';
    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel.stream.listen((message) {
      final msg = jsonDecode(message);

      print("Gelen mesaj: $msg");

      setState(() {
        messages.add({
          'message_id': msg['message_id'],
          'text': msg['message'],
          'isSent': msg['sender'] == widget.senderUsername,
          'timestamp': msg['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] * 1000)
              : DateTime.now(), // Eğer timestamp null ise şimdiki zamanı kullan
        });
      });
    }, onError: (error) {
      print('WebSocket Hatası: $error');
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final messageData = {
      'message': text,
      'sender': widget.senderUsername,
      'receiver': widget.receiverUsername,
    };

    _channel.sink.add(jsonEncode(messageData));

    setState(() {
      messages.add({
        'text': text,
        'isSent': true,
        'timestamp': DateTime.now(),
      });
    });

    _controller.clear();
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
                widget.receiverUsername,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
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
    Key? key,
    required this.text,
    required this.isSent,
    required this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
          decoration: BoxDecoration(
            color: isSent ? Colors.blueAccent : Colors.grey[200],
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Column(
            crossAxisAlignment:
                isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isSent ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 5.0),
              Text(
                '${timestamp.hour}:${timestamp.minute}',
                style: TextStyle(
                  color: isSent ? Colors.white70 : Colors.black45,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
