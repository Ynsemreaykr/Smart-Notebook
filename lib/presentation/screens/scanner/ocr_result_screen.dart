// OCR module has been removed — replaced by Notes module.
import 'dart:io';
import 'package:flutter/material.dart';

class OcrResultScreen extends StatelessWidget {
  final File imageFile;
  const OcrResultScreen({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Bu modül kaldırıldı.')),
    );
  }
}
