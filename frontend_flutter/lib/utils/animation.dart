import 'package:flutter/material.dart';

// TODO:
// Rotate card animation
Route createSlideFadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(animation),
        child: page,
      ),
    ),
    transitionDuration: const Duration(milliseconds: 500),
  );
}
