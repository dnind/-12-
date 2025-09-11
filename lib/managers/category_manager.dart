import 'package:flutter/material.dart';

class CategoryManager {
  static const List<String> predefinedCategories = [
    '업무',      // 직장/업무 관련
    '개인',      // 개인적인 일
    '학습',      // 공부/교육
    '건강',      // 운동/건강관리
    '생활',      // 일상생활/집안일
    '쇼핑',      // 구매/쇼핑
    '사교',      // 인맥/모임
    '취미',      // 여가/취미
    '여행',      // 여행/외출
    '금융',      // 돈/투자/금융
    '가족',      // 가족 관련
    '긴급',      // 긴급한 일
    '기타',      // 사용자 정의
  ];

  static Map<String, Color> categoryColors = {
    '업무': Colors.blue,
    '개인': Colors.green,
    '학습': Colors.purple,
    '건강': Colors.red,
    '생활': Colors.brown,
    '쇼핑': Colors.orange,
    '사교': Colors.pink,
    '취미': Colors.indigo,
    '여행': Colors.teal,
    '금융': Colors.amber,
    '가족': Colors.deepPurple,
    '긴급': Colors.redAccent,
    '기타': Colors.grey,
  };

  static Map<String, IconData> categoryIcons = {
    '업무': Icons.work,
    '개인': Icons.person,
    '학습': Icons.school,
    '건강': Icons.fitness_center,
    '생활': Icons.home,
    '쇼핑': Icons.shopping_cart,
    '사교': Icons.people,
    '취미': Icons.palette,
    '여행': Icons.flight,
    '금융': Icons.attach_money,
    '가족': Icons.family_restroom,
    '긴급': Icons.warning,
    '기타': Icons.more_horiz,
  };
}