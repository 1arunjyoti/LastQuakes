import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:lastquake/screens/home_screen.dart';
import 'package:lastquake/utils/app_page_transitions.dart';
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

  Widget _buildImage(IconData icon, Color color) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(child: Icon(icon, size: 80, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 18.0, color: Colors.black54);

    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 26.0,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      bodyTextStyle: bodyStyle,
      bodyPadding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.only(top: 40),
      imageFlex: 2,
      bodyFlex: 3,
    );

    return IntroductionScreen(
      globalBackgroundColor: Colors.white,
      allowImplicitScrolling: true,

      pages: [
        PageViewModel(
          title: "Global Monitoring",
          body:
              "Track seismic activity worldwide in real-time from reliable sources.",
          image: _buildImage(FontAwesomeIcons.earthAmericas, Colors.blue),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Interactive Maps",
          body:
              "Visualize earthquake locations and magnitudes on detailed interactive maps.",
          image: _buildImage(FontAwesomeIcons.mapLocationDot, Colors.teal),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Smart Alerts",
          body:
              "Create Safe Zones and receive instant notifications for earthquakes near you.",
          image: _buildImage(FontAwesomeIcons.bell, Colors.orange),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Detailed Insights",
          body:
              "Analyze historical data and trends with comprehensive statistics.",
          image: _buildImage(FontAwesomeIcons.chartLine, Colors.purple),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      skipOrBackFlex: 0,
      nextFlex: 0,
      showBackButton: false,
      back: const Icon(Icons.arrow_back),
      skip: const Text(
        'Skip',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
      ),
      next: const Icon(Icons.arrow_forward, color: Colors.blue),
      done: const Text(
        'Get Started',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
      ),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.all(16),
      controlsPadding:
          kIsWeb
              ? const EdgeInsets.all(12.0)
              : const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        color: Color(0xFFBDBDBD),
        activeSize: Size(22.0, 10.0),
        activeColor: Colors.blue,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
    );
  }
}
