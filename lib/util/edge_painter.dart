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

    // 1. Mappatura degli slot usando i nodi EFFETTIVI VISIBILI
    final Map<String, List<String>> edgesBySource = {};
    final Map<String, List<String>> edgesByTarget = {};

    for (var edge in aggregatedEdges) {
      final effSource = _getEffectiveNode(edge.sourceId, provider);
      final effTarget = _getEffectiveNode(edge.targetId, provider);

      // Mappiamo solo se entrambi esistono e non puntano allo stesso container
      if (effSource != null && effTarget != null && effSource.id != effTarget.id) {
        edgesBySource.putIfAbsent(effSource.id, () => []).add(edge.id);
        edgesByTarget.putIfAbsent(effTarget.id, () => []).add(edge.id);
      }
    }

    // 2. Disegna gli Edge esistenti
    for (var edge in aggregatedEdges) {
      final source = _getEffectiveNode(edge.sourceId, provider);
      final target = _getEffectiveNode(edge.targetId, provider);

      // Se manca un capo, o se è un arco interno a un container collassato, saltiamo
      if (source == null || target == null) continue;
      if (source.id == target.id) continue;

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

      // Usiamo gli ID dei nodi effettivi per il Port Slotting
      final sourceIndex = edgesBySource[source.id]!.indexOf(edge.id);
      final sourceTotal = edgesBySource[source.id]!.length;

      final targetIndex = edgesByTarget[target.id]!.indexOf(edge.id);
      final targetTotal = edgesByTarget[target.id]!.length;

      // Capiamo la direzione generale per scegliere l'asse di sdoppiamento delle porte
      final dx = tRect.center.dx - sRect.center.dx;
      final dy = tRect.center.dy - sRect.center.dy;

      Offset sOffset = Offset.zero;
      Offset tOffset = Offset.zero;

      if (dx.abs() > dy.abs()) {
        // Direzione Orizzontale -> Sdoppiamo in Verticale (Y)
        if (sourceTotal > 1) {
          final step = ((source.size.height * 0.6) / (sourceTotal - 1)).clamp(8.0, 16.0);
          sOffset = Offset(0, (sourceIndex - (sourceTotal - 1) / 2) * step);
        }
        if (targetTotal > 1) {
          final step = ((target.size.height * 0.6) / (targetTotal - 1)).clamp(8.0, 16.0);
          tOffset = Offset(0, (targetIndex - (targetTotal - 1) / 2) * step);
        }
      } else {
        // Direzione Verticale -> Sdoppiamo in Orizzontale (X)
        if (sourceTotal > 1) {
          final step = ((source.size.width * 0.6) / (sourceTotal - 1)).clamp(8.0, 16.0);
          sOffset = Offset((sourceIndex - (sourceTotal - 1) / 2) * step, 0);
        }
        if (targetTotal > 1) {
          final step = ((target.size.width * 0.6) / (targetTotal - 1)).clamp(8.0, 16.0);
          tOffset = Offset((targetIndex - (targetTotal - 1) / 2) * step, 0);
        }
      }

      // Spostiamo i punti di aggancio
      final virtualSRect = sRect.shift(sOffset);
      final virtualTRect = tRect.shift(tOffset);

      final int globalIndex = provider.edges.indexOf(edge);
      final double laneOffset = (globalIndex % 6) * 12.0;

      // === OSTACOLI: Usiamo solo i nodi VISIBILI ===
      List<Rect> obstacles = [];
      for (var node in provider.visibleNodes) {
        if (node.id == source.id || node.id == target.id) continue;
        obstacles.add(Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height));
      }

      Path path = EdgeRoutingService.calculateOrthogonalPath(
        virtualSRect,
        virtualTRect,
        obstacles: obstacles,
        laneOffset: laneOffset,
      );

      // --- Taglio al millimetro ---
      path = _shortenPathToRect(path, tRect);
      path = _shortenPathFromSource(path, sRect);

      final isAggregated = edge.count > 1;
      final isSelected = provider.selectedEdgeIds.contains(edge.id);

      Paint currentPaint;
      if (isSelected) {
        currentPaint = Paint()
          ..color = Colors.blueAccent
          ..strokeWidth = 3.5
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

      // Troviamo la sorgente effettiva anche per il ghost edge
      final source = _getEffectiveNode(temp.sourceId, provider) ??
          (provider.visibleNodes.isNotEmpty ? provider.visibleNodes.first : provider.nodes.first);

      final sRect = Rect.fromLTWH(
          source.position.dx,
          source.position.dy,
          source.size.width,
          source.size.height
      );

      final sourceCenter = sRect.center;

      Path ghostPath = Path()
        ..moveTo(sourceCenter.dx, sourceCenter.dy)
        ..lineTo(temp.currentPosition.dx, temp.currentPosition.dy);

      // --- Tagliamo il ghost path alla partenza dal bordo del nodo sorgente ---
      ghostPath = _shortenPathFromSource(ghostPath, sRect);

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

  /// Taglia il path iniziale partendo dal perimetro del Rect sorgente.
  Path _shortenPathFromSource(Path originalPath, Rect sourceRect) {
    final metrics = originalPath.computeMetrics().toList();
    if (metrics.isEmpty) return originalPath;

    final firstMetric = metrics.first;
    final startTangent = firstMetric.getTangentForOffset(0);

    // Se l'inizio del path non è nemmeno dentro il nodo sorgente, ritorniamo il path originale
    if (startTangent == null || !sourceRect.contains(startTangent.position)) {
      return originalPath;
    }

    // Ricerca binaria per trovare il punto esatto di intersezione con il bordo in uscita
    double low = 0;
    double high = firstMetric.length;
    double targetOffset = 0;

    for (int i = 0; i < 12; i++) {
      double mid = (low + high) / 2;
      final tangent = firstMetric.getTangentForOffset(mid);
      if (tangent != null) {
        if (sourceRect.contains(tangent.position)) {
          // Siamo ancora dentro il nodo, l'intersezione è più avanti
          low = mid;
        } else {
          // Siamo fuori dal nodo, l'intersezione potrebbe essere prima
          high = mid;
          targetOffset = mid;
        }
      }
    }

    final newPath = Path();
    // Aggiungiamo solo il pezzo del primo segmento che si trova FUORI dal nodo sorgente
    newPath.addPath(firstMetric.extractPath(targetOffset, firstMetric.length), Offset.zero);

    // Aggiungiamo eventuali segmenti successivi (se il path è composto da più segmenti metrici)
    for (int i = 1; i < metrics.length; i++) {
      newPath.addPath(metrics[i].extractPath(0, metrics[i].length), Offset.zero);
    }

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

  GraphNode? _getEffectiveNode(String nodeId, GraphProvider provider) {
    GraphNode? current;
    try {
      current = provider.nodes.firstWhere((n) => n.id == nodeId);
    } catch (e) {
      return null;
    }

    while (current != null) {
      bool isVisible = provider.visibleNodes.any((n) => n.id == current!.id);
      if (isVisible) return current;

      if (current.parentId == null) break;
      final parentId = current.parentId;
      try {
        current = provider.nodes.firstWhere((n) => n.id == parentId);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

}