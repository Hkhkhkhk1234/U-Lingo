import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const String OPENROUTER_API_KEY = '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';     //'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

  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: 'Hello! I\'m your U-Lingo AI assistant powered by DeepSeek. Ask me anything about learning Mandarin!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: _messageController.text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    final userMessageText = _messageController.text.trim();
    _messageController.clear();
    _scrollToBottom();

    try {
      final aiResponse = await _callDeepSeekAPI(userMessageText);
      setState(() {
        _messages.add(
          ChatMessage(
            text: aiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Sorry, I encountered an error: ${e.toString()}',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  Future<String> _callDeepSeekAPI(String userMessage) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final conversationHistory = _messages
        .where((msg) => !msg.text.contains('powered by DeepSeek'))
        .map((msg) => {
      'role': msg.isUser ? 'user' : 'assistant',
      'content': msg.text,
    })
        .toList();

    conversationHistory.insert(0, {
      'role': 'system',
      'content': 'You are a helpful AI assistant for U-Lingo, a Mandarin Chinese learning app. Help users learn Mandarin by answering their questions about vocabulary, grammar, pronunciation, tones, and study tips. Be encouraging and educational.',
    });

    conversationHistory.add({
      'role': 'user',
      'content': userMessage,
    });

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $OPENROUTER_API_KEY',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://ulingo.app',
        'X-Title': 'U-Lingo',
      },
      body: jsonEncode({
        'model': 'deepseek/deepseek-r1-0528:free',
        'messages': conversationHistory,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5E9),
        elevation: 0,
        title: const Text(
          'Chatbot',
          style: TextStyle(
            color: Color(0xFFE89B93),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFF5E9),
        ),
        child: Stack(
          children: [
            // Background apple pattern
            Positioned.fill(
              child: _buildApplePattern(),
            ),
            // Chat content
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplePattern() {
    return Stack(
      children: [
        // Top left apples
        Positioned(
          top: 20,
          left: 10,
          child: Image.asset('assets/images/apple.png', width: 40, height: 40),
        ),
        Positioned(
          top: 80,
          left: 50,
          child: Image.asset('assets/images/apple1.png', width: 35, height: 35),
        ),
        // Top right apples
        Positioned(
          top: 40,
          right: 30,
          child: Image.asset('assets/images/apple2.png', width: 45, height: 45),
        ),
        Positioned(
          top: 100,
          right: 10,
          child: Image.asset('assets/images/apple.png', width: 38, height: 38),
        ),
        // Middle left apples
        Positioned(
          top: 200,
          left: 5,
          child: Image.asset('assets/images/apple2.png', width: 42, height: 42),
        ),
        Positioned(
          top: 280,
          left: 40,
          child: Image.asset('assets/images/apple1.png', width: 36, height: 36),
        ),
        // Middle right apples
        Positioned(
          top: 220,
          right: 20,
          child: Image.asset('assets/images/apple.png', width: 40, height: 40),
        ),
        Positioned(
          top: 300,
          right: 50,
          child: Image.asset('assets/images/apple2.png', width: 38, height: 38),
        ),
        // Bottom left apples
        Positioned(
          bottom: 200,
          left: 15,
          child: Image.asset('assets/images/apple1.png', width: 44, height: 44),
        ),
        Positioned(
          bottom: 120,
          left: 45,
          child: Image.asset('assets/images/apple.png', width: 36, height: 36),
        ),
        // Bottom right apples
        Positioned(
          bottom: 180,
          right: 25,
          child: Image.asset('assets/images/apple2.png', width: 40, height: 40),
        ),
        Positioned(
          bottom: 100,
          right: 5,
          child: Image.asset('assets/images/apple1.png', width: 42, height: 42),
        ),
        // Additional scattered apples
        Positioned(
          top: 150,
          left: 100,
          child: Image.asset('assets/images/apple.png', width: 30, height: 30),
        ),
        Positioned(
          bottom: 300,
          right: 80,
          child: Image.asset('assets/images/apple1.png', width: 32, height: 32),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Image.asset(
            'assets/images/chatbot_cat.png',
            width: 40,
            height: 40,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A4A4A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                const SizedBox(width: 4),
                _TypingDot(delay: 200),
                const SizedBox(width: 4),
                _TypingDot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E9),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE5D5C3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Icon(
                      Icons.apple,
                      color: Color(0xFFE89B93),
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Ask chatbot',
                        hintStyle: TextStyle(color: Color(0xFF8B7A6A)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFE89B93),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}



class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
        message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser)
            Image.asset(
              'assets/images/chatbot_cat.png',
              width: 40,
              height: 40,
            ),
          if (!message.isUser) const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFFE5D5C3)
                    : const Color(0xFF4A4A4A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? const Color(0xFF4A4A4A)
                      : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 12),
          if (message.isUser)
            CircleAvatar(
              backgroundColor: const Color(0xFFE89B93),
              child: const Icon(Icons.person, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({Key? key, required this.delay}) : super(key: key);

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
