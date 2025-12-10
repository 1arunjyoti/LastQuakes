import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:lastquakes/screens/home_screen.dart';
import 'package:lastquakes/utils/app_page_transitions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatelessWidget {
  final SharedPreferences prefs;

  const OnboardingScreen({super.key, required this.prefs});

  Future<void> _onIntroEnd(BuildContext context) async {
    await prefs.setBool('seenOnboarding', true);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        AppPageTransitions.fadeRoute(page: const NavigationHandler()),
      );
    }
  }

  Widget _buildImage(BuildContext context, IconData icon, Color iconColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            iconColor.withValues(alpha: isDark ? 0.3 : 0.2),
            iconColor.withValues(alpha: isDark ? 0.1 : 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: isDark ? 0.25 : 0.15),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(child: FaIcon(icon, size: 56, color: iconColor)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bodyStyle = TextStyle(
      fontSize: 17.0,
      color: colorScheme.onSurface.withValues(alpha: 0.8),
      height: 1.5,
    );

    final pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 28.0,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
        letterSpacing: -0.5,
      ),
      bodyTextStyle: bodyStyle,
      bodyPadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 24.0),
      pageColor: theme.scaffoldBackgroundColor,
      imagePadding: const EdgeInsets.only(top: 60),
      imageFlex: 2,
      bodyFlex: 3,
      bodyAlignment: Alignment.topCenter,
      imageAlignment: Alignment.bottomCenter,
    );

    final pages = [
      // Page 1: Welcome
      PageViewModel(
        title: "Welcome to LastQuakes",
        body:
            "Your comprehensive earthquake monitoring companion. Stay informed about seismic activity worldwide with real-time data and powerful insights.",
        image: _buildImage(
          context,
          FontAwesomeIcons.houseTsunami,
          colorScheme.primary,
        ),
        decoration: pageDecoration,
      ),
      // Page 2: Global Monitoring
      PageViewModel(
        title: "Global Monitoring",
        body:
            "Track earthquakes in real-time from trusted sources including USGS and EMSC. Get comprehensive coverage of seismic events around the world.",
        image: _buildImage(
          context,
          FontAwesomeIcons.earthAmericas,
          Colors.blue.shade600,
        ),
        decoration: pageDecoration,
      ),
      // Page 3: Interactive Maps
      PageViewModel(
        title: "Interactive Maps",
        body:
            "Explore earthquakes on beautiful interactive maps. Switch between 2D maps and a stunning 3D globe view to visualize seismic activity.",
        image: _buildImage(
          context,
          FontAwesomeIcons.mapLocationDot,
          Colors.teal.shade600,
        ),
        decoration: pageDecoration,
      ),
      // Page 4: Detailed Insights
      PageViewModel(
        title: "Detailed Insights",
        body:
            "Dive deep into earthquake data with comprehensive statistics, historical trends, and magnitude distribution charts.",
        image: _buildImage(
          context,
          FontAwesomeIcons.chartLine,
          Colors.purple.shade600,
        ),
        decoration: pageDecoration,
      ),
    ];

    return IntroductionScreen(
      globalBackgroundColor: theme.scaffoldBackgroundColor,
      allowImplicitScrolling: true,
      pages: pages,
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      skipOrBackFlex: 0,
      nextFlex: 0,
      showBackButton: false,
      back: Icon(Icons.arrow_back, color: colorScheme.primary),
      skip: Text(
        'Skip',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      next: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.arrow_forward, color: colorScheme.primary),
      ),
      done: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'Get Started',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.all(20),
      controlsPadding:
          kIsWeb
              ? const EdgeInsets.all(12.0)
              : const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      dotsDecorator: DotsDecorator(
        size: const Size(8.0, 8.0),
        color: colorScheme.onSurface.withValues(alpha: 0.2),
        activeSize: const Size(24.0, 8.0),
        activeColor: colorScheme.primary,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}
