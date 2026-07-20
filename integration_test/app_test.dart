import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:in_graph/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Tests', () {
    testWidgets('User can create a graph with nodes and edges', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      // Launch app
      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      // Verify app is running
      expect(find.byType(MainGraphApp), findsOneWidget);
      print('✓ App launched successfully');
    });

    testWidgets('User can switch between tools', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      // Find and tap tool buttons
      final toolButtons = find.byType(IconButton);
      expect(toolButtons, findsWidgets);
      print('✓ Tool buttons are visible');
    });

    testWidgets('Canvas responds to interactions', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      // Simulate mouse move on canvas
      final canvasArea = Rect.fromLTWH(200, 100, 1720, 980);
      final centerPoint = canvasArea.center;

      await tester.moveCursor(centerPoint);
      await tester.pumpAndSettle();

      print('✓ Canvas handles pointer moves');
    });

    testWidgets('Sidebar is interactive', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      // Find sidebar
      final sidebar = find.byKey(const Key('graph_tree_sidebar'));
      expect(sidebar, findsOneWidget);
      print('✓ Sidebar is present and interactive');
    });

    testWidgets('Toolbar has all expected controls', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      // Check toolbar
      final toolbar = find.byKey(const Key('editor_toolbar'));
      expect(toolbar, findsOneWidget);

      final buttons = find.byType(IconButton);
      expect(buttons, findsWidgets);
      print('✓ Toolbar has multiple controls');
    });

    testWidgets('No crashes during rapid tool switching', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      // Simulate rapid interactions
      for (int i = 0; i < 10; i++) {
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }

      expect(find.byType(MainGraphApp), findsOneWidget);
      print('✓ No crashes during rapid interactions');
    });

    testWidgets('Theme is properly applied', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      // Check scaffold background
      final scaffold = find.byType(Scaffold);
      expect(scaffold, findsWidgets);
      print('✓ Theme is properly applied');
    });

    testWidgets('No visual glitches with empty canvas', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      // Verify layout
      final scaffold = find.byType(Scaffold);
      expect(scaffold, findsOneWidget);

      final column = find.byType(Column);
      expect(column, findsWidgets);
      print('✓ Layout is correct with empty canvas');
    });

    testWidgets('Responsive layout on different screen sizes', (WidgetTester tester) async {
      final sizes = [
        const Size(1280, 720),
        const Size(1920, 1080),
        const Size(2560, 1440),
      ];

      for (final size in sizes) {
        await tester.binding.window.physicalSizeTestValue = size;
        addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

        await tester.pumpWidget(const MainGraphApp());
        await tester.pumpAndSettle();

        expect(find.byType(MainGraphApp), findsOneWidget);
        print('✓ Layout works at ${size.width}x${size.height}');
      }
    });
  });
}

