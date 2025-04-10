import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatPage extends StatefulWidget {
  final String senderUsername;
  final String receiverUsername;

  const ChatPage({
    required this.senderUsername,
    required this.receiverUsername,
    super.key,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}
class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> messages = [];
  late WebSocketChannel _channel;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    final chatKey =
        '${widget.senderUsername}/${widget.receiverUsername}'; // Chat key formatı
    final uri = Uri.parse('http://98.66.234.35:5004/get_messages/$chatKey');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        setState(() {
          messages.clear();
          messages.addAll(data.map((msg) {
            return {
              'message_id': msg['message_id'],
              'text': msg['message'],
              'isSent': msg['sender'] == widget.senderUsername,
              'timestamp':
                  DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] * 1000),
            };
          }));
        });
      } else {
        debugPrint('Mesajlar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Hata oluştu: $e');
    }
  }

  void _connectWebSocket() {
    final wsUrl = 'ws://98.66.234.35:5004/ws/${widget.senderUsername}';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel.stream.listen((event) {
      final data = jsonDecode(event);
      if (data['sender'] == widget.receiverUsername ||
          data['sender'] == widget.senderUsername) {
        setState(() {
          messages.add({
            'message_id': data['message_id'],
            'text': data['message'],
            'isSent': data['sender'] == widget.senderUsername,
            'timestamp': DateTime.fromMillisecondsSinceEpoch(
              data['timestamp'] * 1000,
            ),
          });
        });
      }
    }, onError: (error) {
      debugPrint('WebSocket hatası: $error');
    });
  }

  Future<void> _deleteMessage(String messageId, int index) async {
    final uri = Uri.parse('http://98.66.234.35:5004/delete_message/${widget.senderUsername}/${widget.receiverUsername}/$messageId');
    final response = await http.delete(uri);
    if (response.statusCode == 200) {
      setState(() {
        messages.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj silinemedi.')),
      );
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final message = {
      'sender': widget.senderUsername,
      'receiver': widget.receiverUsername,
      'message': text,
    };

    _channel.sink.add(jsonEncode(message));

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
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  void _showDeleteDialog(String messageId, int index) {
    showDialog(
      context: context,
      barrierDismissible: true, // dışarı tıklayınca da kapanabilir
      builder: (_) => AlertDialog(
        title: const Text("Mesajı Sil"),
        content: const Text("Bu mesajı silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop(); // BU önemli
            },
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop();
              await _deleteMessage(messageId, index);
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvercin'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                widget.receiverUsername,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final msg = messages[index];
                return MessageBubble(
                  text: msg['text'],
                  isSent: msg['isSent'],
                  timestamp: msg['timestamp'],
                  onLongPress: () =>
                      _showDeleteDialog(msg['message_id'] ?? '', index),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isSent;
  final DateTime timestamp;
  final VoidCallback onLongPress;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isSent,
    required this.timestamp,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSent ? Colors.blueAccent : Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment:
                isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isSent ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: isSent ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
