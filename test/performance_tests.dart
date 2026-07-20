import 'package:flutter_test/flutter_test.dart';
import 'package:in_graph/provider/graph_provider.dart';
import 'package:in_graph/model/graph_models.dart';
import 'package:flutter/material.dart';

void main() {
  group('Performance Tests', () {
    test('Adding 100 nodes should complete in reasonable time', () async {
      final provider = GraphProvider();
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        final node = GraphNode(
          id: i.toString(),
          name: 'Node $i',
          position: Offset((i % 10) * 250.0, (i ~/ 10) * 200.0),
          size: const Size(200, 150),
        );
        provider.addNode(node);
      }

      stopwatch.stop();

      expect(provider.nodes.length, 100);
      // Should complete in less than 500ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason: 'Adding 100 nodes took ${stopwatch.elapsedMilliseconds}ms',
      );
      print('✓ Added 100 nodes in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Creating 50 edges should complete in reasonable time', () async {
      final provider = GraphProvider();

      // First add 10 nodes
      for (int i = 0; i < 10; i++) {
        final node = GraphNode(
          id: i.toString(),
          name: 'Node $i',
          position: Offset((i % 5) * 250.0, (i ~/ 5) * 200.0),
          size: const Size(200, 150),
        );
        provider.addNode(node);
      }

      final stopwatch = Stopwatch()..start();

      // Create edges
      for (int i = 0; i < 5; i++) {
        for (int j = i + 1; j < 10; j++) {
          final edge = GraphEdge(
            id: '$i-$j',
            sourceId: i.toString(),
            targetId: j.toString(),
          );
          provider.edges.add(edge);
        }
      }

      stopwatch.stop();

      expect(provider.edges.isNotEmpty, true);
      // Should complete in less than 200ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(200),
        reason: 'Adding edges took ${stopwatch.elapsedMilliseconds}ms',
      );
      print('✓ Created edges in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Moving nodes should be responsive', () async {
      final provider = GraphProvider();

      // Add 50 nodes
      for (int i = 0; i < 50; i++) {
        final node = GraphNode(
          id: i.toString(),
          name: 'Node $i',
          position: Offset((i % 10) * 250.0, (i ~/ 10) * 200.0),
          size: const Size(200, 150),
        );
        provider.addNode(node);
      }

      final stopwatch = Stopwatch()..start();

      // Move multiple nodes
      for (int i = 0; i < 50; i++) {
        provider.setSelection(i.toString());
        provider.moveNode(i.toString(), const Offset(10, 10));
      }

      stopwatch.stop();

      // Should complete in less than 300ms for 50 nodes
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(300),
        reason: 'Moving 50 nodes took ${stopwatch.elapsedMilliseconds}ms',
      );
      print('✓ Moved 50 nodes in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Resizing containers should be efficient', () async {
      final provider = GraphProvider();

      // Add 20 containers
      for (int i = 0; i < 20; i++) {
        final node = GraphNode(
          id: i.toString(),
          name: 'Container $i',
          position: Offset((i % 5) * 350.0, (i ~/ 5) * 350.0),
          size: const Size(300, 250),
          isContainer: true,
        );
        provider.addNode(node);
      }

      final stopwatch = Stopwatch()..start();

      // Resize all containers
      for (int i = 0; i < 20; i++) {
        provider.resizeNode(i.toString(), const Size(400, 350));
      }

      stopwatch.stop();

      // Should complete in less than 200ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(200),
        reason: 'Resizing 20 containers took ${stopwatch.elapsedMilliseconds}ms',
      );
      print('✓ Resized 20 containers in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Changing zoom should be instant', () async {
      final provider = GraphProvider();

      final stopwatch = Stopwatch()..start();

      for (double zoom = 0.1; zoom <= 5.0; zoom += 0.1) {
        provider.setZoomScale(zoom);
      }

      stopwatch.stop();

      expect(provider.zoomScale, closeTo(5.0, 0.01));
      // Should complete in less than 50ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(50),
        reason: 'Zoom changes took ${stopwatch.elapsedMilliseconds}ms',
      );
      print('✓ Changed zoom 50 times in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Selection from rect with many nodes should be fast', () async {
      final provider = GraphProvider();

      // Add 100 nodes
      for (int i = 0; i < 100; i++) {
        final node = GraphNode(
          id: i.toString(),
          name: 'Node $i',
          position: Offset((i % 10) * 250.0, (i ~/ 10) * 200.0),
          size: const Size(200, 150),
        );
        provider.addNode(node);
      }

      final stopwatch = Stopwatch()..start();

      // Select a rect containing multiple nodes
      final selectionRect = Rect.fromLTWH(0, 0, 1000, 1000);
      provider.updateSelectionFromRect(selectionRect);

      stopwatch.stop();

      // Should complete in less than 100ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: 'Rect selection took ${stopwatch.elapsedMilliseconds}ms',
      );
      expect(provider.selection.isNotEmpty, true);
      print('✓ Selected from rect in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Getting visible nodes should be efficient', () async {
      final provider = GraphProvider();

      // Add 50 nodes with some hierarchy
      for (int i = 0; i < 50; i++) {
        final node = GraphNode(
          id: i.toString(),
          name: 'Node $i',
          position: Offset((i % 10) * 250.0, (i ~/ 10) * 200.0),
          size: const Size(200, 150),
          parentId: i > 0 && i % 5 == 0 ? '${i - 5}' : null,
        );
        provider.addNode(node);
      }

      final stopwatch = Stopwatch()..start();

      // Get visible nodes multiple times
      for (int i = 0; i < 100; i++) {
        final visible = provider.visibleNodes;
        expect(visible, isNotEmpty);
      }

      stopwatch.stop();

      // Should complete in less than 100ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: 'Getting visible nodes 100 times took ${stopwatch.elapsedMilliseconds}ms',
      );
      print('✓ Got visible nodes 100 times in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Memory usage should be reasonable with large graph', () async {
      final provider = GraphProvider();

      // Create a large graph
      for (int i = 0; i < 200; i++) {
        final node = GraphNode(
          id: i.toString(),
          name: 'Node $i',
          position: Offset((i % 20) * 250.0, (i ~/ 20) * 200.0),
          size: const Size(200, 150),
        );
        provider.addNode(node);
      }

      for (int i = 0; i < 100; i++) {
        for (int j = i + 1; j < i + 5 && j < 200; j++) {
          final edge = GraphEdge(
            id: '$i-$j',
            sourceId: i.toString(),
            targetId: j.toString(),
          );
          provider.edges.add(edge);
        }
      }

      expect(provider.nodes.length, 200);
      expect(provider.edges.isNotEmpty, true);
      print('✓ Large graph created: ${provider.nodes.length} nodes, ${provider.edges.length} edges');
    });

    test('Load from graph data should be fast', () async {
      final provider = GraphProvider();

      final nodes = List.generate(
        100,
        (i) => GraphNode(
          id: i.toString(),
          name: 'Node $i',
          position: Offset((i % 10) * 250.0, (i ~/ 10) * 200.0),
          size: const Size(200, 150),
        ),
      );

      final edges = <GraphEdge>[];
      for (int i = 0; i < 50; i++) {
        edges.add(GraphEdge(
          id: i.toString(),
          sourceId: i.toString(),
          targetId: ((i + 1) % 100).toString(),
        ));
      }

      final stopwatch = Stopwatch()..start();
      provider.loadFromGraphData(nodes, edges);
      stopwatch.stop();

      expect(provider.nodes.length, 100);
      expect(provider.edges.length, 50);
      // Should complete in less than 100ms
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: 'Loading graph took ${stopwatch.elapsedMilliseconds}ms',
      );
      print('✓ Loaded graph in ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}

