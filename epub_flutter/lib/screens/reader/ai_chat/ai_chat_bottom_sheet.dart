import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../theme/app_colors.dart';
import 'ai_chat_message.dart';
import 'ai_chat_service.dart';
import 'gemini_config.dart';

class AiChatBottomSheet extends StatefulWidget {
  const AiChatBottomSheet({super.key, required this.selectedText});

  final String selectedText;

  @override
  State<AiChatBottomSheet> createState() => _AiChatBottomSheetState();
}

class _AiChatBottomSheetState extends State<AiChatBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AiChatService _service;
  final List<AiChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _sub;
  bool _isStreaming = false;

  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: geminiApiKey,
      systemInstruction: Content.system(
        'You are a reading assistant. The user is reading a book and has selected a passage. '
        'Help them understand, analyse, or discuss it. Be concise and conversational.',
      ),
    );
    _service = AiChatService(model);

    // Show the selected text as a context bubble immediately.
    _messages.add(
      AiChatMessage(
        text: 'Selected text:\n"${widget.selectedText}"',
        isUser: false,
      ),
    );

    // Send a priming message to the model so it knows the passage context,
    // and stream back an opening question for the user.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendInitial());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  void _sendInitial() {
    final priming =
        'The reader selected this passage from the book they are reading:\n'
        '"${widget.selectedText}"\n\n'
        'Greet the user with a very short, friendly opening (1 sentence) '
        'and ask what they would like to know about this passage.';
    _startStream(priming);
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isStreaming) return;
    _inputController.clear();
    setState(() {
      _messages.add(AiChatMessage(text: text, isUser: true));
    });
    _startStream(text);
  }

  void _startStream(String text) {
    setState(() {
      _messages.add(const AiChatMessage(text: '', isUser: false));
      _isStreaming = true;
    });
    final bubbleIndex = _messages.length - 1;

    _sub = _service.sendStreaming(text).listen(
      (accumulated) {
        if (!mounted) return;
        setState(() {
          _messages[bubbleIndex] = _messages[bubbleIndex].copyWith(text: accumulated);
        });
        _scrollToBottom();
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _messages[bubbleIndex] = _messages[bubbleIndex].copyWith(
            text: 'Error: ${e.toString()}',
          );
          _isStreaming = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _isStreaming = false);
      },
      cancelOnError: true,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, sheetScrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: appBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              const Divider(height: 1, color: appCardBg),
              Expanded(child: _buildMessageList()),
              _buildTypingIndicator(),
              _buildComposer(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: appTextDark.withAlpha(60),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Ask AI',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: appTextDark,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: appTextDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(_messages[index]),
    );
  }

  Widget _buildBubble(AiChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? appGold.withAlpha(60) : appCardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: appTextDark, fontSize: 15, height: 1.45),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final showDots =
        _isStreaming && _messages.isNotEmpty && _messages.last.text.isEmpty;
    if (!showDots) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: AnimatedBuilder(
          animation: _dotController,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = ((_dotController.value * 3) - i).clamp(0.0, 1.0);
                final opacity = (phase < 0.5 ? phase * 2 : (1 - phase) * 2)
                    .clamp(0.3, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: appTextDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 8,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: !_isStreaming,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: appTextDark, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Ask something…',
                  hintStyle: TextStyle(color: appTextDark.withAlpha(100)),
                  filled: true,
                  fillColor: appCardBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _isStreaming ? null : _send,
              icon: const Icon(Icons.send_rounded),
              color: appGold,
              disabledColor: appTextDark.withAlpha(60),
            ),
          ],
        ),
      ),
    );
  }
}
