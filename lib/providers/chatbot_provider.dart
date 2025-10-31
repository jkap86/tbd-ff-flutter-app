import 'package:flutter/foundation.dart';
import '../services/chatbot_service.dart';

/// Represents a single message in the chat conversation
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ChatbotQuestion? relatedQuestion;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.relatedQuestion,
  });

  /// Create a copy with modifications
  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    ChatbotQuestion? relatedQuestion,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      relatedQuestion: relatedQuestion ?? this.relatedQuestion,
    );
  }
}

/// Provider for managing chatbot state and conversation flow
class ChatbotProvider extends ChangeNotifier {
  final ChatbotService _service;
  final List<ChatMessage> _messages = [];
  String? _selectedCategory;
  bool _isProcessing = false;

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isProcessing => _isProcessing;
  String? get selectedCategory => _selectedCategory;

  ChatbotProvider(this._service) {
    // Add welcome message on initialization
    _addBotMessage(
      'Hi! I\'m here to help you navigate the app. What would you like to know?',
    );
  }

  /// Send a user message and get a bot response
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message to conversation
    _addUserMessage(text);

    // Set processing state
    _isProcessing = true;
    notifyListeners();

    try {
      // Find answer using the chatbot service
      final response = _service.findAnswer(text);

      // Simulate thinking time for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      // Add bot response
      if (response.found) {
        _addBotMessage(
          response.question!.answer,
          relatedQuestion: response.question,
        );
      } else {
        _addBotMessage(
          'I\'m not sure about that. Try asking about creating leagues, drafting, or setting lineups.',
        );
      }
    } catch (e) {
      // Handle errors gracefully
      _addBotMessage(
        'Sorry, I encountered an error. Please try again.',
      );
      debugPrint('Chatbot error: $e');
    } finally {
      // Clear processing state
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Set the current category filter
  void setCategory(String? category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  /// Clear the current category filter
  void clearCategory() {
    if (_selectedCategory != null) {
      _selectedCategory = null;
      notifyListeners();
    }
  }

  /// Get suggested questions based on current context
  List<ChatbotQuestion> getSuggestedQuestions() {
    if (_selectedCategory != null) {
      // Filter by selected category and limit to 5
      return _service.knowledge
          .where((q) => q.category == _selectedCategory)
          .take(5)
          .toList();
    }
    // Return top 5 questions when no category selected
    return _service.knowledge.take(5).toList();
  }

  /// Get all available categories
  List<String> getCategories() {
    return _service.knowledge
        .map((q) => q.category)
        .toSet()
        .toList()
      ..sort();
  }

  /// Clear all messages and reset conversation
  void clearConversation() {
    _messages.clear();
    _selectedCategory = null;
    _isProcessing = false;

    // Re-add welcome message
    _addBotMessage(
      'Hi! I\'m here to help you navigate the app. What would you like to know?',
    );

    notifyListeners();
  }

  /// Add a user message to the conversation
  void _addUserMessage(String text) {
    _messages.add(ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  /// Add a bot message to the conversation
  void _addBotMessage(String text, {ChatbotQuestion? relatedQuestion}) {
    _messages.add(ChatMessage(
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      relatedQuestion: relatedQuestion,
    ));
    notifyListeners();
  }

  /// Ask a predefined question directly
  Future<void> askQuestion(ChatbotQuestion question) async {
    await sendMessage(question.question);
  }

  /// Get conversation summary for analytics
  Map<String, dynamic> getConversationSummary() {
    final userMessages = _messages.where((m) => m.isUser).length;
    final botMessages = _messages.where((m) => !m.isUser).length;
    final categories = _messages
        .where((m) => m.relatedQuestion != null)
        .map((m) => m.relatedQuestion!.category)
        .toSet()
        .toList();

    return {
      'totalMessages': _messages.length,
      'userMessages': userMessages,
      'botMessages': botMessages,
      'categoriesDiscussed': categories,
      'duration': _messages.isNotEmpty
          ? _messages.last.timestamp.difference(_messages.first.timestamp)
          : Duration.zero,
    };
  }
}
