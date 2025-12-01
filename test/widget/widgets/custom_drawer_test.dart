import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget _buildTestApp({
    required GlobalKey<ScaffoldState> scaffoldKey,
    NavigatorObserver? observer,
  }) {
    return ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        navigatorObservers: observer != null ? [observer] : const [],
        home: _DrawerHost(scaffoldKey: scaffoldKey),
      ),
    );
  }

  Future<void> _openDrawer(
    WidgetTester tester,
    GlobalKey<ScaffoldState> scaffoldKey,
  ) async {
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('renders all navigation destinations', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(_buildTestApp(scaffoldKey: scaffoldKey));
    await tester.pump();

    await _openDrawer(tester, scaffoldKey);

    expect(find.text('Preparedness & Safety'), findsOneWidget);
    expect(find.text('Emergency Contacts'), findsOneWidget);
    expect(find.text('Test Your Knowledge'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('navigates to destination screen when tapped', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(_buildTestApp(scaffoldKey: scaffoldKey));
    await tester.pump();

    await _openDrawer(tester, scaffoldKey);

    await tester.tap(find.text('Preparedness & Safety'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Earthquake Preparedness'), findsOneWidget);
  });
}

class _DrawerHost extends StatelessWidget {
  const _DrawerHost({required this.scaffoldKey});

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(),
      drawer: const CustomDrawer(),
      body: const SizedBox.shrink(),
    );
  }
}
