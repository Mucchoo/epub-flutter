sealed class AiChatAction {}

class MessageSubmitted extends AiChatAction {
  MessageSubmitted(this.text);
  final String text;
}
