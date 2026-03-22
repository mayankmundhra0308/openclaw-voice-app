import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/thread.dart';
import '../services/ai_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import 'dart:math';

class ChatScreen extends StatefulWidget {
  final Thread thread;
  const ChatScreen({super.key, required this.thread});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiService _ai = AiService();
  final VoiceService _voice = VoiceService();

  late Box _messagesBox;
  bool _isLoading = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _listeningText = '';
  late AnimationController _micAnimController;

  @override
  void initState() {
    super.initState();
    _messagesBox = Hive.box('messages');
    _voice.init();
    _micAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _voice.dispose();
    _micAnimController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Message> get _messages {
    return _messagesBox.values
        .cast<Message>()
        .where((m) => m.threadId == widget.thread.id)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  List<Map<String, String>> get _historyForApi {
    return _messages.take(20).map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();
  }

  String _randomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();

    final userMsg = Message(
      id: '${widget.thread.id}_${_randomId()}',
      threadId: widget.thread.id,
      isUser: true,
      text: text.trim(),
      timestamp: DateTime.now(),
    );
    _messagesBox.put(userMsg.id, userMsg);

    // Update thread title if first message
    if (_messages.length == 1) {
      widget.thread.title = text.trim().length > 40
          ? '${text.trim().substring(0, 40)}...'
          : text.trim();
    }
    widget.thread.lastMessage = text.trim().length > 60
        ? '${text.trim().substring(0, 60)}...'
        : text.trim();
    widget.thread.updatedAt = DateTime.now();
    widget.thread.save();

    setState(() => _isLoading = true);
    _scrollToBottom();

    final responseText = await _ai.getChatResponse(text, _historyForApi);

    final aiMsg = Message(
      id: '${widget.thread.id}_${_randomId()}',
      threadId: widget.thread.id,
      isUser: false,
      text: responseText,
      summary: responseText,
      timestamp: DateTime.now(),
    );
    _messagesBox.put(aiMsg.id, aiMsg);

    final preview = responseText.length > 60 ? '${responseText.substring(0, 60)}...' : responseText;
    widget.thread.lastMessage = 'AI: $preview';
    widget.thread.updatedAt = DateTime.now();
    widget.thread.save();

    setState(() => _isLoading = false);
    _scrollToBottom();

    // Auto-speak response
    if (responseText.isNotEmpty) {
      setState(() => _isSpeaking = true);
      // Clean markdown before speaking
      final spokenText = responseText
          .replaceAll(RegExp(r'\*\*|__|#|\*|_|`'), '')
          .replaceAll(RegExp(r'\n{2,}'), '. ')
          .trim();
      await _voice.speak(spokenText);
      setState(() => _isSpeaking = false);
    }
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

  void _startListening() {
    setState(() {
      _isListening = true;
      _listeningText = '';
    });

    _voice.startListening(
      onResult: (text) {
        setState(() {
          _listeningText = text;
          _isListening = false;
        });
        _sendMessage(text);
      },
      onDone: () {
        setState(() => _isListening = false);
      },
    );
  }

  void _stopListening() {
    _voice.stopListening();
    setState(() => _isListening = false);
  }

  void _speakMessage(Message message) {
    final textToSpeak = message.summary ?? message.text;
    _voice.speak(textToSpeak);
    setState(() => _isSpeaking = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: Text(
          widget.thread.title,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: AppTheme.accentColor),
              onPressed: () {
                _voice.stop();
                setState(() => _isSpeaking = false);
              },
            ),
          IconButton(
            icon: const Icon(Icons.more_vert_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _messagesBox.listenable(),
              builder: (context, box, _) {
                final messages = _messages;
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.mic_none,
                          color: AppTheme.primaryColor,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tap the mic to start',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'or type your message below',
                          style: TextStyle(color: Colors.white30, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),

          // Listening indicator
          if (_isListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _micAnimController,
                    builder: (_, __) => Icon(
                      Icons.mic,
                      color: AppTheme.primaryColor
                          .withOpacity(0.4 + 0.6 * _micAnimController.value),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _listeningText.isEmpty ? 'Listening...' : _listeningText,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: _stopListening,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                decoration: BoxDecoration(
                  color: message.isUser ? AppTheme.userBubble : AppTheme.aiBubble,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                    bottomRight: Radius.circular(message.isUser ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isUser)
                      Text(
                        message.text,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5),
                      )
                    else
                      MarkdownBody(
                        data: message.text,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.5),
                          h1: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          h2: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          h3: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          code: const TextStyle(
                            color: AppTheme.accentColor,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          strong: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          listBullet: const TextStyle(color: Colors.white70),
                        ),
                      ),

                    // Voice summary pill
                    if (!message.isUser && message.summary != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _speakMessage(message),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.accentColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.volume_up_outlined,
                                color: AppTheme.accentColor,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  message.summary!,
                                  style: TextStyle(
                                    color: AppTheme.accentColor.withOpacity(0.9),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Timestamp
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.aiBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++)
                  AnimatedBuilder(
                    animation: _micAnimController,
                    builder: (_, __) => Container(
                      width: 7,
                      height: 7,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(
                          0.3 + 0.7 * (((_micAnimController.value + i * 0.33) % 1.0)),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Row(
        children: [
          // Mic button
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isListening
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.white : AppTheme.primaryColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Text field
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Type or speak...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppTheme.cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              onSubmitted: (text) => _sendMessage(text),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: () => _sendMessage(_textController.text),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
