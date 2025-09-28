import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/diary_models.dart';
import '../config/api_keys.dart';

class DiaryService {
  static final DiaryService _instance = DiaryService._internal();
  factory DiaryService() => _instance;
  DiaryService._internal();

  GenerativeModel? _model;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  GenerativeModel get model {
    _model ??= GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: ApiKeys.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 4096,
      ),
    );
    return _model!;
  }

  void dispose() {
    _model = null;
  }

  Future<List<DiaryEntry>> getUserDiaries() async {
    final preferences = await prefs;
    final diariesJson = preferences.getStringList('diaries') ?? [];

    final diaries = diariesJson.map((json) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return DiaryEntry.fromJson(data);
    }).toList();

    diaries.sort((a, b) => b.date.compareTo(a.date));
    return diaries;
  }

  Future<DiaryEntry?> getDiary(String id) async {
    try {
      final diaries = await getUserDiaries();
      return diaries.where((diary) => diary.id == id).firstOrNull;
    } catch (e) {
      print('Error getting diary: $e');
      return null;
    }
  }

  Future<String> createDiary(DiaryEntry diary) async {
    try {
      final preferences = await prefs;
      final diaries = await getUserDiaries();

      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      final newDiary = diary.copyWith(
        id: newId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      diaries.add(newDiary);

      final diariesJson = diaries.map((d) => jsonEncode(d.toJson())).toList();
      await preferences.setStringList('diaries', diariesJson);

      return newId;
    } catch (e) {
      print('Error creating diary: $e');
      throw e;
    }
  }

  Future<void> updateDiary(DiaryEntry diary) async {
    try {
      final preferences = await prefs;
      final diaries = await getUserDiaries();

      final index = diaries.indexWhere((d) => d.id == diary.id);
      if (index != -1) {
        diaries[index] = diary.copyWith(updatedAt: DateTime.now());
        final diariesJson = diaries.map((d) => jsonEncode(d.toJson())).toList();
        await preferences.setStringList('diaries', diariesJson);
      }
    } catch (e) {
      print('Error updating diary: $e');
      throw e;
    }
  }

  Future<void> deleteDiary(String id) async {
    try {
      final preferences = await prefs;
      final diaries = await getUserDiaries();

      diaries.removeWhere((d) => d.id == id);
      final diariesJson = diaries.map((d) => jsonEncode(d.toJson())).toList();
      await preferences.setStringList('diaries', diariesJson);
    } catch (e) {
      print('Error deleting diary: $e');
      throw e;
    }
  }

  Future<DiaryAIAnalysis> analyzeDiary(String content, DiaryCategory category) async {
    try {
      String prompt = _buildAnalysisPrompt(content, category);
      print('=== AI 분석 시작 ===');
      print('카테고리: ${category.korean}');
      print('내용 길이: ${content.length}자');
      print('API 키 존재: ${ApiKeys.geminiApiKey.isNotEmpty}');
      print('API 키 길이: ${ApiKeys.geminiApiKey.length}');

      // Content를 정확하게 생성
      final contents = [Content.text(prompt)];
      print('Content 생성 완료');

      // 타임아웃 설정과 함께 API 호출
      final response = await model.generateContent(contents).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('AI API 호출 타임아웃 (30초)');
        },
      );

      print('API 응답 받음');
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        throw Exception('AI 응답이 비어있음');
      }

      print('=== AI 응답 ===');
      print('응답 길이: ${responseText.length}자');
      print('응답 내용: $responseText');

      final analysis = _parseAIResponse(responseText, category);
      print('=== 파싱 결과 ===');
      print('요약: ${analysis.summary}');
      print('조언: ${analysis.advice}');
      print('태그: ${analysis.suggestedTags}');

      return analysis;
    } catch (e) {
      print('Error analyzing diary (상세): $e');
      print('에러 타입: ${e.runtimeType}');
      if (e.toString().contains('not found') || e.toString().contains('not supported')) {
        print('모델명 문제 감지됨');
      }
      rethrow; // 에러를 다시 던져서 UI에서 처리하도록 함
    }
  }

  String _buildAnalysisPrompt(String content, DiaryCategory category) {
    String basePrompt = '''
당신은 한국의 전문 다이어리 분석 AI입니다. 주어진 다이어리 내용을 반드시 한국어로 분석해주세요.

📝 다이어리 내용:
"$content"

📂 카테고리: ${category.korean}

🚨 중요한 지시사항:
- 반드시 아래 번호와 형식을 정확히 지켜주세요
- 각 항목은 새로운 줄에 작성하고 번호와 콜론(:)을 포함해주세요
- 추상적이거나 일반적인 답변 금지, 구체적이고 개인화된 분석 필수
- 모든 답변은 한국어로 작성

1. 요약: [다이어리 내용의 핵심을 2-3문장으로 구체적으로 요약해주세요]
2. 조언: [작성자의 상황에 맞는 구체적이고 실용적인 조언을 3문장 이상 작성해주세요]
3. 추천 태그: [내용에서 추출한 핵심 키워드 5-7개를 쉼표로 구분해주세요]
4. 추천 테마: [minimal, vintage, cute, professional, nature, cosmic 중 정확히 하나만 선택해주세요]
5. 추천 스티커: [내용의 감정과 분위기에 맞는 이모지 5-8개를 쉼표로 구분해주세요]
''';

    switch (category) {
      case DiaryCategory.study:
        basePrompt += '''

=== 학습 전용 분석 ===
6. 핵심 포인트: [학습한 내용의 핵심 개념 4-6개를 구체적으로 나열]
7. 퀴즈 문제: [학습 내용을 바탕으로 한 4지선다 문제 2개]
   - 첫 번째 문제: 질문내용|선택지1|선택지2|선택지3|선택지4|정답번호(1-4)|상세한 설명
   - 두 번째 문제: 질문내용|선택지1|선택지2|선택지3|선택지4|정답번호(1-4)|상세한 설명

💡 학습 조언: 효과적인 복습 방법이나 다음 학습 방향을 구체적으로 제시해주세요.
''';
        break;
      case DiaryCategory.travel:
        basePrompt += '''

=== 여행 전용 분석 ===
6. 언급된 장소: [텍스트에서 언급된 모든 장소명을 정확히 추출하여 쉼표로 구분]
7. 추천 장소: [언급된 지역 기반으로 실제 추천할 만한 관광지나 맛집 3-4곳]

🗺️ 여행 조언: 해당 지역의 추가 여행 팁이나 주의사항을 구체적으로 제시해주세요.
''';
        break;
      case DiaryCategory.daily:
        basePrompt += '''

=== 일상 전용 분석 ===
6. 감정 분석: [긍정적/중립/부정적 중 하나와 그 이유를 간단히 설명]
7. 내일을 위한 팁: [오늘의 경험을 바탕으로 내일 더 나은 하루를 위한 구체적인 조언 2-3가지]

💭 라이프스타일 조언: 더 나은 일상을 위한 실용적인 제안을 해주세요.
''';
        break;
    }

    basePrompt += '''

⚠️ 주의사항:
- 각 항목마다 번호와 콜론(:)을 정확히 사용해주세요
- 추상적인 표현보다는 구체적이고 실용적인 내용으로 작성해주세요
- 사용자가 실제로 도움받을 수 있는 수준의 상세한 분석을 제공해주세요
- 모든 응답은 한국어로 작성해주세요
''';

    return basePrompt;
  }

  DiaryAIAnalysis _parseAIResponse(String response, DiaryCategory category) {
    try {
      final lines = response.split('\n').where((line) => line.trim().isNotEmpty).toList();

      String summary = '';
      String advice = '';
      List<String> tags = [];
      DiaryTheme theme = DiaryTheme.minimal;
      List<String> stickers = [];
      Map<String, dynamic>? categorySpecific;

      // 더 정확한 파싱을 위한 정규식 사용
      for (final line in lines) {
        final trimmedLine = line.trim();

        if (trimmedLine.startsWith('1. 요약:')) {
          summary = trimmedLine.substring(6).trim();
        } else if (trimmedLine.startsWith('2. 조언:')) {
          advice = trimmedLine.substring(6).trim();
        } else if (trimmedLine.startsWith('3. 추천 태그:')) {
          tags = trimmedLine.substring(9)
              .split(',')
              .map((tag) => tag.trim().replaceAll(RegExp(r'[^\w가-힣]'), ''))
              .where((tag) => tag.isNotEmpty)
              .toList();
        } else if (trimmedLine.startsWith('4. 추천 테마:')) {
          final themeName = trimmedLine.substring(9).trim().toLowerCase();
          theme = DiaryTheme.values.firstWhere(
            (t) => themeName.contains(t.name),
            orElse: () => DiaryTheme.minimal,
          );
        } else if (trimmedLine.startsWith('5. 추천 스티커:')) {
          final stickerStart = trimmedLine.indexOf(':') + 1;
          if (stickerStart > 0 && stickerStart < trimmedLine.length) {
            stickers = trimmedLine.substring(stickerStart)
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      }

      // 카테고리별 특화 분석
      if (category == DiaryCategory.study) {
        List<String> keyPoints = [];
        List<QuizQuestion> quizQuestions = [];

        for (final line in lines) {
          final trimmedLine = line.trim();

          if (trimmedLine.startsWith('6. 핵심 포인트:')) {
            final pointStart = trimmedLine.indexOf(':') + 1;
            if (pointStart > 0 && pointStart < trimmedLine.length) {
              keyPoints = trimmedLine.substring(pointStart)
                  .split(',')
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty)
                  .toList();
            }
          } else if (trimmedLine.contains('첫 번째 문제:') || trimmedLine.contains('두 번째 문제:')) {
            print('퀴즈 파싱 시도: $trimmedLine');
            final colonIndex = trimmedLine.indexOf(':');
            if (colonIndex != -1 && colonIndex < trimmedLine.length - 1) {
              final questionData = trimmedLine.substring(colonIndex + 1).trim();
              print('퀴즈 데이터: $questionData');
              final parts = questionData.split('|');
              print('파싱된 부분 개수: ${parts.length}');
              if (parts.length >= 7) {
                try {
                  quizQuestions.add(QuizQuestion(
                    question: parts[0].trim(),
                    options: [
                      parts[1].trim(),
                      parts[2].trim(),
                      parts[3].trim(),
                      parts[4].trim(),
                    ],
                    correctAnswerIndex: int.parse(parts[5].trim()) - 1,
                    explanation: parts[6].trim(),
                  ));
                  print('퀴즈 문제 추가 성공');
                } catch (e) {
                  print('Error parsing quiz question: $e');
                }
              } else {
                print('퀴즈 부분이 부족함: ${parts.length}개 (최소 7개 필요)');
              }
            }
          }
        }

        categorySpecific = StudyAnalysis(
          summary: summary,
          keyPoints: keyPoints,
          quizQuestions: quizQuestions,
        ).toJson();
        print('StudyAnalysis 생성 완료 - 퀴즈 개수: ${quizQuestions.length}');
      } else if (category == DiaryCategory.travel) {
        List<String> places = [];
        List<String> recommendations = [];

        for (final line in lines) {
          final trimmedLine = line.trim();

          if (trimmedLine.startsWith('6. 언급된 장소:')) {
            final placeStart = trimmedLine.indexOf(':') + 1;
            if (placeStart > 0 && placeStart < trimmedLine.length) {
              places = trimmedLine.substring(placeStart)
                  .split(',')
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty)
                  .toList();
            }
          } else if (trimmedLine.startsWith('7. 추천 장소:')) {
            final recStart = trimmedLine.indexOf(':') + 1;
            if (recStart > 0 && recStart < trimmedLine.length) {
              recommendations = trimmedLine.substring(recStart)
                  .split(',')
                  .map((r) => r.trim())
                  .where((r) => r.isNotEmpty)
                  .toList();
            }
          }
        }

        categorySpecific = TravelAnalysis(
          summary: summary,
          placesmentioned: places,
          recommendations: recommendations,
        ).toJson();
      } else if (category == DiaryCategory.daily) {
        String emotion = '';
        List<String> tomorrowTips = [];

        for (final line in lines) {
          final trimmedLine = line.trim();

          if (trimmedLine.startsWith('6. 감정 분석:')) {
            final emotionStart = trimmedLine.indexOf(':') + 1;
            if (emotionStart > 0 && emotionStart < trimmedLine.length) {
              emotion = trimmedLine.substring(emotionStart).trim();
            }
          } else if (trimmedLine.startsWith('7. 내일을 위한 팁:')) {
            final tipStart = trimmedLine.indexOf(':') + 1;
            if (tipStart > 0 && tipStart < trimmedLine.length) {
              tomorrowTips = trimmedLine.substring(tipStart)
                  .split(',')
                  .map((tip) => tip.trim())
                  .where((tip) => tip.isNotEmpty)
                  .toList();
            }
          }
        }

        categorySpecific = {
          'emotion': emotion,
          'tomorrowTips': tomorrowTips,
        };
      }

      return DiaryAIAnalysis(
        summary: summary.isNotEmpty ? summary : '오늘의 ${category.korean} 기록',
        advice: advice.isNotEmpty ? advice : '멋진 하루를 보내셨네요! 계속해서 좋은 경험을 쌓아가세요.',
        suggestedTags: tags.isNotEmpty ? tags : [category.korean],
        suggestedTheme: theme,
        suggestedStickers: stickers.isNotEmpty ? stickers : ['📝', '✨', '💫'],
        categorySpecific: categorySpecific,
      );
    } catch (e) {
      print('Error parsing AI response: $e');
      return _getDefaultAnalysis(category);
    }
  }

  DiaryAIAnalysis _getDefaultAnalysis(DiaryCategory category) {
    return DiaryAIAnalysis(
      summary: '오늘의 ${category.korean} 일기',
      advice: '멋진 하루를 보내셨네요!',
      suggestedTags: [category.korean],
      suggestedTheme: DiaryTheme.minimal,
      suggestedStickers: ['📝', '✨', '💫'],
    );
  }

  Future<DiaryDecoration> generateDecoration(DiaryTheme theme, List<String> stickers) async {
    Map<String, String> themeColors = {
      'minimal': '#FFFFFF,#000000',
      'vintage': '#F5E6D3,#5D4E37',
      'cute': '#FFE4E1,#FF69B4',
      'professional': '#F0F0F0,#2C3E50',
      'nature': '#E8F5E9,#2E7D32',
      'cosmic': '#1A237E,#E1BEE7',
    };

    final colors = themeColors[theme.name]?.split(',') ?? ['#FFFFFF', '#000000'];

    List<StickerPosition> stickerPositions = [];
    for (int i = 0; i < stickers.length && i < 5; i++) {
      stickerPositions.add(StickerPosition(
        stickerId: stickers[i],
        x: 20.0 + (i * 70),
        y: 20.0,
        size: 1.0,
        rotation: (i * 15.0) - 30.0,
      ));
    }

    return DiaryDecoration(
      backgroundColor: colors[0],
      textColor: colors[1],
      borderStyle: theme == DiaryTheme.vintage ? 'dashed' : 'solid',
      stickerPositions: stickerPositions,
      customStyles: {
        'fontFamily': _getFontForTheme(theme),
        'borderRadius': theme == DiaryTheme.cute ? 20.0 : 8.0,
      },
    );
  }

  String _getFontForTheme(DiaryTheme theme) {
    switch (theme) {
      case DiaryTheme.vintage:
        return 'Georgia';
      case DiaryTheme.cute:
        return 'Comic Sans MS';
      case DiaryTheme.professional:
        return 'Arial';
      case DiaryTheme.nature:
        return 'Verdana';
      case DiaryTheme.cosmic:
        return 'Courier New';
      default:
        return 'Helvetica';
    }
  }

  Future<List<DiaryEntry>> searchDiaries(String query) async {
    final diaries = await getUserDiaries();

    return diaries.where((diary) =>
        diary.title.toLowerCase().contains(query.toLowerCase()) ||
        diary.content.toLowerCase().contains(query.toLowerCase()) ||
        diary.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase())))
        .toList();
  }

  Future<List<DiaryEntry>> getDiariesByCategory(DiaryCategory category) async {
    final diaries = await getUserDiaries();

    final filteredDiaries = diaries
        .where((diary) => diary.category == category)
        .toList();
    filteredDiaries.sort((a, b) => b.date.compareTo(a.date));
    return filteredDiaries;
  }

  Future<List<DiaryEntry>> getDiariesByDateRange(DateTime start, DateTime end) async {
    final diaries = await getUserDiaries();

    final filteredDiaries = diaries
        .where((diary) =>
          diary.date.isAfter(start.subtract(const Duration(days: 1))) &&
          diary.date.isBefore(end.add(const Duration(days: 1))))
        .toList();
    filteredDiaries.sort((a, b) => b.date.compareTo(a.date));
    return filteredDiaries;
  }
}