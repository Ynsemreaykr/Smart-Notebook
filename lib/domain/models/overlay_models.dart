import 'dart:ui';

class ImageOverlay {
  String id;
  String base64Data;
  Offset position;
  Size size;

  ImageOverlay({
    required this.id,
    required this.base64Data,
    this.position = Offset.zero,
    this.size = const Size(200, 150),
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'base64Data': base64Data,
    'position': {'dx': position.dx, 'dy': position.dy},
    'size': {'w': size.width, 'h': size.height},
  };

  factory ImageOverlay.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>?;
    final sz = json['size'] as Map<String, dynamic>?;
    return ImageOverlay(
      id: json['id'] as String,
      base64Data: json['base64Data'] as String,
      position: pos != null ? Offset((pos['dx'] as num).toDouble(), (pos['dy'] as num).toDouble()) : Offset.zero,
      size: sz != null ? Size((sz['w'] as num).toDouble(), (sz['h'] as num).toDouble()) : const Size(200, 150),
    );
  }
}

class TextBoxOverlay {
  String id;
  String text;
  Offset position;
  Size size;
  double fontSize;
  String fontFamily;
  int textColorValue;
  bool isBold;
  bool isItalic;

  TextBoxOverlay({
    required this.id,
    this.text = '',
    this.position = const Offset(50, 100),
    this.size = const Size(200, 100),
    this.fontSize = 16.0,
    this.fontFamily = 'Roboto',
    this.textColorValue = 0xFF000000,
    this.isBold = false,
    this.isItalic = false,
  });

  Color get textColor => Color(textColorValue);

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'position': {'dx': position.dx, 'dy': position.dy},
    'size': {'w': size.width, 'h': size.height},
    'fontSize': fontSize,
    'fontFamily': fontFamily,
    'textColorValue': textColorValue,
    'isBold': isBold,
    'isItalic': isItalic,
  };

  factory TextBoxOverlay.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>?;
    final sz = json['size'] as Map<String, dynamic>?;
    return TextBoxOverlay(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      position: pos != null ? Offset((pos['dx'] as num).toDouble(), (pos['dy'] as num).toDouble()) : const Offset(50, 100),
      size: sz != null ? Size((sz['w'] as num).toDouble(), (sz['h'] as num).toDouble()) : const Size(200, 100),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      fontFamily: json['fontFamily'] as String? ?? 'Roboto',
      textColorValue: json['textColorValue'] as int? ?? 0xFF000000,
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
    );
  }
}
