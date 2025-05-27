import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';

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
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  WebSocketChannel? _channel;
  File? _pickedFile;
  String? _pickedFileName;

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
    _scrollController.dispose();
    super.dispose();
  }

  void _connectWebSocket() {
    final wsUrl = 'ws://172.30.226.235:5004/ws/${widget.senderUsername}';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen((event) {
      final data = jsonDecode(event);
      final messageId = data['message_id'];
      DateTime time =
          DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now();
      setState(() {
        _messages.add({
          'message_id': messageId,
          'text': _parseContent(data),
          'isSent': false,
          'timestamp': time,
          'delivered': data['delivered'],
          'file_name': data['file_name'],
        });
      });
      _markAsSeen(messageId);
      _scrollToBottom();
    }, onError: (err) {
      debugPrint('WebSocket Error: $err');
      _reconnect();
    }, onDone: () {
      debugPrint('WebSocket Closed');
      _reconnect();
    });
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _connectWebSocket();
    });
  }

  Future<void> _fetchMessages() async {
    final url =
        'http://172.30.226.235:5004/get_messages/${widget.senderUsername}/${widget.receiverUsername}';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _messages.clear();
          _messages.addAll(data.map((msg) {
            return {
              'message_id': msg['id'],
              'text': msg['type'] == 'text'
                  ? msg['content']
                  : '[Dosya: ${msg['file_name']}]',
              'isSent': msg['sender'] == widget.senderUsername,
              'timestamp':
                  DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] * 1000),
              'delivered': msg['delivered'] == 0 ? 1 : 0,
              'file_name': msg['file_name'],
            };
          }));
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Mesaj çekme hatası: $e');
    }
  }

  Future<void> _markAsSeen(String messageId) async {
    final url = 'http://172.30.226.235:5004/ws/${widget.senderUsername}/seen';
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message_id': messageId,
          'receiver': widget.receiverUsername,
        }),
      );
      if (res.statusCode == 200) {
        debugPrint('Mesaj okundu olarak işaretlendi.');
      } else {
        debugPrint('mark_seen başarısız: ${res.body}');
      }
    } catch (e) {
      debugPrint('mark_seen hatası: $e');
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final msg = {
      'sender': widget.senderUsername,
      'receiver': widget.receiverUsername,
      'message': text,
    };
    _channel?.sink.add(jsonEncode(msg));
    setState(() {
      _messages.add({
        'message_id': '',
        'text': text,
        'isSent': true,
        'timestamp': DateTime.now(),
        'delivered': 0,
      });
    });
    _controller.clear();
    _scrollToBottom();
  }

  Future<void> _sendFile(File file) async {
    final ws = WebSocketChannel.connect(
      Uri.parse('ws://172.30.226.235:5004/ws/${widget.senderUsername}'),
    );

    final fileName = path.basename(file.path);
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

    final fileMetadata = jsonEncode({
      'sender': widget.senderUsername,
      'receiver': widget.receiverUsername,
      'type': 'file',
      'file_name': fileName,
      'mime_type': mimeType,
      'message': null,
      'file_url': 'incoming',
    });

    ws.sink.add(fileMetadata);
    final fileBytes = await file.readAsBytes();
    ws.sink.add(fileBytes);
    ws.sink.close();
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles();
    if (picked != null && picked.files.single.path != null) {
      setState(() {
        _pickedFile = File(picked.files.single.path!);
        _pickedFileName = picked.files.single.name;
      });
    }
  }

  Future<void> _downloadAndOpenFile(String username, String fileName) async {
    try {
      final url =
          'http://172.30.226.235:5004/download_file/$username/$fileName';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        await OpenFile.open(file.path);
      } else {
        debugPrint('Dosya indirilemedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Dosya indirme hatası: $e');
    }
  }

  String _parseContent(Map<String, dynamic> data) {
    final file = data['file_name']?.toString().toLowerCase();
    if (file != null) {
      if (file.endsWith('.mp3') || file.endsWith('.wav')) return '[Ses Kaydı]';
      if (file.endsWith('.jpg') || file.endsWith('.png')) return '[Fotoğraf]';
      return '[Dosya: ${data['file_name']}]';
    }
    return data['message'] ?? '';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _deleteMessage(String messageId, int index) async {
    final uri = Uri.parse(
        'http://172.30.226.235:5004/delete_message/${widget.senderUsername}/$messageId');
    final res = await http.delete(uri);
    if (res.statusCode == 200) {
      setState(() => _messages.removeAt(index));
    }
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          if (_pickedFile != null && _pickedFileName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pickedFileName!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _pickedFile = null;
                        _pickedFileName = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickFile),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: 'Mesaj yaz...'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  if (_pickedFile != null) {
                    _sendFile(_pickedFile!);
                    setState(() {
                      _pickedFile = null;
                      _pickedFileName = null;
                    });
                  } else {
                    _sendMessage();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isSent = msg['isSent'] as bool;
    final alignment = isSent ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isSent ? Colors.blue[100] : Colors.grey[300];
    const textColor = Colors.black;
    final timestamp = msg['timestamp'] as DateTime;
    final delivered = msg['delivered'] ?? 0;

    Icon? statusIcon;
    if (isSent) {
      statusIcon = delivered == 1
          ? const Icon(Icons.done_all, size: 16, color: Colors.blue)
          : const Icon(Icons.done, size: 16, color: Colors.grey);
    }

    final isFile = msg['file_name'] != null;

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: isFile
            ? () => _downloadAndOpenFile(widget.senderUsername, msg['file_name'])
            : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment:
                isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(msg['text'], style: const TextStyle(color: textColor)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                  if (statusIcon != null) ...[
                    const SizedBox(width: 4),
                    statusIcon,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.senderUsername} - ${widget.receiverUsername}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (ctx, index) {
                final msg = _messages[index];
                return Dismissible(
                  key: Key(msg['message_id'].toString()),
                  onDismissed: (_) =>
                      _deleteMessage(msg['message_id'], index),
                  child: _buildMessageBubble(msg),
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }
}
