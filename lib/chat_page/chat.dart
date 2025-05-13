import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

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
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  File? _recordedFile;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _fetchMessages();
    _initAudio();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    super.dispose();
  }

  Future<void> _initAudio() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    await _recorder!.openRecorder();
    await _player!.openPlayer();
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('Mikrofon izni reddedildi.');
    }
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

    // Dosya bilgilerini içeren JSON
    final fileMetadata = jsonEncode({
      'sender': widget.senderUsername,
      'receiver': widget.receiverUsername,
      'type': 'file',
      'file_name': fileName,
      'mime_type': mimeType,
      'message': null,
      'file_url': 'incoming', // dosyanın geleceğini belirtmek için
    });

    ws.sink.add(fileMetadata);

    // Dosyanın ham içeriğini byte olarak gönder
    final fileBytes = await file.readAsBytes();
    ws.sink.add(fileBytes);

    ws.sink.close(); // Bağlantıyı kapatabilirsiniz veya açık tutabilirsiniz
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles();
    if (picked != null && picked.files.single.path != null) {
      await _sendFile(File(picked.files.single.path!));
    }
  }

  Future<void> _startStopRecording() async {
    if (_isRecording) {
      final path = await _recorder!.stopRecorder();
      _recordedFile = File(path!);
      setState(() => _isRecording = false);
      _showAudioDialog();
    } else {
      final dir = await getApplicationDocumentsDirectory();
      await _recorder!.startRecorder(toFile: '${dir.path}/audio.m4a');
      setState(() => _isRecording = true);
    }
  }

  void _showAudioDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ses Kaydı'),
        content: const Text('Ses kaydı gönderilsin mi?'),
        actions: [
          TextButton(
            child: const Text('Dinle'),
            onPressed: () => _player?.startPlayer(fromURI: _recordedFile!.path),
          ),
          TextButton(
            child: const Text('Gönder'),
            onPressed: () {
              Navigator.pop(context);
              _sendFile(_recordedFile!);
            },
          ),
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String messageId, int index) async {
    final uri = Uri.parse(
        'http://172.30.226.235:5004/delete_message/${widget.senderUsername}/$messageId');
    final res = await http.delete(uri);
    if (res.statusCode == 200) {
      setState(() => _messages.removeAt(index));
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

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickFile),
          IconButton(
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              onPressed: _startStopRecording),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: 'Mesaj yaz...'),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
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
    final deliveredcheck = msg['delivered'];
    int delivered = 0;
    if (deliveredcheck == null) {

    } else {
        delivered = deliveredcheck as int;
    }

    Icon? statusIcon;
    if (isSent) {
      if (delivered == 1) {
        statusIcon = const Icon(Icons.done_all, size: 16, color: Colors.blue);
      } else {
        statusIcon = const Icon(Icons.done, size: 16, color: Colors.grey);
      }
    }

    return Align(
      alignment: alignment,
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
                        Text(
              msg['text'],
              style: const TextStyle(color: textColor),
            ),
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
                  onDismissed: (_) => _deleteMessage(msg['message_id'], index),
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
