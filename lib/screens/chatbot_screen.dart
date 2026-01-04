import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// AI-powered chatbot screen for U-Lingo language learning app.
/// 
/// Provides an interactive chat interface where users can ask questions about
/// learning Mandarin Chinese. The chatbot is powered by DeepSeek AI via OpenRouter
/// and maintains conversation context to provide coherent, educational responses.
/// 
/// Features:
/// - Real-time AI responses for language learning queries
/// - Conversation history maintained throughout the session
/// - Visual feedback with typing indicators
/// - Themed UI with decorative apple pattern background
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  /// OpenRouter API key for accessing DeepSeek AI model.
  /// 
  /// SECURITY NOTE: In production, this should be stored securely on the backend
  /// and never exposed in client-side code. Consider implementing a proxy API
  /// endpoint to handle AI requests without exposing the API key.
  static const String OPENROUTER_API_KEY = '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';

  // Controller for the message input field
  final TextEditingController _messageController = TextEditingController();
  
  // List of all chat messages in the conversation, displayed in chronological order
  final List<ChatMessage> _messages = [];
  
  // Controller for auto-scrolling to show the latest messages
  final ScrollController _scrollController = ScrollController();
  
  // Flag to show typing indicator while waiting for AI response
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message when chat screen first loads
    // This helps users understand the chatbot's purpose and capabilities
    _messages.add(
      ChatMessage(
        text: 'Hello! I\'m your U-Lingo AI assistant powered by DeepSeek. Ask me anything about learning Mandarin!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Handles sending a user message and receiving an AI response.
  /// 
  /// Process flow:
  /// 1. Validates that the message is not empty
  /// 2. Adds user message to chat history
  /// 3. Shows typing indicator
  /// 4. Calls DeepSeek API with conversation context
  /// 5. Displays AI response or error message
  /// 6. Auto-scrolls to show the latest message
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

    // Store message text before clearing the input field
    // This ensures we don't lose the message if the user types during API call
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
      // Show user-friendly error message instead of crashing
      // This maintains a good user experience even when API calls fail
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

  /// Makes an API call to DeepSeek AI model via OpenRouter.
  /// 
  /// Maintains conversation context by sending the full message history,
  /// allowing the AI to provide coherent responses based on previous exchanges.
  /// The system prompt configures the AI to act as a Mandarin learning assistant.
  /// 
  /// Returns the AI's response text.
  /// Throws an exception if the API call fails.
  Future<String> _callDeepSeekAPI(String userMessage) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    // Build conversation history excluding the welcome message
    // We filter out the welcome message to avoid confusing the AI
    final conversationHistory = _messages
        .where((msg) => !msg.text.contains('powered by DeepSeek'))
        .map((msg) => {
      'role': msg.isUser ? 'user' : 'assistant',
      'content': msg.text,
    })
        .toList();

    // Prepend system prompt to define the AI's role and behavior
    // This instructs the AI to focus on Mandarin learning assistance
    conversationHistory.insert(0, {
      'role': 'system',
      'content': 'You are a helpful AI assistant for U-Lingo, a Mandarin Chinese learning app. Help users learn Mandarin by answering their questions about vocabulary, grammar, pronunciation, tones, and study tips. Be encouraging and educational.',
    });

    // Add the current user message to the conversation
    conversationHistory.add({
      'role': 'user',
      'content': userMessage,
    });

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $OPENROUTER_API_KEY',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://ulingo.app', // Required by OpenRouter for analytics
        'X-Title': 'U-Lingo', // App identifier for OpenRouter
      },
      body: jsonEncode({
        'model': 'deepseek/deepseek-r1-0528:free', // Free tier DeepSeek model
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

  /// Auto-scrolls the chat view to the bottom to show the latest message.
  /// 
  /// Uses a small delay to ensure the new message has been rendered before scrolling.
  /// This prevents scrolling to an incorrect position when messages are still being added to the UI.
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
        backgroundColor: const Color(0xFFFFF5E9), // Warm cream background
        elevation: 0,
        title: const Text(
          'Chatbot',
          style: TextStyle(
            color: Color(0xFFE89B93), // Coral/peach accent color
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        // Hide back button since this is a main navigation screen
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFF5E9),
        ),
        child: Stack(
          children: [
            // Decorative apple pattern in the background
            // Creates a playful, educational atmosphere for the learning app
            Positioned.fill(
              child: _buildApplePattern(),
            ),
            // Main chat interface overlaid on the background
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    // Add extra item for typing indicator when AI is responding
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

  /// Creates a decorative background pattern with apple images.
  /// 
  /// Apples are strategically positioned to create visual interest without
  /// interfering with chat message readability. Uses three different apple
  /// images for variety and placed at different sizes to add depth.
  Widget _buildApplePattern() {
    return Stack(
      children: [
        // Top section - scattered apples creating a header decoration
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
        
        // Middle section - side decorations that frame the chat area
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
        
        // Bottom section - footer decoration
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
        
        // Additional scattered apples to fill empty spaces
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

  /// Displays an animated typing indicator while waiting for AI response.
  /// 
  /// Shows the chatbot's avatar with three animated dots to indicate
  /// that the AI is "thinking" and generating a response. This provides
  /// visual feedback that the app is working and hasn't frozen.
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Chatbot avatar (cat character)
          Image.asset(
            'assets/images/chatbot_cat.png',
            width: 40,
            height: 40,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A4A4A), // Dark gray matching AI message bubbles
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Three dots with staggered animation timing for wave effect
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

  /// Builds the message input area at the bottom of the screen.
  /// 
  /// Consists of a text field with an apple icon (brand consistency) and
  /// a circular send button. The input field expands to fill available space
  /// while the send button remains fixed width.
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
                color: const Color(0xFFE5D5C3), // Light brown/beige
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  // Apple icon for brand consistency
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
                      // Allow sending message by pressing Enter/Return
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Circular send button with contrasting color
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFE89B93), // Coral/peach accent
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
    // Clean up controllers to prevent memory leaks
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// Data model representing a single chat message.
/// 
/// Stores the message content, sender type (user or AI), and timestamp.
/// This simple structure could be extended in the future to include
/// message IDs, read status, or other metadata if needed.
class ChatMessage {
  final String text;
  final bool isUser; // true = user message, false = AI message
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Widget that displays a single message bubble in the chat.
/// 
/// Adapts its appearance based on whether it's a user or AI message:
/// - User messages: right-aligned, beige background, user avatar
/// - AI messages: left-aligned, dark gray background, chatbot avatar
/// 
/// This visual distinction helps users quickly understand the conversation flow.
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
          // AI messages show chatbot avatar on the left
          if (!message.isUser)
            Image.asset(
              'assets/images/chatbot_cat.png',
              width: 40,
              height: 40,
            ),
          if (!message.isUser) const SizedBox(width: 12),
          
          // Message bubble with text
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? const Color(0xFFE5D5C3) // Beige for user messages
                    : const Color(0xFF4A4A4A), // Dark gray for AI messages
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? const Color(0xFF4A4A4A) // Dark text on light background
                      : Colors.white, // White text on dark background
                  fontSize: 16,
                ),
              ),
            ),
          ),
          
          // User messages show user avatar on the right
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

/// Single animated dot used in the typing indicator.
/// 
/// Each dot fades in and out continuously to create a wave effect.
/// The staggered delay parameter allows multiple dots to animate
/// out of sync, creating a more natural "typing" appearance.
class _TypingDot extends StatefulWidget {
  /// Delay in milliseconds before starting the animation.
  /// Used to create staggered animation across multiple dots.
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
    // Create a repeating fade animation that reverses at the end
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Start animation after the specified delay
    // This creates the staggered wave effect across multiple dots
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
    // Clean up animation controller to prevent memory leaks
    _controller.dispose();
    super.dispose();
  }
}
