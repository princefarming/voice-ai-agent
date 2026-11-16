import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _voiceEnabled = true;
  final Box _box = Hive.box('chat_history');
  final FlutterTts _tts = FlutterTts();

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get voiceEnabled => _voiceEnabled;

  ChatProvider() {
    _initTts();
    _loadHistory();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.95); // Natural conversational speed
    await _tts.setPitch(1.0);
  }

  void toggleVoice() {
    _voiceEnabled = !_voiceEnabled;
    if (!_voiceEnabled) _tts.stop();
    notifyListeners();
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  Future<void> _speakResponse(String rawText) async {
    if (!_voiceEnabled || rawText.trim().isEmpty) return;

    // Strip basic Markdown symbols and <think> tags so TTS reads cleanly
    final cleanText = rawText
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .replaceAll(RegExp(r'[*#`_]'), '')
        .trim();

    if (cleanText.isNotEmpty) {
      await _tts.speak(cleanText);
    }
  }

  void _loadHistory() {
    final rawHistory = _box.get('messages', defaultValue: []);
    for (var item in rawHistory) {
      _messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(item)));
    }
    notifyListeners();
  }

  void _saveHistory() {
    final serialized = _messages.map((m) => m.toJson()).toList();
    _box.put('messages', serialized);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    await _tts.stop(); // Interrupt current speech if user asks a new question

    final userMessage = ChatMessage(role: 'user', content: text);
    _messages.add(userMessage);

    final assistantMessage = ChatMessage(role: 'assistant', content: '');
    _messages.add(assistantMessage);

    _isLoading = true;
    notifyListeners();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('http://127.0.0.1:11434/api/chat'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': 'qwen3:8b',
        'messages': _messages
            .sublist(0, _messages.length - 1)
            .map((m) => m.toJson())
            .toList(),
        'stream': true,
      });

      final response = await http.Client().send(request);

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (String line) {
          if (line.trim().isNotEmpty) {
            final data = jsonDecode(line);
            if (data.containsKey('message') &&
                data['message'].containsKey('content')) {
              assistantMessage.content += data['message']['content'];
              notifyListeners();
            }
          }
        },
        onDone: () {
          _isLoading = false;
          _saveHistory();
          notifyListeners();
          _speakResponse(assistantMessage.content);
        },
        onError: (error) {
          assistantMessage.content += '\n[Error: Connection interrupted]';
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      assistantMessage.content =
          'Failed to connect to Ollama. Check CORS and server execution.';
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearHistory() {
    _tts.stop();
    _messages.clear();
    _box.delete('messages');
    notifyListeners();
  }
}