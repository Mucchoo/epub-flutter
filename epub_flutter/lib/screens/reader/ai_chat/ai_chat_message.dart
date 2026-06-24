class AiChatMessage {
  const AiChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  AiChatMessage copyWith({String? text}) =>
      AiChatMessage(text: text ?? this.text, isUser: isUser);
}
