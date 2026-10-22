import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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

  // 🚀 Voice input
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadAIReports();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) setState(() => _speechAvailable = ok);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  Future<void> _toggleListen() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Speech recognition not available on this device'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    await _speech.listen(
      onResult: (result) {
        setState(() => _messageController.text = result.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
    setState(() => _isListening = true);
  }

  Future<void> _loadAIReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await ApiService().getAIReports();
      if (reports.isNotEmpty) {
        setState(() {
          for (var report in reports.reversed) {
            _messages.add({
              'text': report['insight_text'] ?? 'No insights',
              'isUser': false,
              'timestamp': report['generated_at'] ?? DateTime.now().toString(),
            });
          }
        });
        _scrollToBottom();
      } else {
        _sendWelcomeMessage();
      }
    } catch (_) {
      _sendWelcomeMessage();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendWelcomeMessage() {
    setState(() {
      _messages.add({
        'text': '👋 Hello! I\'m your AI Financial Assistant.\n\n'
            'Ask me anything about your expenses:\n'
            '• "How much did I spend on food this month?"\n'
            '• "Do I have enough money left for shopping?"\n\n'
            'Or tap "Generate Insight" for a full report!\n'
            '🎤 You can also tap the mic to speak.',
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
        'text': 'Analyzing your transactions...',
        'isUser': false,
        'timestamp': DateTime.now().toString(),
        'isTyping': true,
      });
    });
    _scrollToBottom();

    try {
      final response = await ApiService().generateInsight();
      setState(() => _messages.removeWhere((m) => m['isTyping'] == true));
      if (response['insight'] != null) {
        setState(() => _messages.add({
              'text': response['insight'],
              'isUser': false,
              'timestamp': DateTime.now().toString(),
            }));
      }
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m['isTyping'] == true);
        _messages.add({
          'text': '❌ Error: ${e.toString().replaceAll('Exception:', '')}',
          'isUser': false,
          'timestamp': DateTime.now().toString(),
        });
      });
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
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
      final query =
          "$text\n\nProvide answer with bullet points and bold text where useful.";
      final answer = await ApiService().chatWithAI(query);
      setState(() {
        _messages.removeWhere((m) => m['isTyping'] == true);
        _messages.add({
          'text': answer,
          'isUser': false,
          'timestamp': DateTime.now().toString(),
        });
      });
    } catch (_) {
      setState(() {
        _messages.removeWhere((m) => m['isTyping'] == true);
        _messages.add({
          'text': 'Sorry, I couldn\'t connect. Try again.',
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

  String _formatTimestamp(String t) {
    try {
      final date = DateTime.parse(t);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.auto_awesome, color: Colors.amberAccent),
          SizedBox(width: 10),
          Text('AI Assistant',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Expanded(
                  child: Text('Need a detailed report?',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
                ElevatedButton.icon(
                  onPressed: _isGeneratingReport ? null : _generateInsight,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade50,
                    foregroundColor: Colors.indigo,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (c, i) => _buildBubble(_messages[i]),
                  ),
          ),
          Container(
            padding: EdgeInsets.all(16)
                .copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
            color: Colors.white,
            child: Row(
              children: [
                // 🚀 Voice button
                Container(
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.red
                        : (_speechAvailable
                            ? Colors.indigo.shade50
                            : Colors.grey.shade200),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening
                          ? Colors.white
                          : (_speechAvailable
                              ? Colors.indigo
                              : Colors.grey),
                    ),
                    onPressed: _toggleListen,
                    tooltip: _isListening ? 'Stop' : 'Speak',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Listening...'
                          : 'Ask about your finances...',
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
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.indigo, Colors.purple]),
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

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isUser = msg['isUser'] ?? false;
    final isTyping = msg['isTyping'] ?? false;
    final text = msg['text'] ?? '';
    final ts = msg['timestamp'] ?? '';

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
              ),
              child: isTyping
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            height: 10,
                            width: 10,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('AI is thinking...',
                            style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isUser
                            ? SelectableText(text,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.5))
                            : MarkdownBody(
                                data: text,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 15,
                                      height: 1.5),
                                  h3: const TextStyle(
                                      color: Colors.indigo,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                  listBullet: const TextStyle(
                                      color: Colors.indigo, fontSize: 15),
                                ),
                              ),
                        if (ts.isNotEmpty && !isTyping) ...[
                          const SizedBox(height: 8),
                          Text(_formatTimestamp(ts),
                              style: TextStyle(
                                  color: isUser
                                      ? Colors.white70
                                      : Colors.grey.shade500,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
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
}