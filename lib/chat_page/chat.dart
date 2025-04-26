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

  // Mesajları backend API'den çekme
  Future<void> _fetchMessages() async {
    final uri = Uri.parse(
      'http://172.30.226.235:5004/get_messages/${widget.senderUsername}/${widget.receiverUsername}',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          messages.clear();
          messages.addAll(data.map((msg) {
            final messageType = msg['type']?.toString() ?? 'text';
            final content = msg['content']?.toString() ?? '';
            final fileName = msg['file_name']?.toString() ?? '';

            return {
              'message_id': msg['id'].toString(),
              'text': messageType == 'text' ? content : '[Dosya: $fileName]',
              'isSent': msg['sender']?.toString() == widget.senderUsername,
              'timestamp': DateTime.fromMillisecondsSinceEpoch(
                  (msg['timestamp'] as int) * 1000),
            };
          }));
        });
      } else {
        debugPrint('Mesajlar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Mesaj çekilirken hata: $e');
    }
  }

  // WebSocket bağlantısı kurma
  void _connectWebSocket() {
    final wsUrl = 'ws://172.30.226.235:5004/ws/${widget.senderUsername}';

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel.stream.listen((event) {
      final data = jsonDecode(event);
      if (data['sender'] == widget.receiverUsername) {
        setState(() {
          messages.add({
            'message_id': data['id'].toString(),
            'text': data['type'] == 'text'
                ? data['content']
                : '[Dosya: ${data['file_name']}]',
            'isSent': false,
            'timestamp': DateTime.parse(data['timestamp']),
          });
        });
      }
    }, onError: (error) {
      debugPrint('WebSocket hatası: $error');
    });
  }

  // Mesaj silme işlemi
  Future<void> _deleteMessage(String messageId, int index) async {
    final uri = Uri.parse(
        'http://172.30.226.235:5004/delete_message/${widget.senderUsername}/${messageId}');
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

  // Mesaj gönderme işlemi
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

  // Silme onayı için dialog gösterme
  void _showDeleteDialog(String messageId, int index) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text("Mesajı Sil"),
        content: const Text("Bu mesajı silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () {
              // AlertDialog'u kapat
              Navigator.of(context, rootNavigator: true)
                  .pop(); // rootNavigator: true parametresi, dialogu doğru şekilde kapatır
            },
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () async {
             Navigator.of(context, rootNavigator: true)
                  .pop(); // 
              await _deleteMessage(messageId, index);
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverUsername),
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
                      _showDeleteDialog(msg['message_id'], index),
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
