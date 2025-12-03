import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:lastquakes/domain/usecases/get_earthquakes_usecase.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

class MockGetEarthquakesUseCase extends Mock implements GetEarthquakesUseCase {}

void main() {
  testWidgets('EarthquakeProvider smoke test', (WidgetTester tester) async {
    final mockGetEarthquakesUseCase = MockGetEarthquakesUseCase();

    // Build app with provider
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create:
                (_) => EarthquakeProvider(
                  getEarthquakesUseCase: mockGetEarthquakesUseCase,
                ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer<EarthquakeProvider>(
              builder: (context, provider, _) {
                return const Text('Provider Loaded');
              },
            ),
          ),
        ),
      ),
    );

    // Verify it builds and finds provider
    expect(find.text('Provider Loaded'), findsOneWidget);
  });
}
