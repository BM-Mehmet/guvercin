import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:guvercin/diffie_hellman/diffie_hellman.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';
import 'package:guvercin/env.dart';

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
  List<Map<String, dynamic>> _messages = [];

  WebSocketChannel? _channel;
  File? _pickedFile;
  String? _pickedFileName;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _fetchMessages();
    _getPublicKey();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

 
void _getPublicKey() async {
  final keyUrl = 'http://$Url:5004/public_key/${widget.receiverUsername}';
  String? publicKeyHex;
  String? username;

  try {
    final response = await http.get(Uri.parse(keyUrl));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // API'den gelen public_key büyük ihtimalle string (hex/base64)
      publicKeyHex = data['public_key'] as String?;
      username = data['username'] as String?;

      if (publicKeyHex == null) {
        print('❌ Public key boş döndü');
        return;
      }

      print('🔑 Public key for $username: $publicKeyHex');
    } else {
      print('❌ Public key alınamadı. Durum: ${response.statusCode}');
      return;
    }
  } catch (e) {
    print('❗ Hata oluştu: $e');
    return;
  }

  // Hex string'i BigInt'e çevir
  BigInt otherPublicKey = BigInt.parse(publicKeyHex, radix: 16);

  final diffieHellman = DiffieHellman();

  // Ortak sır (shared secret) hesapla
  Uint8List sharedSecretKey = await diffieHellman.computeSharedSecret(
    otherPublicKey,
    defaultPrime,
  );

  print('AES Anahtarı (Base64): ${base64.encode(sharedSecretKey)}');

  // sharedSecretKey artık AES şifreleme için kullanılabilir
}
  void _connectWebSocket() {
    final wsUrl = 'ws://$Url:5004/ws/${widget.senderUsername}';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen((event) {
      print('🟢 WebSocket Mesaj Geldi: $event');
      final data = jsonDecode(event);
      final messageId = data['message_id'].toString();

      final existingIndex = _messages.indexWhere((m) =>
          m['message_id'].toString() == messageId ||
          (m['message_id'].toString().startsWith('temp_') &&
              m['text'] ==
                  (data['message'] ??
                      (data['file_name'] != null
                          ? '[Dosya: ${data['file_name']}]'
                          : ''))));

      DateTime time;
      try {
        time = DateTime.fromMillisecondsSinceEpoch(
            (int.tryParse(data['timestamp'].toString()) ?? 0) * 1000);
      } catch (_) {
        time = DateTime.now();
      }

      setState(() {
        final newMessage = {
          'message_id': messageId,
          'text': _parseContent(data),
          'isSent': data['sender'] == widget.senderUsername,
          'timestamp': time,
          'delivered': data['delivered'] ?? 0,
          'file_name': data['file_name'],
        };

        if (existingIndex >= 0) {
          _messages[existingIndex] = newMessage;
        } else {
          _messages.add(newMessage);
        }

        _isSending = false;
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
        'http://$Url:5004/get_messages/${widget.senderUsername}/${widget.receiverUsername}';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _messages = data.map((msg) {
            return {
              'message_id': msg['id'].toString(),
              'text': msg['type'] == 'text'
                  ? msg['content']
                  : '[Dosya: ${msg['file_name']}]',
              'isSent': msg['sender'] == widget.senderUsername,
              'timestamp':
                  DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] * 1000),
              'delivered': msg['delivered'],
              'file_name': msg['file_name'],
            };
          }).toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Mesaj çekme hatası: $e');
    }
  }

  Future<void> _markAsSeen(String messageId) async {
    final url = 'http://$Url:5004/ws/${widget.senderUsername}/seen';
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message_id': messageId,
          'receiver': widget.receiverUsername,
        }),
      );
      if (res.statusCode != 200) {
        debugPrint('mark_seen başarısız: ${res.body}');
      }
    } catch (e) {
      debugPrint('mark_seen hatası: $e');
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _messages.add({
        'message_id': tempId,
        'text': text,
        'isSent': true,
        'timestamp': DateTime.now(),
        'delivered': 0,
        'file_name': null,
      });
      _controller.clear();
    });

    _scrollToBottom();

    final msg = {
      'sender': widget.senderUsername,
      'receiver': widget.receiverUsername,
      'message': text,
    };
    _channel?.sink.add(jsonEncode(msg));
  }

  Future<void> _sendFile(File file) async {
    if (_isSending) return;

    final fileName = path.basename(file.path);
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _isSending = true;
      _messages.add({
        'message_id': tempId,
        'text': '[Dosya: $fileName]',
        'isSent': true,
        'timestamp': DateTime.now(),
        'delivered': 0,
        'file_name': fileName,
      });
    });

    _scrollToBottom();

    final fileMetadata = jsonEncode({
      'sender': widget.senderUsername,
      'receiver': widget.receiverUsername,
      'type': 'file',
      'file_name': fileName,
      'mime_type': mimeType,
      'message': null,
      'file_url': 'incoming',
    });

    try {
      _channel?.sink.add(fileMetadata);
      final fileBytes = await file.readAsBytes();
      _channel?.sink.add(fileBytes);
    } catch (e) {
      debugPrint('Dosya gönderme hatası: $e');
    } finally {
      setState(() {
        _pickedFile = null;
        _pickedFileName = null;
        _isSending = false;
      });
    }
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

  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  Future<void> _downloadAndOpenFile(String username, String fileName) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final url = 'http://$Url:5004/download_file/$username/$fileName';
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode == 200) {
        final contentLength = response.contentLength ?? 0;
        List<int> bytes = [];
        int received = 0;

        final completer = Completer<void>();

        response.stream.listen(
          (newBytes) {
            bytes.addAll(newBytes);
            received += newBytes.length;
            if (contentLength != 0) {
              setState(() {
                _downloadProgress = received / contentLength;
              });
            }
          },
          onDone: () => completer.complete(),
          onError: (e) {
            completer.completeError(e);
          },
          cancelOnError: true,
        );

        await completer.future;

        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      } else {
        debugPrint('Dosya indirilemedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Dosya indirme hatası: $e');
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
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
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _deleteMessage(String messageId, int index) async {
    final uri = Uri.parse('http://$Url:5004/delete_message/$messageId');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': widget.senderUsername}),
    );
    if (res.statusCode == 200) {
      setState(() {
        _messages.removeAt(index);
      });
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pickedFile != null && _pickedFileName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file,
                      size: 22, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pickedFileName!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.blue),
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
              Material(
                color: Colors.transparent,
                child: IconButton(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file, color: Colors.blue),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Mesaj yaz...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _isSending
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Material(
                      color: Colors.blue,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () {
                          if (_pickedFile != null) {
                            _sendFile(_pickedFile!);
                          } else {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, int index) {
    final isSent = msg['isSent'] as bool? ?? false;
    final text = msg['text'] as String? ?? '';
    final fileName = msg['file_name'] as String?;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isSent ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight:
          isSent ? const Radius.circular(4) : const Radius.circular(16),
    );

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Dismissible(
        key: Key(msg['message_id']),
        //sadece gönderen kendi mesajını silebiliyordu
        // direction: isSent ? DismissDirection.endToStart : DismissDirection.none,
        onDismissed: (_) => _deleteMessage(msg['message_id'], index),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: borderRadius,
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: isSent
                ? const LinearGradient(
                    colors: [Color(0xff4A90E2), Color(0xff357ABD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xffE1E1E1), Color(0xffC7C7C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: borderRadius,
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: GestureDetector(
            onTap: fileName != null
                ? () => _downloadAndOpenFile(widget.senderUsername, fileName)
                : null,
            child: Text(
              text,
              style: TextStyle(
                color: isSent ? Colors.white : Colors.black87,
                fontSize: 16,
                decoration: fileName != null ? TextDecoration.underline : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff357ABD),
        elevation: 2,
        centerTitle: true,
        title: Text(
          widget.receiverUsername,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isDownloading)
              LinearProgressIndicator(
                value: _downloadProgress,
                minHeight: 4,
                backgroundColor: Colors.grey[300],
                color: Colors.indigo,
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg, index);
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }
}
