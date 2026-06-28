import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'ai_chat_action.dart';
import 'ai_chat_message.dart';
import 'ai_chat_service.dart';
import 'ai_chat_ui_state.dart';
import 'gemini_config.dart';

class AiChatViewModel extends ChangeNotifier {
  AiChatViewModel(String selectedText) : _selectedText = selectedText {
    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite',
      apiKey: geminiApiKey,
      systemInstruction: Content.system(
        'You are a reading assistant. The user is reading a book and has selected a passage. '
        'Help them understand, analyse, or discuss it. Be concise and conversational.',
      ),
    );
    _service = AiChatService(model);
    _state = _state.copyWith(
      messages: [AiChatMessage(text: selectedText, isUser: true)],
    );
  }

  final String _selectedText;
  late final AiChatService _service;
  AiChatUiState _state = const AiChatUiState();
  AiChatUiState get state => _state;

  StreamSubscription<String>? _sub;
  bool _firstMessageSent = false;

  void onAction(AiChatAction action) {
    switch (action) {
      case MessageSubmitted(:final text):
        _send(text);
    }
  }

  void _send(String text) {
    if (text.isEmpty || _state.isStreaming) return;

    _state = _state.copyWith(
      messages: [..._state.messages, AiChatMessage(text: text, isUser: true)],
    );
    notifyListeners();

    final String modelInput;
    if (!_firstMessageSent) {
      _firstMessageSent = true;
      modelInput =
          'The reader selected this passage from the book they are reading:\n'
          '"$_selectedText"\n\n'
          '$text';
    } else {
      modelInput = text;
    }

    _startStream(modelInput);
  }

  void _startStream(String text) {
    _state = _state.copyWith(
      messages: [
        ..._state.messages,
        const AiChatMessage(text: '', isUser: false),
      ],
      isStreaming: true,
    );
    notifyListeners();

    final bubbleIndex = _state.messages.length - 1;

    _sub = _service.sendStreaming(text).listen(
      (accumulated) {
        final updated = List<AiChatMessage>.from(_state.messages);
        updated[bubbleIndex] = updated[bubbleIndex].copyWith(text: accumulated);
        _state = _state.copyWith(messages: updated);
        notifyListeners();
      },
      onError: (Object e) {
        final updated = List<AiChatMessage>.from(_state.messages);
        updated[bubbleIndex] = updated[bubbleIndex].copyWith(
          text: 'Error: ${e.toString()}',
        );
        _state = _state.copyWith(messages: updated, isStreaming: false);
        notifyListeners();
      },
      onDone: () {
        _state = _state.copyWith(isStreaming: false);
        notifyListeners();
      },
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
