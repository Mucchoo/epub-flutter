import 'ai_chat_message.dart';

class AiChatUiState {
  const AiChatUiState({
    this.messages = const [],
    this.isStreaming = false,
  });

  final List<AiChatMessage> messages;
  final bool isStreaming;

  AiChatUiState copyWith({
    List<AiChatMessage>? messages,
    bool? isStreaming,
  }) => AiChatUiState(
    messages: messages ?? this.messages,
    isStreaming: isStreaming ?? this.isStreaming,
  );
}
