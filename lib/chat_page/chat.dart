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
  final ScrollController _scrollController = ScrollController();
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _fetchMessages();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    super.dispose();
  }

  void _connectWebSocket() {
  // Eğer daha önce bağlantı varsa kapat
  _channel?.sink.close();

  final wsUrl = 'ws://172.30.226.235:5004/ws/${widget.senderUsername}';
  _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

  _channel!.stream.listen(
    (event) {
      if (!mounted) return;

      final data = jsonDecode(event);

      DateTime timestamp;
      try {
        timestamp = DateTime.parse(data['timestamp'].toString());
      } catch (e) {
        timestamp = DateTime.now();
      }

      // Yeni gelen mesajı ekle
      setState(() {
         int? deliveryStatus; // Varsayılan durum "sent"
        // Veritabanındaki teslimat durumu (0 veya 1) ile uyumlu şekilde kontrol
        if (data['delivered'] == 0) {
          deliveryStatus = 0 ;
        } else if (data['delivered'] == 1) {  // Eğer "read" durumu varsa, veritabanında 2 olarak gösterilebilir.
          deliveryStatus = 1;
        }

        messages.add({
          'message_id': data['message_id']?.toString() ?? '',
          'text': _parseMessageContent(data),
          'isSent': false,
          'timestamp': timestamp,
          'delivered': deliveryStatus,
        });
      });

      // Yeni mesaj eklenince ekranı aşağı kaydır
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    },
    onError: (error) {
      debugPrint('WebSocket hatası: $error');
      _reconnectWebSocket();
    },
    onDone: () {
      debugPrint('WebSocket bağlantısı kapandı.');
      _reconnectWebSocket();
    },
    cancelOnError: true,
  );
}


  void _reconnectWebSocket() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      debugPrint('WebSocket yeniden bağlanıyor...');
      _connectWebSocket();
    });
  }

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
              'delivered': msg['delivered'] == 1,
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

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final message = {
      'sender': widget.senderUsername,
      'receiver': widget.receiverUsername,
      'message': text,
    };

    _channel?.sink.add(jsonEncode(message));

    setState(() {
      messages.add({
        'text': text,
        'isSent': true,
        'timestamp': DateTime.now(),
        'delivered': 0,
      });
    });

    _controller.clear();
    FocusScope.of(context).unfocus();
    _scrollToBottom();
  }

  Future<void> _deleteMessage(String messageId, int index) async {
    final uri = Uri.parse(
        'http://172.30.226.235:5004/delete_message/${widget.senderUsername}/$messageId');

    try {
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
    } catch (e) {
      debugPrint('Mesaj silme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sunucu hatası, mesaj silinemedi.')),
      );
    }
  }

  void _showDeleteDialog(String messageId, int index) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text("Mesajı Sil"),
        content: const Text("Bu mesajı silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _parseMessageContent(Map<String, dynamic> data) {
    final fileName = data['file_name'];
    if (fileName != null) {
      final lower = fileName.toString().toLowerCase();
      if (lower.endsWith('.m4a') ||
          lower.endsWith('.mp3') ||
          lower.endsWith('.wav') ||
          lower.endsWith('.ogg')) {
        return '[Ses Kaydı]';
      } else if (lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.bmp') ||
          lower.endsWith('.webp')) {
        return '[Fotoğraf]';
      } else {
        return '[Dosya: $fileName]';
      }
    }
    return data['message'] ?? '';
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
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final msg = messages[index];
                return MessageBubble(
                  text: msg['text'],
                  isSent: msg['isSent'],
                  timestamp: msg['timestamp'],
                  deliveryStatus: msg['delivered'] == 1
                      ? 1 : 0 , // Üç durum için doğru değeri döndürüyoruz

                  onLongPress: () {
                    if (msg['isSent'] &&
                        msg['message_id'] != null &&
                        msg['message_id'] != '') {
                      _showDeleteDialog(msg['message_id'], index);
                    }
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
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
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isSent;
  final DateTime timestamp;
  final int deliveryStatus; // "sent", "delivered", "read"
  final VoidCallback onLongPress;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isSent,
    required this.timestamp,
    required this.deliveryStatus,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(
                      fontSize: 12,
                      color: isSent ? Colors.white : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (isSent)
                    Icon(
                      _getDeliveryIcon(deliveryStatus),
                      size: 16,
                      color: _getDeliveryColor(deliveryStatus),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeliveryIcon(int status) {
    switch (status) {
      case 0:
        return Icons.done_all; // Gönderildi ve okundu
      case 1:
        return Icons.remove_red_eye; // Okundu
      default:
        return Icons.done; // Henüz gönderilmedi, sadece gönderildi
    }
  }

  Color _getDeliveryColor(int status) {
    switch (status) {
      case 0:
        return Colors.green; // Okundu veya teslim edildi
      case 1:
        return Colors.blue; // Okundu
      default:
        return Colors.white; // Henüz gönderilmedi
    }
  }
}
