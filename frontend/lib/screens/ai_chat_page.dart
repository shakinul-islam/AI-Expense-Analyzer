import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _loadAIReports();
  }

  Future<void> _loadAIReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await ApiService().getAIReports();
      if (reports.isNotEmpty) {
        setState(() {
          for (var report in reports.reversed) {
            _messages.add({
              'text': report['insight_text'] ?? 'No insights available',
              'isUser': false,
              'timestamp': report['generated_at'] ?? DateTime.now().toString(),
            });
          }
        });
        _scrollToBottom();
      } else {
        _sendWelcomeMessage();
      }
    } catch (e) {
      _sendWelcomeMessage();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _sendWelcomeMessage() {
    setState(() {
      _messages.add({
        'text': '👋 Hello! I am your AI Financial Assistant.\n\n'
            'You can ask me anything about your expenses, like:\n'
            '• "How much did I spend on food this month?"\n'
            '• "Do I have enough money left for shopping?"\n\n'
            'Or tap "Generate Insight" above for a complete financial report!',
        'isUser': false,
        'timestamp': DateTime.now().toString(),
      });
    });
  }

  Future<void> _generateInsight() async {
    if (_isGeneratingReport) return;

    setState(() {
      _isGeneratingReport = true;
      _messages.add({
        'text': 'Analyzing your transactions... Please wait.',
        'isUser': false,
        'timestamp': DateTime.now().toString(),
        'isTyping': true,
      });
    });
    _scrollToBottom();

    try {
      final response = await ApiService().generateInsight();
      setState(() => _messages.removeWhere((msg) => msg['isTyping'] == true));

      if (response['insight'] != null) {
        setState(() {
          _messages.add({
            'text': response['insight'],
            'isUser': false,
            'timestamp': DateTime.now().toString(),
          });
        });
      } else {
        throw Exception('No insight received');
      }
    } catch (e) {
      setState(() {
        _messages.removeWhere((msg) => msg['isTyping'] == true);
        _messages.add({
          'text':
              '❌ Error generating insight: ${e.toString().replaceAll('Exception:', '')}',
          'isUser': false,
          'timestamp': DateTime.now().toString(),
        });
      });
    } finally {
      setState(() => _isGeneratingReport = false);
      _scrollToBottom();
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'timestamp': DateTime.now().toString(),
      });
      _messageController.clear();
      _messages.add({
        'text': '...',
        'isUser': false,
        'timestamp': DateTime.now().toString(),
        'isTyping': true,
      });
    });
    _scrollToBottom();

    try {
      // 🚀 Append format instruction so the AI responds in a neat report-like manner
      final query =
          "$text\n\nPlease provide your answer in a well-formatted manner using bullet points and bold text where necessary.";
      final answer = await ApiService().chatWithAI(query);

      setState(() {
        _messages.removeWhere((msg) => msg['isTyping'] == true);
        _messages.add({
          'text': answer,
          'isUser': false,
          'timestamp': DateTime.now().toString(),
        });
      });
    } catch (e) {
      setState(() {
        _messages.removeWhere((msg) => msg['isTyping'] == true);
        _messages.add({
          'text':
              'Sorry, I am having trouble connecting to the server. Please try again.',
          'isUser': false,
          'timestamp': DateTime.now().toString(),
        });
      });
    } finally {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) return '${difference.inDays}d ago';
      if (difference.inHours > 0) return '${difference.inHours}h ago';
      if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amberAccent),
            SizedBox(width: 10),
            Text('AI Assistant',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                _messages.clear();
                _sendWelcomeMessage();
              });
            },
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Need a detailed report?',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isGeneratingReport ? null : _generateInsight,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade50,
                    foregroundColor: Colors.indigo,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: _isGeneratingReport
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.analytics_outlined, size: 18),
                  label: Text(
                      _isGeneratingReport ? 'Analyzing...' : 'Generate Insight',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),

          // Chat Area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.indigo))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

          // Modern Input Bar
          Container(
            padding: const EdgeInsets.all(16)
                .copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about your finances...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    gradient:
                        LinearGradient(colors: [Colors.indigo, Colors.purple]),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isUser = msg['isUser'] ?? false;
    final isTyping = msg['isTyping'] ?? false;
    final String displayText = msg['text'] ?? '';
    final String timestamp = msg['timestamp'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              backgroundColor: Colors.indigo,
              radius: 16,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? Colors.indigo : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: isTyping
                  ? _buildTypingDots()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isUser
                            ? SelectableText(
                                // 🚀 Makes user text copyable
                                displayText,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.5),
                              )
                            : MarkdownBody(
                                data: displayText,
                                selectable:
                                    true, // 🚀 Makes AI markdown text copyable
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 15,
                                      height: 1.5),
                                  h1: const TextStyle(
                                      color: Colors.indigo,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                  h2: const TextStyle(
                                      color: Colors.indigo,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  h3: const TextStyle(
                                      color: Colors.indigo,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                  listBullet: const TextStyle(
                                      color: Colors.indigo, fontSize: 15),
                                ),
                              ),
                        if (timestamp.isNotEmpty && !isTyping) ...[
                          const SizedBox(height: 8),
                          Text(
                            _formatTimestamp(
                                timestamp), // 🚀 Shows timestamp under message
                            style: TextStyle(
                              color: isUser
                                  ? Colors.white70
                                  : Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              radius: 16,
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
            height: 10,
            width: 10,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 10),
        Text('AI is thinking...',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }
}
