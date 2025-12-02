import 'package:flutter/material.dart';

/// Optimized page transitions for the LastQuake app.
/// All transitions use fast durations and efficient curves to prevent slowness.
class AppPageTransitions {
  // Fast, snappy duration for all transitions
  static const Duration _transitionDuration = Duration(milliseconds: 250);

  // Smooth, efficient curve
  static const Curve _transitionCurve = Curves.easeInOutCubic;

  /// Slide transition from right (default forward navigation)
  /// Optimized for drawer navigation and forward flows
  static Route<T> slideRoute<T>({
    required Widget page,
    RouteSettings? settings,
    AxisDirection direction = AxisDirection.left,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Determine offset based on direction
        Offset begin;
        switch (direction) {
          case AxisDirection.left:
            begin = const Offset(1.0, 0.0); // Slide from right
            break;
          case AxisDirection.right:
            begin = const Offset(-1.0, 0.0); // Slide from left
            break;
          case AxisDirection.up:
            begin = const Offset(0.0, 1.0); // Slide from bottom
            break;
          case AxisDirection.down:
            begin = const Offset(0.0, -1.0); // Slide from top
            break;
        }

        const end = Offset.zero;

        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: _transitionCurve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  /// Fade transition for modal-style screens
  /// Optimized for map picker and overlay screens
  static Route<T> fadeRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: _transitionCurve).animate(animation),
          child: child,
        );
      },
    );
  }

  /// Scale + Fade transition for detail views
  /// Optimized for earthquake detail screens with smooth zoom effect
  static Route<T> scaleRoute<T>({
    required Widget page,
    RouteSettings? settings,
    double initialScale = 0.9,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurveTween(
          curve: _transitionCurve,
        ).animate(animation);

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: initialScale,
              end: 1.0,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  /// Shared axis transition (material design pattern)
  /// Alternative option for horizontal transitions with fade
  static Route<T> sharedAxisRoute<T>({
    required Widget page,
    RouteSettings? settings,
    bool isHorizontal = true,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurveTween(
          curve: _transitionCurve,
        ).animate(animation);

        // Incoming page
        final incomingOffset =
            isHorizontal
                ? Tween<Offset>(
                  begin: const Offset(0.05, 0.0),
                  end: Offset.zero,
                ).animate(curvedAnimation)
                : Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(curvedAnimation);

        return SlideTransition(
          position: incomingOffset,
          child: FadeTransition(opacity: curvedAnimation, child: child),
        );
      },
    );
  }
}
