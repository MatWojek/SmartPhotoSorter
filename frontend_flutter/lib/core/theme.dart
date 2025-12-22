import 'package:flutter/material.dart';

class ClassicStyle {
  ClassicStyle._();

  // colors (hex / rgb)

  // darkmode
  static const Color navy = Color.fromARGB(255, 25, 8, 124); 
  static const Color violet = Color.fromARGB(255, 29, 44, 141); 
  static const Color lightGray = Color(0xFF787A91);
  static const Color newWhite = Color(0xFFEEEEEE);

  // lightmode
  static const Color blue = Color(0xFF3674B5); 
  static const Color mediumBlue = Color(0xFF578FCA); 
  static const Color lightBlue = Color(0xFFA1E3F9);
  static const Color mintGreen = Color(0xFFD1F8EF);

  // texts styles
  static const TextStyle title =
      TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black);
}
