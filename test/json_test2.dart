import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_drawing_board/paint_contents.dart';

void main() {
  test('test rect json', () {
    var rect = Rectangle();
    rect.paint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2.0;
    rect.startPoint = Offset(10, 10);
    rect.endPoint = Offset(50, 50);
    print('Rect: ${jsonEncode(rect.toJson())}');
  });
}
