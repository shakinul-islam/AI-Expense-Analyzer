import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _loadAIReports();
  }

  // Load previous AI reports
  Future<void> _loadAIReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await ApiService().getAIReports();
      if (reports.isNotEmpty) {
        // Add reports as messages from AI
        setState(() {
          for (var report in reports) {
            _messages.add({
              'text': report['insight_text'] ?? 'No insights available',
              'isUser': false,
              'timestamp': report['generated_at'] ?? DateTime.now().toString(),
            });
          }
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        // Welcome message if no reports
        setState(() {
          _messages.add({
            'text': '👋 Welcome to AI Assistant!\n\n'
                'I can help you with:\n'
                '• Generate spending insights\n'
                '• Analyze your expenses\n'
                '• Provide money-saving tips\n'
                '• Answer financial questions\n\n'
                'Click the "Generate Insight" button to get started!',
            'isUser': false,
            'timestamp': DateTime.now().toString(),
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'text': '👋 Welcome to AI Assistant!\n\n'
              'I can help you manage your finances better. '
              'Click the "Generate Insight" button to analyze your spending patterns.',
          'isUser': false,
          'timestamp': DateTime.now().toString(),
        });
        _isLoading = false;
      });
    }
  }

  // Generate new insight
  Future<void> _generateInsight() async {
    if (_isGeneratingReport) return;

    setState(() {
      _isGeneratingReport = true;
      _messages.add({
        'text': '🤔 Analyzing your transactions... Please wait.',
        'isUser': false,
        'timestamp': DateTime.now().toString(),
        'isLoading': true,
      });
    });
    _scrollToBottom();

    try {
      final response = await ApiService().generateInsight();
      
      // Remove loading message
      setState(() {
        _messages.removeWhere((msg) => msg['isLoading'] == true);
      });

      if (response['report'] != null) {
        final insight = response['report']['insight_text'] ?? 'No insights available';
        setState(() {
          _messages.add({
            'text': insight,
            'isUser': false,
            'timestamp': DateTime.now().toString(),
          });
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ New insights generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _messages.add({
            'text': '⚠️ No insights could be generated. Please ensure you have transactions recorded.',
            'isUser': false,
            'timestamp': DateTime.now().toString(),
          });
        });
      }
    } catch (e) {
      // Remove loading message
      setState(() {
        _messages.removeWhere((msg) => msg['isLoading'] == true);
        _messages.add({
          'text': '❌ Error: ${e.toString().replaceAll('Exception:', '')}',
          'isUser': false,
          'timestamp': DateTime.now().toString(),
        });
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${e.toString().replaceAll('Exception:', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isGeneratingReport = false);
      _scrollToBottom();
    }
  }

  // Send user message
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'timestamp': DateTime.now().toString(),
      });
      _messageController.clear();
    });
    _scrollToBottom();

    // Add typing indicator
    setState(() {
      _messages.add({
        'text': '...',
        'isUser': false,
        'timestamp': DateTime.now().toString(),
        'isTyping': true,
      });
    });
    _scrollToBottom();

    try {
      // TODO: Implement chat API endpoint
      // For now, send to generate insight or show default response
      final response = await ApiService().generateInsight();
      
      // Remove typing indicator
      setState(() {
        _messages.removeWhere((msg) => msg['isTyping'] == true);
      });

      if (response['report'] != null) {
        final insight = response['report']['insight_text'] ?? 
            'I analyzed your request. Here are some insights based on your spending:';
        setState(() {
          _messages.add({
            'text': insight,
            'isUser': false,
            'timestamp': DateTime.now().toString(),
          });
        });
      } else {
        setState(() {
          _messages.add({
            'text': 'I need to analyze your transactions first. Please click the "Generate Insight" button.',
            'isUser': false,
            'timestamp': DateTime.now().toString(),
          });
        });
      }
    } catch (e) {
      // Remove typing indicator
      setState(() {
        _messages.removeWhere((msg) => msg['isTyping'] == true);
        _messages.add({
          'text': '💡 You can ask me about:\n'
              '• Spending patterns\n'
              '• Budget recommendations\n'
              '• Saving tips\n'
              '• Financial planning\n\n'
              'For detailed analysis, click the "Generate Insight" button.',
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
          _scrollController.position.maxScrollExtent,
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

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.white),
            SizedBox(width: 8),
            Text('AI Assistant'),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAIReports,
            tooltip: 'Refresh conversations',
          ),
          // Clear chat button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Chat'),
                  content: const Text('Are you sure you want to clear all messages?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _messages.add({
                            'text': 'Chat cleared. Start a new conversation!',
                            'isUser': false,
                            'timestamp': DateTime.now().toString(),
                          });
                        });
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Generate Insight Button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingReport ? null : _generateInsight,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isGeneratingReport
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _isGeneratingReport ? 'Generating...' : 'Generate Insight',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chat Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['isUser'] ?? false;
                      final isTyping = message['isTyping'] ?? false;
                      final isLoading = message['isLoading'] ?? false;
                      final text = message['text'] ?? '';
                      final timestamp = message['timestamp'] ?? '';

                      // Typing indicator
                      if (isTyping) {
                        return _buildTypingIndicator();
                      }

                      // Loading indicator
                      if (isLoading) {
                        return _buildLoadingMessage();
                      }

                      return _buildMessageBubble(
                        text: text,
                        isUser: isUser,
                        timestamp: timestamp,
                      );
                    },
                  ),
          ),
          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about your finances...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.indigo,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                    padding: EdgeInsets.zero,
                    tooltip: 'Send message',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Message Bubble Widget
  Widget _buildMessageBubble({
    required String text,
    required bool isUser,
    required String timestamp,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? Colors.indigo : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 16 : 4),
                  topRight: Radius.circular(isUser ? 4 : 16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    text,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (timestamp.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        color: isUser ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  // AI Avatar
  Widget _buildAvatar() {
    return const CircleAvatar(
      backgroundColor: Colors.indigo,
      radius: 18,
      child: Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  // User Avatar
  Widget _buildUserAvatar() {
    return CircleAvatar(
      backgroundColor: Colors.grey.shade300,
      radius: 18,
      child: const Icon(
        Icons.person,
        color: Colors.grey,
        size: 18,
      ),
    );
  }

  // Typing Indicator
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        color: Colors.grey.shade600,
        shape: BoxShape.circle,
      ),
    );
  }

  // Loading Message
  Widget _buildLoadingMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Analyzing...',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
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