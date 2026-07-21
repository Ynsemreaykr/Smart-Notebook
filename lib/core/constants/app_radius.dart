import 'package:flutter/material.dart';

class AppRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double circular = 30.0;

  // BorderRadius templates
  static final BorderRadius rSmall = BorderRadius.circular(small);
  static final BorderRadius rMedium = BorderRadius.circular(medium);
  static final BorderRadius rLarge = BorderRadius.circular(large);
  static final BorderRadius rCircular = BorderRadius.circular(circular);

  // Radius templates
  static const Radius radSmall = Radius.circular(small);
  static const Radius radMedium = Radius.circular(medium);
  static const Radius radLarge = Radius.circular(large);
  static const Radius radCircular = Radius.circular(circular);
}
