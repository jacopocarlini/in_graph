import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_graph/main.dart';
import 'package:in_graph/provider/graph_provider.dart';
import 'package:in_graph/model/graph_models.dart';
import 'package:provider/provider.dart';

void main() {
  group('EditorScreen Widget Tests', () {
    testWidgets('App loads successfully', (WidgetTester tester) async {
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MainGraphApp());

      expect(find.byType(MainGraphApp), findsOneWidget);
      expect(find.byType(Material), findsWidgets);
    });

    testWidgets('Toolbar is visible', (WidgetTester tester) async {
      await tester.pumpWidget(const MainGraphApp());

      expect(find.byKey(const Key('editor_toolbar')), findsOneWidget);
    });

    testWidgets('Canvas is visible', (WidgetTester tester) async {
      await tester.pumpWidget(const MainGraphApp());

      // Cerca il canvas
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Sidebar is visible', (WidgetTester tester) async {
      await tester.pumpWidget(const MainGraphApp());

      expect(find.byKey(const Key('graph_tree_sidebar')), findsOneWidget);
    });
  });

  group('GraphProvider Tests', () {
    test('Initial state is correct', () {
      final provider = GraphProvider();

      expect(provider.nodes, isEmpty);
      expect(provider.edges, isEmpty);
      expect(provider.selection, isEmpty);
      expect(provider.activeTool, ToolType.pointer);
      expect(provider.zoomScale, 1.0);
    });

    test('Can add nodes', () {
      final provider = GraphProvider();
      final node = GraphNode(
        id: '1',
        name: 'Test Node',
        position: const Offset(100, 100),
        size: const Size(200, 150),
      );

      provider.addNode(node);

      expect(provider.nodes.length, 1);
      expect(provider.nodes.first.name, 'Test Node');
    });

    test('Can select nodes', () {
      final provider = GraphProvider();
      final node = GraphNode(
        id: '1',
        name: 'Test Node',
        position: const Offset(100, 100),
        size: const Size(200, 150),
      );

      provider.addNode(node);
      provider.setSelection('1');

      expect(provider.selection, contains('1'));
    });

    test('Can delete nodes', () {
      final provider = GraphProvider();
      final node = GraphNode(
        id: '1',
        name: 'Test Node',
        position: const Offset(100, 100),
        size: const Size(200, 150),
      );

      provider.addNode(node);
      provider.setSelection('1');
      provider.deleteSelected();

      expect(provider.nodes, isEmpty);
    });

    test('Can change zoom scale', () {
      final provider = GraphProvider();

      provider.setZoomScale(2.0);
      expect(provider.zoomScale, 2.0);

      provider.setZoomScale(0.5);
      expect(provider.zoomScale, 0.5);
    });

    test('Can change tool', () {
      final provider = GraphProvider();

      provider.setTool(ToolType.node);
      expect(provider.activeTool, ToolType.node);

      provider.setTool(ToolType.edge);
      expect(provider.activeTool, ToolType.edge);

      provider.setTool(ToolType.pointer);
      expect(provider.activeTool, ToolType.pointer);
    });

    test('Can create edges between nodes', () {
      final provider = GraphProvider();
      final node1 = GraphNode(
        id: '1',
        name: 'Node 1',
        position: const Offset(100, 100),
        size: const Size(200, 150),
      );
      final node2 = GraphNode(
        id: '2',
        name: 'Node 2',
        position: const Offset(400, 100),
        size: const Size(200, 150),
      );

      provider.addNode(node1);
      provider.addNode(node2);
      provider.setTool(ToolType.edge);
      provider.startEdge('1');
      provider.updateDraftEdge(const Offset(410, 175));

      // Simulate edge creation by finishing at node 2
      provider.finishEdge(const Offset(410, 175));

      expect(provider.edges, isNotEmpty);
    });

    test('Can move node', () {
      final provider = GraphProvider();
      final node = GraphNode(
        id: '1',
        name: 'Test Node',
        position: const Offset(100, 100),
        size: const Size(200, 150),
      );

      provider.addNode(node);
      provider.setSelection('1');
      provider.moveNode('1', const Offset(50, 50));

      expect(provider.nodes.first.position, const Offset(150, 150));
    });

    test('Can resize node', () {
      final provider = GraphProvider();
      final node = GraphNode(
        id: '1',
        name: 'Test Node',
        position: const Offset(100, 100),
        size: const Size(200, 150),
        isContainer: true,
      );

      provider.addNode(node);
      provider.resizeNode('1', const Size(300, 250));

      expect(provider.nodes.first.size, const Size(300, 250));
    });

    test('Can update node name', () {
      final provider = GraphProvider();
      final node = GraphNode(
        id: '1',
        name: 'Old Name',
        position: const Offset(100, 100),
        size: const Size(200, 150),
      );

      provider.addNode(node);
      provider.updateNameNode('1', 'New Name');

      expect(provider.nodes.first.name, 'New Name');
    });

    test('Can update node color', () {
      final provider = GraphProvider();
      final node = GraphNode(
        id: '1',
        name: 'Test Node',
        position: const Offset(100, 100),
        size: const Size(200, 150),
      );

      provider.addNode(node);
      provider.updateNodeColor('1', Colors.red);

      expect(provider.nodes.first.color, Colors.red);
    });

    test('Selection handles multiple selections', () {
      final provider = GraphProvider();
      final node1 = GraphNode(
        id: '1',
        name: 'Node 1',
        position: const Offset(100, 100),
        size: const Size(200, 150),
      );
      final node2 = GraphNode(
        id: '2',
        name: 'Node 2',
        position: const Offset(400, 100),
        size: const Size(200, 150),
      );

      provider.addNode(node1);
      provider.addNode(node2);

      // Selection should replace previous selection
      provider.setSelection('1');
      expect(provider.selection, ['1']);

      provider.setSelection('2');
      expect(provider.selection, ['2']);
    });

    test('Clear selection works', () {
      final provider = GraphProvider();
      final node = GraphNode(
        id: '1',
        name: 'Test Node',
        position: const Offset(100, 100),
        size: const Size(200, 150),
      );

      provider.addNode(node);
      provider.setSelection('1');
      expect(provider.selection.isNotEmpty, true);

      provider.clearSelection();
      expect(provider.selection, isEmpty);
    });
  });

  group('Node Models Tests', () {
    test('GraphNode copyWith creates copy with updated fields', () {
      final node = GraphNode(
        id: '1',
        name: 'Original',
        position: const Offset(100, 100),
        size: const Size(200, 150),
      );

      final updated = node.copyWith(name: 'Updated');

      expect(node.name, 'Original');
      expect(updated.name, 'Updated');
      expect(updated.id, '1');
    });

    test('GraphEdge creates correctly', () {
      final edge = GraphEdge(
        id: '1',
        sourceId: 'source',
        targetId: 'target',
        label: 'connection',
      );

      expect(edge.sourceId, 'source');
      expect(edge.targetId, 'target');
      expect(edge.label, 'connection');
    });
  });
}

