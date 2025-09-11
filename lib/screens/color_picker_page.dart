import 'package:flutter/material.dart';

class ColorPickerPage extends StatelessWidget {
  const ColorPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('컬러 선택')),
      body: const Center(
        child: Text('컬러 선택 페이지 (구현 예정)'),
      ),
    );
  }
}