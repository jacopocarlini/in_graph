import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../provider/graph_provider.dart';
import '../model/graph_models.dart';

class EdgePainter extends CustomPainter {
  final GraphProvider provider;

  EdgePainter({required this.provider}) : super(repaint: provider);

  @override
  void paint(Canvas canvas, Size size) {

    final aggregatedEdges = provider.getAggregatedEdges();

    // 1. Mappatura unificata dei "porti" (slot) per ogni nodo
    // Consideriamo sia le frecce in entrata che in uscita per evitare sovrapposizioni
    final Map<String, List<String>> nodePorts = {};

    for (var edge in aggregatedEdges) {
      final effSource = _getEffectiveNode(edge.sourceId, provider);
      final effTarget = _getEffectiveNode(edge.targetId, provider);

      if (effSource != null &&
          effTarget != null &&
          effSource.id != effTarget.id) {
        nodePorts.putIfAbsent(effSource.id, () => []).add(edge.id);
        nodePorts.putIfAbsent(effTarget.id, () => []).add(edge.id);
      }
    }

    // 2. Disegna gli Edge esistenti
    for (var edge in aggregatedEdges) {
      final source = _getEffectiveNode(edge.sourceId, provider);
      final target = _getEffectiveNode(edge.targetId, provider);

      if (source == null || target == null || source.id == target.id) continue;

      final tRect = Rect.fromLTWH(
        target.position.dx,
        target.position.dy,
        target.size.width,
        target.size.height,
      );
      final sRect = Rect.fromLTWH(
        source.position.dx,
        source.position.dy,
        source.size.width,
        source.size.height,
      );

      final List<Offset> points = provider.getEdgePath(edge);
      if (points.isEmpty) continue;

      var routedPath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        routedPath.lineTo(points[i].dx, points[i].dy);
      }

      // --- Taglio al millimetro ---
      final finalEdgePath = _cutPathFromSource(
        _cutPathToRect(routedPath, tRect),
        sRect,
      );

      final isAggregated = edge.count > 1;
      final isSelected = provider.selectedEdgeIds.contains(edge.id);

      // --- 1. DISEGNO ALONE DI SELEZIONE (Glow) ---
      if (isSelected) {
        final selectionGlowPaint = Paint()
          ..color = Colors.blue.withOpacity(0.15)
          ..strokeWidth =
              (isAggregated ? 3.0 : 2.0) +
              10.0 // Più largo della freccia
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        // Disegniamo l'alone azzurro sotto
        canvas.drawPath(finalEdgePath, selectionGlowPaint);
      }

      // --- 2. DISEGNO FRECCIA REALE ---
      double opacity = 1.0;
      if (provider.activeTool == ToolType.explorer &&
          provider.hoveredNodeId != null) {
        if (!provider.explorerActiveEdges.contains(edge.id)) {
          opacity = 0.2;
        }
      }

      // La freccia mantiene il suo colore originale anche se selezionata
      final arrowColor = edge.color.withOpacity(opacity);

      final currentPaint = Paint()
        ..color = arrowColor
        ..strokeWidth = isAggregated ? 3.0 : 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (edge.borderStyle == BorderStyleType.dashed) {
        canvas.drawPath(_createDashedPath(finalEdgePath, 6.0, 4.0), currentPaint);
      } else {
        canvas.drawPath(finalEdgePath, currentPaint);
      }

      // --- 3. DISEGNO PUNTE ---
      if (edge.showTargetArrow) {
        _drawArrowhead(canvas, finalEdgePath, arrowColor, atEnd: true);
      }
      if (edge.showSourceArrow) {
        _drawArrowhead(canvas, finalEdgePath, arrowColor, atEnd: false);
      }

      // --- 4. DISEGNO LABEL ---
      if (edge.label != null && edge.label!.isNotEmpty) {
        _drawEdgeLabel(canvas, finalEdgePath, edge.label!, arrowColor);
      }
    }

    // 3. Disegna l'Edge temporaneo (Ghost Edge durante il drag)
    if (provider.tempEdge != null) {
      final temp = provider.tempEdge!;

      // Troviamo la sorgente effettiva anche per il ghost edge
      final source =
          _getEffectiveNode(temp.sourceId, provider) ??
          (provider.visibleNodes.isNotEmpty
              ? provider.visibleNodes.first
              : provider.nodes.first);

      final sRect = Rect.fromLTWH(
        source.position.dx,
        source.position.dy,
        source.size.width,
        source.size.height,
      );

      final sourceCenter = sRect.center;

      Path ghostPath = Path()
        ..moveTo(sourceCenter.dx, sourceCenter.dy)
        ..lineTo(temp.currentPosition.dx, temp.currentPosition.dy);

      // --- Tagliamo il ghost path alla partenza dal bordo del nodo sorgente ---
      ghostPath = _cutPathFromSource(ghostPath, sRect);

      final ghostPaint = Paint()
        ..color = Colors.blue.withOpacity(0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawPath(ghostPath, ghostPaint);
      _drawArrowhead(canvas, ghostPath, Colors.blue.withOpacity(0.6));
    }
  }

  /// Taglia il path esattamente sul perimetro del Rect di destinazione
  Path _cutPathToRect(Path originalPath, Rect targetRect) {
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
      newPath.addPath(
        metrics[i].extractPath(0, metrics[i].length),
        Offset.zero,
      );
    }
    newPath.addPath(lastMetric.extractPath(0, targetOffset), Offset.zero);

    return newPath;
  }

  /// Taglia il path iniziale partendo dal perimetro del Rect sorgente.
  Path _cutPathFromSource(Path originalPath, Rect sourceRect) {
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
    newPath.addPath(
      firstMetric.extractPath(targetOffset, firstMetric.length),
      Offset.zero,
    );

    // Aggiungiamo eventuali segmenti successivi (se il path è composto da più segmenti metrici)
    for (int i = 1; i < metrics.length; i++) {
      newPath.addPath(
        metrics[i].extractPath(0, metrics[i].length),
        Offset.zero,
      );
    }

    return newPath;
  }

  /// Disegna la punta della freccia perfettamente orientata sul finale o inizio del tracciato
  void _drawArrowhead(
    Canvas canvas,
    Path path,
    Color color, {
    bool atEnd = true,
  }) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = atEnd ? metrics.last : metrics.first;
    final offset = atEnd ? metric.length : 0.0;
    final tangent = metric.getTangentForOffset(offset);
    if (tangent == null) return;

    // Se siamo all'inizio, invertiamo il vettore per puntare verso il nodo
    final dx = atEnd ? tangent.vector.dx : -tangent.vector.dx;
    final dy = atEnd ? tangent.vector.dy : -tangent.vector.dy;

    final angle = atan2(dy, dx);
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

  void _drawEdgeLabel(
    Canvas canvas,
    Path path,
    String text,
    Color color,
  ) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    // Troviamo il punto a metà della lunghezza totale
    double totalLength = metrics.fold(0.0, (sum, m) => sum + m.length);
    double halfLength = totalLength / 2;

    Tangent? tangent;
    double currentLen = 0;
    for (var m in metrics) {
      if (currentLen + m.length >= halfLength) {
        tangent = m.getTangentForOffset(halfLength - currentLen);
        break;
      }
      currentLen += m.length;
    }

    if (tangent == null) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Centra il testo sul punto medio
    final offset = Offset(
      tangent.position.dx - textPainter.width / 2,
      tangent.position.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, offset);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final Path dashedPath = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    return dashedPath;
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
