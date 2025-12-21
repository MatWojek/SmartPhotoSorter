import 'package:flutter/material.dart';

class ClassicStyle {
  ClassicStyle._();

  // colors (hex / rgb)

  // darkmode
  static const Color navy = Color(0xFF0F044C); 
  static const Color violet = Color(0xFF141E61); 
  static const Color light_gray = Color(0xFF787A91);
  static const Color new_white = Color(0xFFEEEEEE);

  // lightmode
  static const Color blue = Color(0xFF3674B5); 
  static const Color medium_blue = Color(0xFF578FCA); 
  static const Color light_blue = Color(0xFFA1E3F9);
  static const Color mint_green = Color(0xFFD1F8EF);

  // texts styles
  static const TextStyle title =
      TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black);
}
