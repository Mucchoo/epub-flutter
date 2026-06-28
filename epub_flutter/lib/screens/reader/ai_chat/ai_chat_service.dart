import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

class AiChatService {
  AiChatService(GenerativeModel model) : _session = model.startChat();

  final ChatSession _session;
  StreamSubscription<String>? _sub;

  Stream<String> sendStreaming(String text) async* {
    final responseStream = _session.sendMessageStream(Content.text(text));
    final buffer = StringBuffer();
    await for (final response in responseStream) {
      final chunk = response.text;
      if (chunk != null && chunk.isNotEmpty) {
        buffer.write(chunk);
        yield buffer.toString();
      }
    }
  }

  void cancel() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    cancel();
  }
}
