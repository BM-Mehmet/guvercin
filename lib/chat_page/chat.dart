import 'package:flutter/material.dart';
import 'package:guvercin/home/home.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Map<String, dynamic>> messages = [
    {'text': 'Merhaba!', 'isSent': true, 'timestamp': DateTime.now().subtract(const Duration(minutes: 5))},
    {'text': 'Merhaba, nasılsınız?', 'isSent': false, 'timestamp': DateTime.now().subtract(const Duration(minutes: 4))},
    {'text': 'İyiyim, teşekkürler. Siz?', 'isSent': true, 'timestamp': DateTime.now().subtract(const Duration(minutes: 3))},
  ];

  final TextEditingController _controller = TextEditingController();
  int? _replyToMessageIndex; // Yalnızca cevap verilen mesajın index'ini tutar

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      messages.add({
        'text': text,
        'isSent': true,
        'timestamp': DateTime.now(),
      });
    });
    _controller.clear();
  }

  void editMessage(int index, String newText) {
    setState(() {
      messages[index]['text'] = newText;
    });
  }

  void deleteMessage(int index) {
    setState(() {
      messages.removeAt(index);
    });
  }

  void replyToMessage(String replyText) {
    setState(() {
      _replyToMessageIndex = messages.length - 1; // Yeni mesaj, son mesajın altına eklenecek
      sendMessage(replyText);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Güvercin Sohbeti'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  return Dismissible(
                    key: Key(message['timestamp'].toString()),
                    direction: message['isSent']
                        ? DismissDirection.endToStart
                        : DismissDirection.startToEnd,
                    onDismissed: (direction) {
                      if (direction == DismissDirection.endToStart && message['isSent']) {
                        replyToMessage('Yanıt: ${message['text']}');
                      } else if (direction == DismissDirection.startToEnd && !message['isSent']) {
                        replyToMessage('Yanıt: ${message['text']}');
                      }
                    },
                    background: Container(
                      alignment: message['isSent']
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      color: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: const Icon(
                        Icons.reply,
                        color: Colors.white,
                      ),
                    ),
                    secondaryBackground: Container(
                      alignment: message['isSent']
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      color: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: const Icon(
                        Icons.reply,
                        color: Colors.white,
                      ),
                    ),
                    child: GestureDetector(
                      onLongPress: () async {
                        final action = await showDialog<String>(
                          context: context,
                          builder: (BuildContext context) {
                            return SimpleDialog(
                              title: const Text('Mesaj İşlemleri'),
                              children: <Widget>[
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(context, 'edit'),
                                  child: const Text('Düzenle'),
                                ),
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(context, 'delete'),
                                  child: const Text('Sil'),
                                ),
                              ],
                            );
                          },
                        );

                        if (action == 'edit') {
                          final TextEditingController editController = TextEditingController(text: message['text']);
                          final newText = await showDialog<String>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Mesajı Düzenle'),
                                content: TextField(
                                  controller: editController,
                                  decoration: const InputDecoration(hintText: 'Yeni mesajı girin'),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, null),
                                    child: const Text('İptal'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, editController.text),
                                    child: const Text('Kaydet'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (newText != null && newText.trim().isNotEmpty) {
                            editMessage(messages.length - 1 - index, newText);
                          }
                        } else if (action == 'delete') {
                          deleteMessage(messages.length - 1 - index);
                        }
                      },
                      onDoubleTap: () {
                        setState(() {
                          // Mesaja iki kez tıklanıldığında, replyToMessage fonksiyonu ile cevap ekleyebiliriz
                          _controller.text = '${message['text']}\n'; // Yanıt olarak mesajın ön izlemesi
                        });
                      },
                      child: MessageBubble(
                        text: message['text'],
                        isSent: message['isSent'],
                        timestamp: message['timestamp'],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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

  const MessageBubble({super.key, 
    required this.text,
    required this.isSent,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final time = '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';

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
