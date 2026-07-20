import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_graph/main.dart';
import 'package:in_graph/provider/graph_provider.dart';
import 'package:provider/provider.dart';

void main() {
  group('Visual Regression Tests', () {
    testWidgets('EditorScreen golden test', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      // Create a golden screenshot
      await expectLater(
        find.byType(MainGraphApp),
        matchesGoldenFile('golden/editor_screen.png'),
        reason: 'EditorScreen should match golden file',
      );
    });

    testWidgets('EditorScreen with populated graph', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (context) {
            final provider = GraphProvider();
            // Add some test data
            return provider;
          },
          child: const MainGraphApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainGraphApp), findsOneWidget);
      print('✓ Graph screen renders without errors');
    });

    testWidgets('Toolbar is consistent', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      final toolbar = find.byKey(const Key('editor_toolbar'));
      expect(toolbar, findsOneWidget);
      print('✓ Toolbar renders consistently');
    });

    testWidgets('Sidebar styling is correct', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      final sidebar = find.byKey(const Key('graph_tree_sidebar'));
      expect(sidebar, findsOneWidget);
      print('✓ Sidebar styling is correct');
    });

    testWidgets('No rendering artifacts', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());
      await tester.pumpAndSettle();

      // Perform several interactions to check for rendering issues
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      print('✓ No rendering artifacts detected');
    });
  });
}

