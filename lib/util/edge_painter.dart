import 'dart:math';
import 'package:flutter/material.dart';
import '../provider/graph_provider.dart';
import '../model/graph_models.dart';
import 'edge_routing_service.dart';

class EdgePainter extends CustomPainter {
  final GraphProvider provider;

  EdgePainter({required this.provider}) : super(repaint: provider);

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = Colors.blueGrey
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final aggregatedPaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final aggregatedEdges = provider.getAggregatedEdges();

    // 1. Mappatura degli slot per evitare sovrapposizioni (Port Slotting)
    final Map<String, List<String>> edgesBySource = {};
    final Map<String, List<String>> edgesByTarget = {};

    for (var edge in aggregatedEdges) {
      edgesBySource.putIfAbsent(edge.sourceId, () => []).add(edge.id);
      edgesByTarget.putIfAbsent(edge.targetId, () => []).add(edge.id);
    }

    // 2. Disegna gli Edge esistenti con instradamento parallelo completo
    for (var edge in aggregatedEdges) {
      final source = provider.nodes.firstWhere((n) => n.id == edge.sourceId);
      final target = provider.nodes.firstWhere((n) => n.id == edge.targetId);

      final sRect = Rect.fromLTWH(
        source.position.dx,
        source.position.dy,
        source.size.width,
        source.size.height,
      );
      final tRect = Rect.fromLTWH(
        target.position.dx,
        target.position.dy,
        target.size.width,
        target.size.height,
      );

      // Trova l'indice di questo specifico arco tra quelli collegati allo stesso nodo
      final sourceIndex = edgesBySource[edge.sourceId]!.indexOf(edge.id);
      final sourceTotal = edgesBySource[edge.sourceId]!.length;

      final targetIndex = edgesByTarget[edge.targetId]!.indexOf(edge.id);
      final targetTotal = edgesByTarget[edge.targetId]!.length;

      // Capiamo la direzione generale per scegliere l'asse di sdoppiamento delle porte
      final dx = tRect.center.dx - sRect.center.dx;
      final dy = tRect.center.dy - sRect.center.dy;

      Offset sOffset = Offset.zero;
      Offset tOffset = Offset.zero;

      if (dx.abs() > dy.abs()) {
        // Direzione Orizzontale -> Sdoppiamo gli ingressi/uscite in Verticale (Y)
        if (sourceTotal > 1) {
          final step = ((source.size.height * 0.6) / (sourceTotal - 1)).clamp(8.0, 16.0);
          sOffset = Offset(0, (sourceIndex - (sourceTotal - 1) / 2) * step);
        }
        if (targetTotal > 1) {
          final step = ((target.size.height * 0.6) / (targetTotal - 1)).clamp(8.0, 16.0);
          tOffset = Offset(0, (targetIndex - (targetTotal - 1) / 2) * step);
        }
      } else {
        // Direzione Verticale -> Sdoppiamo gli ingressi/uscite in Orizzontale (X)
        if (sourceTotal > 1) {
          final step = ((source.size.width * 0.6) / (sourceTotal - 1)).clamp(8.0, 16.0);
          sOffset = Offset((sourceIndex - (sourceTotal - 1) / 2) * step, 0);
        }
        if (targetTotal > 1) {
          final step = ((target.size.width * 0.6) / (targetTotal - 1)).clamp(8.0, 16.0);
          tOffset = Offset((targetIndex - (targetTotal - 1) / 2) * step, 0);
        }
      }

      // Spostiamo i punti di aggancio sui nodi creando dei Rect virtuali
      final virtualSRect = sRect.shift(sOffset);
      final virtualTRect = tRect.shift(tOffset);

      // === COSTRUIAMO IL DISLIVELLO PER I GOMITI INTERMEDI ===
      final int globalIndex = provider.edges.indexOf(edge);
      final double laneOffset = (globalIndex % 6) * 12.0;

      List<Rect> obstacles = [];
      for (var node in provider.nodes) {
        if (node.id == edge.sourceId || node.id == edge.targetId) continue;
        obstacles.add(Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height));
      }

// Passa il laneOffset!
      Path path = EdgeRoutingService.calculateOrthogonalPath(
        virtualSRect,
        virtualTRect,
        obstacles: obstacles,
        laneOffset: laneOffset, // <-- L'aggiornamento magico
      );

      // Accorciamo al millimetro sul bordo reale del nodo target
      path = _shortenPathToRect(path, tRect);

      final isAggregated = edge.count > 1;
      final isSelected = provider.selectedEdgeIds.contains(edge.id);

      // Definiamo il tipo di stile in base allo stato di selezione
      Paint currentPaint;
      if (isSelected) {
        currentPaint = Paint()
          ..color = Colors.blueAccent // Colore freccia selezionata
          ..strokeWidth = 3.5          // Più spessa per risaltare
          ..style = PaintingStyle.stroke;
      } else {
        currentPaint = isAggregated ? aggregatedPaint : edgePaint;
      }

      canvas.drawPath(path, currentPaint);

      _drawArrowhead(
        canvas,
        path,
        isSelected ? Colors.blueAccent : (isAggregated ? Colors.blueAccent : Colors.blueGrey),
      );
      }

    // 3. Disegna l'Edge temporaneo (Ghost Edge durante il drag)
    if (provider.tempEdge != null) {
      final temp = provider.tempEdge!;
      final source = provider.nodes.firstWhere(
            (n) => n.id == temp.sourceId,
        orElse: () => provider.nodes.first,
      );

      final sourceCenter = Offset(
        source.position.dx + source.size.width / 2,
        source.position.dy + source.size.height / 2,
      );

      Path ghostPath = Path()
        ..moveTo(sourceCenter.dx, sourceCenter.dy)
        ..lineTo(temp.currentPosition.dx, temp.currentPosition.dy);

      GraphNode? hoverTarget;
      for (var node in provider.nodes.reversed) {
        if (node.id == temp.sourceId) continue;
        final rect = Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);
        if (rect.contains(temp.currentPosition)) {
          hoverTarget = node;
          break;
        }
      }

      if (hoverTarget != null) {
        final tRect = Rect.fromLTWH(
          hoverTarget.position.dx,
          hoverTarget.position.dy,
          hoverTarget.size.width,
          hoverTarget.size.height,
        );
        ghostPath = _shortenPathToRect(ghostPath, tRect);
      }

      final ghostPaint = Paint()
        ..color = Colors.blue.withOpacity(0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawPath(ghostPath, ghostPaint);
      _drawArrowhead(canvas, ghostPath, Colors.blue.withOpacity(0.6));
    }
  }

  /// Taglia il path esattamente sul perimetro del Rect di destinazione
  Path _shortenPathToRect(Path originalPath, Rect targetRect) {
    final metrics = originalPath.computeMetrics().toList();
    if (metrics.isEmpty) return originalPath;

    final lastMetric = metrics.last;
    final endTangent = lastMetric.getTangentForOffset(lastMetric.length);
    if (endTangent == null || !targetRect.contains(endTangent.position)) {
      return originalPath;
    }

    double low = 0;
    double high = lastMetric.length;
    double targetOffset = lastMetric.length;

    for (int i = 0; i < 12; i++) {
      double mid = (low + high) / 2;
      final tangent = lastMetric.getTangentForOffset(mid);
      if (tangent != null) {
        if (targetRect.contains(tangent.position)) {
          high = mid;
          targetOffset = mid;
        } else {
          low = mid;
        }
      }
    }

    final newPath = Path();
    for (int i = 0; i < metrics.length - 1; i++) {
      newPath.addPath(metrics[i].extractPath(0, metrics[i].length), Offset.zero);
    }
    newPath.addPath(lastMetric.extractPath(0, targetOffset), Offset.zero);

    return newPath;
  }

  /// Disegna la punta della freccia perfettamente orientata sul finale del tracciato
  void _drawArrowhead(Canvas canvas, Path path, Color color) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final lastMetric = metrics.last;
    final tangent = lastMetric.getTangentForOffset(lastMetric.length);
    if (tangent == null) return;

    final angle = atan2(tangent.vector.dy, tangent.vector.dx);
    final arrowSize = 12.0;

    final arrowPath = Path()
      ..moveTo(tangent.position.dx, tangent.position.dy)
      ..lineTo(
        tangent.position.dx - arrowSize * cos(angle - pi / 6),
        tangent.position.dy - arrowSize * sin(angle - pi / 6),
      )
      ..lineTo(
        tangent.position.dx - arrowSize * cos(angle + pi / 6),
        tangent.position.dy - arrowSize * sin(angle + pi / 6),
      )
      ..close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant EdgePainter oldDelegate) => true;
}