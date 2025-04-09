import 'package:flutter/material.dart';

class AppGradients {
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE53935), // Lighter shade of red
      Color(0xFFD32F2F), // Colors.red.shade700
      Color(0xFFB71C1C), // Darker shade of red
    ],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF57C00), // Lighter shade of orange
      Color(0xFFEF6C00), // Orange
      Color(0xFFE65100), // Darker shade of orange
    ],
  );
}
