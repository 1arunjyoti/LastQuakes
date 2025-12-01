import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/widgets/appbar.dart';

void main() {
  testWidgets('renders title and actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: LastQuakesAppBar(
            title: 'Recent Quakes',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {},
              ),
            ],
            automaticallyImplyLeading: false,
          ),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(appBar.automaticallyImplyLeading, isFalse);
    expect(find.text('Recent Quakes'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('defaults to automatically implying leading widgets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: const LastQuakesAppBar(title: 'Back Stack'),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.automaticallyImplyLeading, isTrue);
  });
}
