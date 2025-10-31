import 'package:flutter/foundation.dart';

/// Represents a question in the knowledge base
class ChatbotQuestion {
  final String id;
  final String question;
  final String answer;
  final List<String> keywords;
  final List<String> alternativePhrasings;
  final String category;
  final String? deepLink;

  ChatbotQuestion({
    required this.id,
    required this.question,
    required this.answer,
    required this.keywords,
    this.alternativePhrasings = const [],
    this.category = 'general',
    this.deepLink,
  });

  factory ChatbotQuestion.fromJson(Map<String, dynamic> json) {
    return ChatbotQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      alternativePhrasings: json['alternativePhrasings'] != null
          ? (json['alternativePhrasings'] as List<dynamic>).cast<String>()
          : [],
      category: json['category'] as String? ?? 'general',
      deepLink: json['deepLink'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'keywords': keywords,
      'alternativePhrasings': alternativePhrasings,
      'category': category,
      'deepLink': deepLink,
    };
  }
}

/// Represents the response from the chatbot
class ChatbotResponse {
  final ChatbotQuestion? question;
  final bool found;
  final double confidence;
  final List<ChatbotMatch> alternatives;
  final String? fallbackMessage;

  ChatbotResponse._({
    this.question,
    required this.found,
    required this.confidence,
    this.alternatives = const [],
    this.fallbackMessage,
  });

  factory ChatbotResponse.found(
    ChatbotQuestion question,
    double confidence, {
    List<ChatbotMatch> alternatives = const [],
  }) {
    return ChatbotResponse._(
      question: question,
      found: true,
      confidence: confidence,
      alternatives: alternatives,
    );
  }

  factory ChatbotResponse.notFound({
    List<ChatbotMatch> alternatives = const [],
    String? fallbackMessage,
  }) {
    return ChatbotResponse._(
      found: false,
      confidence: 0.0,
      alternatives: alternatives,
      fallbackMessage: fallbackMessage ??
          "I'm sorry, I couldn't find an answer to your question. Please try rephrasing or contact support.",
    );
  }

  String get answer {
    if (found && question != null) {
      return question!.answer;
    }
    return fallbackMessage ?? '';
  }
}

/// Represents a potential match with its confidence score
class ChatbotMatch {
  final ChatbotQuestion question;
  final double score;

  ChatbotMatch(this.question, this.score);
}

/// Intelligent pattern matching engine for question recognition
class ChatbotService {
  final List<ChatbotQuestion> knowledge;

  // Common stop words to filter out
  static const Set<String> _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'is', 'are', 'was', 'were', 'be', 'been',
    'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
    'should', 'could', 'may', 'might', 'can', 'what', 'how', 'when', 'where',
    'why', 'who', 'which', 'this', 'that', 'these', 'those', 'i', 'you',
    'he', 'she', 'it', 'we', 'they', 'my', 'your', 'his', 'her', 'its',
    'our', 'their',
  };

  // Threshold for considering a match as "good enough"
  static const double _minConfidenceThreshold = 0.3;

  // Number of alternative matches to include in response
  static const int _maxAlternatives = 3;

  ChatbotService(this.knowledge);

  /// Find the best answer for a user's question
  ChatbotResponse findAnswer(String userQuestion) {
    if (userQuestion.trim().isEmpty) {
      return ChatbotResponse.notFound(
        fallbackMessage: 'Please ask a question.',
      );
    }

    // 1. Clean and tokenize question
    final tokens = _tokenize(userQuestion);

    if (tokens.isEmpty) {
      return ChatbotResponse.notFound(
        fallbackMessage: 'Please provide more details in your question.',
      );
    }

    // 2. Score all knowledge entries
    final scores = knowledge.map((q) {
      final score = _scoreMatch(tokens, q);
      return ChatbotMatch(q, score);
    }).toList();

    // 3. Sort by score (highest first)
    scores.sort((a, b) => b.score.compareTo(a.score));

    // 4. Get the best match and alternatives
    final bestMatch = scores.first;
    final alternatives = scores
        .skip(1)
        .where((match) => match.score > _minConfidenceThreshold * 0.5)
        .take(_maxAlternatives)
        .toList();

    // 5. Return best match if confidence is high enough, otherwise return not found with alternatives
    if (bestMatch.score >= _minConfidenceThreshold) {
      if (kDebugMode) {
        debugPrint('[ChatbotService] Found match: "${bestMatch.question.question}" with confidence ${bestMatch.score.toStringAsFixed(2)}');
      }
      return ChatbotResponse.found(
        bestMatch.question,
        bestMatch.score,
        alternatives: alternatives,
      );
    } else {
      if (kDebugMode) {
        debugPrint('[ChatbotService] No good match found. Best score: ${bestMatch.score.toStringAsFixed(2)}');
      }
      return ChatbotResponse.notFound(
        alternatives: alternatives,
      );
    }
  }

  /// Clean and tokenize the input text
  List<String> _tokenize(String text) {
    // Convert to lowercase
    final lowercased = text.toLowerCase();

    // Remove punctuation and special characters
    final cleaned = lowercased.replaceAll(RegExp(r'[^\w\s]'), ' ');

    // Split into words
    final words = cleaned.split(RegExp(r'\s+'));

    // Remove stop words and empty strings
    final filtered = words
        .where((word) => word.isNotEmpty && !_stopWords.contains(word))
        .toList();

    if (kDebugMode) {
      debugPrint('[ChatbotService] Tokenized "$text" -> $filtered');
    }

    return filtered;
  }

  /// Calculate match score between user tokens and a knowledge base question
  double _scoreMatch(List<String> userTokens, ChatbotQuestion question) {
    double score = 0.0;

    // Tokenize the question and keywords
    final questionTokens = _tokenize(question.question);
    final keywordTokens = question.keywords.map((k) => k.toLowerCase()).toList();

    if (kDebugMode) {
      debugPrint('[ChatbotService] Scoring against: "${question.question}"');
      debugPrint('[ChatbotService] User tokens: $userTokens');
      debugPrint('[ChatbotService] Keywords: $keywordTokens');
    }

    // Score 1: Exact question match (very high weight)
    if (_exactMatch(userTokens, questionTokens)) {
      score += 1.0;
    }

    // Score 2: Alternative phrasing match (high weight)
    for (final alt in question.alternativePhrasings) {
      final altTokens = _tokenize(alt);
      if (_exactMatch(userTokens, altTokens)) {
        score += 0.9;
        break;
      }
    }

    // Score 3: Keyword matching (medium weight)
    final keywordScore = _keywordMatchScore(userTokens, keywordTokens);
    score += keywordScore * 0.6;

    // Score 4: Partial question match (low-medium weight)
    final questionMatchScore = _partialMatchScore(userTokens, questionTokens);
    score += questionMatchScore * 0.4;

    // Score 5: Fuzzy matching bonus (low weight)
    final fuzzyScore = _fuzzyMatchScore(userTokens, questionTokens);
    score += fuzzyScore * 0.2;

    // Score 6: Word order similarity (low weight)
    final orderScore = _sequenceMatchScore(userTokens, questionTokens);
    score += orderScore * 0.15;

    // Normalize score to 0-1 range
    // Maximum possible score is approximately: 1.0 + 0.9 + 0.6 + 0.4 + 0.2 + 0.15 = 3.25
    final normalizedScore = (score / 3.25).clamp(0.0, 1.0);

    if (kDebugMode) {
      debugPrint('[ChatbotService] Score: ${normalizedScore.toStringAsFixed(3)} (raw: ${score.toStringAsFixed(3)})');
    }

    return normalizedScore;
  }

  /// Check if two token lists are an exact match
  bool _exactMatch(List<String> tokens1, List<String> tokens2) {
    if (tokens1.length != tokens2.length) return false;

    final sorted1 = List<String>.from(tokens1)..sort();
    final sorted2 = List<String>.from(tokens2)..sort();

    for (int i = 0; i < sorted1.length; i++) {
      if (sorted1[i] != sorted2[i]) return false;
    }

    return true;
  }

  /// Calculate keyword match score
  double _keywordMatchScore(List<String> userTokens, List<String> keywords) {
    if (keywords.isEmpty) return 0.0;

    int matches = 0;
    for (final token in userTokens) {
      if (keywords.contains(token)) {
        matches++;
      }
    }

    return matches / keywords.length;
  }

  /// Calculate partial match score based on shared tokens
  double _partialMatchScore(List<String> tokens1, List<String> tokens2) {
    if (tokens1.isEmpty || tokens2.isEmpty) return 0.0;

    final set1 = Set<String>.from(tokens1);
    final set2 = Set<String>.from(tokens2);

    final intersection = set1.intersection(set2);
    final union = set1.union(set2);

    if (union.isEmpty) return 0.0;

    // Jaccard similarity
    return intersection.length / union.length;
  }

  /// Calculate fuzzy match score (handles typos and similar words)
  double _fuzzyMatchScore(List<String> userTokens, List<String> questionTokens) {
    double totalSimilarity = 0.0;
    int comparisons = 0;

    for (final userToken in userTokens) {
      for (final questionToken in questionTokens) {
        final similarity = _levenshteinSimilarity(userToken, questionToken);
        totalSimilarity += similarity;
        comparisons++;
      }
    }

    if (comparisons == 0) return 0.0;

    return totalSimilarity / comparisons;
  }

  /// Calculate sequence/order match score
  double _sequenceMatchScore(List<String> tokens1, List<String> tokens2) {
    if (tokens1.isEmpty || tokens2.isEmpty) return 0.0;

    // Find longest common subsequence
    final lcs = _longestCommonSubsequence(tokens1, tokens2);
    final maxLength = tokens1.length > tokens2.length ? tokens1.length : tokens2.length;

    return lcs / maxLength;
  }

  /// Calculate similarity between two strings using Levenshtein distance
  double _levenshteinSimilarity(String s1, String s2) {
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = s1.length > s2.length ? s1.length : s2.length;

    if (maxLength == 0) return 1.0;

    return 1.0 - (distance / maxLength);
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    // Create a matrix to store distances
    final matrix = List.generate(
      len1 + 1,
      (i) => List.generate(len2 + 1, (j) => 0),
    );

    // Initialize first row and column
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    // Fill in the matrix
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  /// Calculate longest common subsequence length
  int _longestCommonSubsequence(List<String> list1, List<String> list2) {
    final m = list1.length;
    final n = list2.length;

    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (list1[i - 1] == list2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    return dp[m][n];
  }

  /// Search knowledge base by category
  List<ChatbotQuestion> getQuestionsByCategory(String category) {
    return knowledge
        .where((q) => q.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  /// Get all available categories
  Set<String> getCategories() {
    return knowledge.map((q) => q.category).toSet();
  }

  /// Add a new question to the knowledge base
  void addQuestion(ChatbotQuestion question) {
    knowledge.add(question);
  }

  /// Remove a question from the knowledge base
  bool removeQuestion(String questionId) {
    final index = knowledge.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      knowledge.removeAt(index);
      return true;
    }
    return false;
  }

  /// Update an existing question
  bool updateQuestion(String questionId, ChatbotQuestion updatedQuestion) {
    final index = knowledge.indexWhere((q) => q.id == questionId);
    if (index != -1) {
      knowledge[index] = updatedQuestion;
      return true;
    }
    return false;
  }
}
