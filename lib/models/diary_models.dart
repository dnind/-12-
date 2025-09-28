
enum DiaryCategory {
  study('공부'),
  travel('여행'),
  daily('일상');

  final String korean;
  const DiaryCategory(this.korean);

  static DiaryCategory fromString(String value) {
    return DiaryCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => DiaryCategory.daily,
    );
  }
}

enum DiaryTheme {
  minimal('미니멀'),
  vintage('빈티지'),
  cute('귀여운'),
  professional('전문적인'),
  nature('자연'),
  cosmic('우주');

  final String korean;
  const DiaryTheme(this.korean);
}

class DiaryEntry {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime date;
  final DiaryCategory category;
  final DiaryTheme? theme;
  final List<String> stickers;
  final Map<String, dynamic>? aiAnalysis;
  final Map<String, dynamic>? decoration;
  final String? location;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaryEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.date,
    required this.category,
    this.theme,
    this.stickers = const [],
    this.aiAnalysis,
    this.decoration,
    this.location,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      date: DateTime.parse(json['date']),
      category: DiaryCategory.fromString(json['category'] ?? 'daily'),
      theme: json['theme'] != null ? DiaryTheme.values.firstWhere(
        (t) => t.name == json['theme'],
        orElse: () => DiaryTheme.minimal,
      ) : null,
      stickers: List<String>.from(json['stickers'] ?? []),
      aiAnalysis: json['aiAnalysis'],
      decoration: json['decoration'],
      location: json['location'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'category': category.name,
      'theme': theme?.name,
      'stickers': stickers,
      'aiAnalysis': aiAnalysis,
      'decoration': decoration,
      'location': location,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  DiaryEntry copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    DateTime? date,
    DiaryCategory? category,
    DiaryTheme? theme,
    List<String>? stickers,
    Map<String, dynamic>? aiAnalysis,
    Map<String, dynamic>? decoration,
    String? location,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      category: category ?? this.category,
      theme: theme ?? this.theme,
      stickers: stickers ?? this.stickers,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      decoration: decoration ?? this.decoration,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DiaryAIAnalysis {
  final String summary;
  final String? advice;
  final List<String> suggestedTags;
  final DiaryTheme suggestedTheme;
  final List<String> suggestedStickers;
  final Map<String, dynamic>? categorySpecific;

  DiaryAIAnalysis({
    required this.summary,
    this.advice,
    this.suggestedTags = const [],
    required this.suggestedTheme,
    this.suggestedStickers = const [],
    this.categorySpecific,
  });

  factory DiaryAIAnalysis.fromJson(Map<String, dynamic> json) {
    return DiaryAIAnalysis(
      summary: json['summary'] ?? '',
      advice: json['advice'],
      suggestedTags: List<String>.from(json['suggestedTags'] ?? []),
      suggestedTheme: DiaryTheme.values.firstWhere(
        (t) => t.name == json['suggestedTheme'],
        orElse: () => DiaryTheme.minimal,
      ),
      suggestedStickers: List<String>.from(json['suggestedStickers'] ?? []),
      categorySpecific: json['categorySpecific'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'advice': advice,
      'suggestedTags': suggestedTags,
      'suggestedTheme': suggestedTheme.name,
      'suggestedStickers': suggestedStickers,
      'categorySpecific': categorySpecific,
    };
  }
}

class StudyAnalysis {
  final String summary;
  final List<QuizQuestion> quizQuestions;
  final List<String> keyPoints;

  StudyAnalysis({
    required this.summary,
    this.quizQuestions = const [],
    this.keyPoints = const [],
  });

  factory StudyAnalysis.fromJson(Map<String, dynamic> json) {
    return StudyAnalysis(
      summary: json['summary'] ?? '',
      quizQuestions: (json['quizQuestions'] as List?)
          ?.map((q) => QuizQuestion.fromJson(q))
          .toList() ?? [],
      keyPoints: List<String>.from(json['keyPoints'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'quizQuestions': quizQuestions.map((q) => q.toJson()).toList(),
      'keyPoints': keyPoints,
    };
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswerIndex: json['correctAnswerIndex'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
    };
  }
}

class TravelAnalysis {
  final String summary;
  final List<String> placesmentioned;
  final List<String> recommendations;
  final Map<String, dynamic>? weatherInfo;

  TravelAnalysis({
    required this.summary,
    this.placesmentioned = const [],
    this.recommendations = const [],
    this.weatherInfo,
  });

  factory TravelAnalysis.fromJson(Map<String, dynamic> json) {
    return TravelAnalysis(
      summary: json['summary'] ?? '',
      placesmentioned: List<String>.from(json['placesmentioned'] ?? []),
      recommendations: List<String>.from(json['recommendations'] ?? []),
      weatherInfo: json['weatherInfo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'placesmentioned': placesmentioned,
      'recommendations': recommendations,
      'weatherInfo': weatherInfo,
    };
  }
}

class DiaryDecoration {
  final String backgroundColor;
  final String textColor;
  final String borderStyle;
  final List<StickerPosition> stickerPositions;
  final Map<String, dynamic>? customStyles;

  DiaryDecoration({
    required this.backgroundColor,
    required this.textColor,
    required this.borderStyle,
    this.stickerPositions = const [],
    this.customStyles,
  });

  factory DiaryDecoration.fromJson(Map<String, dynamic> json) {
    return DiaryDecoration(
      backgroundColor: json['backgroundColor'] ?? '#FFFFFF',
      textColor: json['textColor'] ?? '#000000',
      borderStyle: json['borderStyle'] ?? 'solid',
      stickerPositions: (json['stickerPositions'] as List?)
          ?.map((sp) => StickerPosition.fromJson(sp))
          .toList() ?? [],
      customStyles: json['customStyles'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'borderStyle': borderStyle,
      'stickerPositions': stickerPositions.map((sp) => sp.toJson()).toList(),
      'customStyles': customStyles,
    };
  }
}

class StickerPosition {
  final String stickerId;
  final double x;
  final double y;
  final double size;
  final double rotation;

  StickerPosition({
    required this.stickerId,
    required this.x,
    required this.y,
    this.size = 1.0,
    this.rotation = 0.0,
  });

  factory StickerPosition.fromJson(Map<String, dynamic> json) {
    return StickerPosition(
      stickerId: json['stickerId'] ?? '',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      size: (json['size'] ?? 1.0).toDouble(),
      rotation: (json['rotation'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stickerId': stickerId,
      'x': x,
      'y': y,
      'size': size,
      'rotation': rotation,
    };
  }
}