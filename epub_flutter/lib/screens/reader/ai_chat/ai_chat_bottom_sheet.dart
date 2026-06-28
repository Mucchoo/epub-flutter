import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'ai_chat_action.dart';
import 'ai_chat_message.dart';
import 'ai_chat_ui_state.dart';
import 'ai_chat_view_model.dart';

class AiChatBottomSheet extends StatefulWidget {
  const AiChatBottomSheet({super.key, required this.selectedText});

  final String selectedText;

  @override
  State<AiChatBottomSheet> createState() => _AiChatBottomSheetState();
}

class _AiChatBottomSheetState extends State<AiChatBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AiChatViewModel _viewModel;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _viewModel = AiChatViewModel(widget.selectedText);
    _viewModel.addListener(_onStateChanged);

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onStateChanged);
    _viewModel.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    _scrollToBottom();
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _viewModel.state.isStreaming) return;
    _inputController.clear();
    _viewModel.onAction(MessageSubmitted(text));
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
        return ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final state = _viewModel.state;
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
                  Expanded(child: _buildMessageList(state.messages)),
                  _buildTypingIndicator(state),
                  _buildComposer(state.isStreaming),
                ],
              ),
            );
          },
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

  Widget _buildMessageList(List<AiChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) => _buildBubble(messages[index]),
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

  Widget _buildTypingIndicator(AiChatUiState state) {
    final showDots =
        state.isStreaming &&
        state.messages.isNotEmpty &&
        state.messages.last.text.isEmpty;
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

  Widget _buildComposer(bool isStreaming) {
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
                enabled: !isStreaming,
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
              onPressed: isStreaming ? null : _send,
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
