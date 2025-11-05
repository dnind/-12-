class AiPromptService {
  /// 일정 기반 프롬프트 생성
  static String buildPrompt({
    required String title,
    required String description,
    required DateTime date,
    String? location,
  }) {
    final dateStr = "${date.year}년 ${date.month}월 ${date.day}일";

    return """
당신은 다이어리 꾸미기 전문가이자 스티커 디자이너입니다.
사용자가 작성한 일정을 바탕으로, 감각적인 다꾸 스타일을 추천해주세요.

[일정 정보]
- 제목: $title
- 설명: $description
- 날짜: $dateStr
- 위치: ${location ?? "정보 없음"}

[출력 형식]
1. 추천 스티커 (이모지 3~5개, 배열 형태, 예: ["📚","☕","✏️"])
2. 추천 색상 HEX 코드 (예: #FFB6C1)
3. 추천 스타일 키워드 (예: "따뜻한 분위기, 공부 집중, 깔끔함")

[조건]
- 한국어로 출력
- JSON 형식으로만 응답
- 다른 불필요한 문장은 포함하지 말 것

출력 예시:
{
  "stickers": ["📚","☕","✏️"],
  "color": "#FFB6C1",
  "style": "따뜻한 분위기, 공부 집중, 깔끔함"
}
    """;
  }
}
