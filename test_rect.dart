import 'dart:convert';
import 'package:flutter_drawing_board/paint_contents.dart';

void main() {
  var rect = Rectangle();
  print(jsonEncode(rect.toJson()));
}
