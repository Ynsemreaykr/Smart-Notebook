# ML Kit Text Recognition ProGuard / R8 Rules
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.**

-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
