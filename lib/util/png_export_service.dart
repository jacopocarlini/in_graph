import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/graph_models.dart';
import '../provider/graph_provider.dart';
import 'edge_routing_service.dart';

class PngExportService {
  static const double _padding = 60.0;

  /// Crea un PNG renderizzando manualmente nodi ed archi su un Canvas.
  /// Questo evita i limiti di memoria del RepaintBoundary su canvas giganti.
  static Future<Uint8List?> captureAsPng(
    GraphProvider provider, {
    double pixelRatio = 2.0,
  }) async {
    final nodes = provider.visibleNodes;
    final edges = provider.getAggregatedEdges();

    if (nodes.isEmpty) return null;

    // 1. Calcola la bounding box
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in nodes) {
      minX = min(minX, node.position.dx);
      minY = min(minY, node.position.dy);
      maxX = max(maxX, node.position.dx + node.size.width);
      maxY = max(maxY, node.position.dy + node.size.height);
    }
    
    // Aggiungi spazio per il testo sotto i nodi
    maxY += 40;

    final contentRect = Rect.fromLTRB(
      minX - _padding,
      minY - _padding,
      maxX + _padding,
      maxY + _padding,
    );

    final width = contentRect.width * pixelRatio;
    final height = contentRect.height * pixelRatio;

    // 2. Inizia la registrazione del disegno
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Scala tutto in base al pixelRatio
    canvas.scale(pixelRatio);
    // Trasla per centrare il contenuto (portiamo minX, minY a 0,0 con padding)
    canvas.translate(-contentRect.left, -contentRect.top);

    // Sfondo bianco
    final paintBg = Paint()..color = Colors.white;
    canvas.drawRect(contentRect, paintBg);

    // 3. Disegna gli Edges (Logica simile a EdgePainter)
    _drawEdges(canvas, provider, edges, nodes);

    // 4. Disegna i Nodi
    for (final node in nodes) {
      _drawNode(canvas, node);
    }

    // 5. Genera l'immagine
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.round(), height.round());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    img.dispose();
    picture.dispose();

    return byteData?.buffer.asUint8List();
  }

  static void _drawNode(Canvas canvas, GraphNode node) {
    final rect = Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.size.height,
    );

    // Box
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    canvas.drawRRect(rrect, paint);

    // Border
    final borderPaint = Paint()
      ..color = node.color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (node.borderStyle == BorderStyleType.dashed) {
       _drawDashedRRect(canvas, rrect, borderPaint);
    } else {
       canvas.drawRRect(rrect, borderPaint);
    }

    // Icon (Usiamo l'icona garantita dal modello)
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(node.icon!.codePoint),
        style: TextStyle(
          fontSize: node.isContainer && !node.isCollapsed ? 20 : 32,
          fontFamily: node.icon!.fontFamily,
          package: node.icon!.fontPackage,
          color: node.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final iconX = node.isContainer && !node.isCollapsed
        ? node.position.dx + 10
        : node.position.dx + (node.size.width - textPainter.width) / 2;
    final iconY = node.isContainer && !node.isCollapsed
        ? node.position.dy + 10
        : node.position.dy + (node.size.height - textPainter.height) / 2;

    textPainter.paint(canvas, Offset(iconX, iconY));

    // Text
    final showTextBelow = !node.isContainer || node.isCollapsed;
    final namePainter = TextPainter(
      text: TextSpan(
        text: node.name,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      textAlign: showTextBelow ? TextAlign.center : TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    
    if (showTextBelow) {
      namePainter.layout(maxWidth: node.size.width + 60);
      namePainter.paint(canvas, Offset(node.position.dx - 30, node.position.dy + node.size.height + 4));
    } else {
      namePainter.layout(maxWidth: node.size.width - 60);
      namePainter.paint(canvas, Offset(node.position.dx + 40, node.position.dy + 12));
    }
  }

  static void _drawEdges(Canvas canvas, GraphProvider provider, List<AggregatedEdge> edges, List<GraphNode> visibleNodes) {
    final Map<String, List<String>> nodePorts = {};

    for (var edge in edges) {
        nodePorts.putIfAbsent(edge.sourceId, () => []).add(edge.id);
        nodePorts.putIfAbsent(edge.targetId, () => []).add(edge.id);
    }

    for (var edge in edges) {
      final source = visibleNodes.firstWhere((n) => n.id == edge.sourceId, orElse: () => visibleNodes.first);
      final target = visibleNodes.firstWhere((n) => n.id == edge.targetId, orElse: () => visibleNodes.first);

      if (source.id == target.id) continue;

      final sRect = Rect.fromLTWH(source.position.dx, source.position.dy, source.size.width, source.size.height);
      final tRect = Rect.fromLTWH(target.position.dx, target.position.dy, target.size.width, target.size.height);

      final sourceIndex = nodePorts[source.id]!.indexOf(edge.id);
      final sourceTotal = nodePorts[source.id]!.length;
      final targetIndex = nodePorts[target.id]!.indexOf(edge.id);
      final targetTotal = nodePorts[target.id]!.length;

      final dx = tRect.center.dx - sRect.center.dx;
      final dy = tRect.center.dy - sRect.center.dy;

      Offset sOffset = Offset.zero;
      Offset tOffset = Offset.zero;
      const double minStep = 20.0;

      if (dx.abs() > dy.abs()) {
        if (sourceTotal > 1) {
          final step = ((source.size.height * 0.7) / (sourceTotal - 1)).clamp(minStep, 25.0);
          sOffset = Offset(0, (sourceIndex - (sourceTotal - 1) / 2) * step);
        }
        if (targetTotal > 1) {
          final step = ((target.size.height * 0.7) / (targetTotal - 1)).clamp(minStep, 25.0);
          tOffset = Offset(0, (targetIndex - (targetTotal - 1) / 2) * step);
        }
      } else {
        if (sourceTotal > 1) {
          final step = ((source.size.width * 0.7) / (sourceTotal - 1)).clamp(minStep, 25.0);
          sOffset = Offset((sourceIndex - (sourceTotal - 1) / 2) * step, 0);
        }
        if (targetTotal > 1) {
          final step = ((target.size.width * 0.7) / (targetTotal - 1)).clamp(minStep, 25.0);
          tOffset = Offset((targetIndex - (targetTotal - 1) / 2) * step, 0);
        }
      }

      final virtualSRect = sRect.shift(sOffset);
      final virtualTRect = tRect.shift(tOffset);
      final int globalIndex = edges.indexOf(edge);
      final double laneOffset = (globalIndex % 6) * 20.0;

      List<Rect> obstacles = [];
      for (var node in visibleNodes) {
        if (node.id == source.id || node.id == target.id) continue;
        if (node.isContainer && (provider.isAncestor(node.id, source.id) || provider.isAncestor(node.id, target.id))) continue;
        obstacles.add(Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height));
      }

      Path path = EdgeRoutingService.calculateOrthogonalPath(virtualSRect, virtualTRect, obstacles: obstacles, laneOffset: laneOffset);
      
      // Shorten path
      path = _shortenPathToRect(path, tRect);
      path = _shortenPathFromSource(path, sRect);

      final paint = Paint()
        ..color = edge.color
        ..strokeWidth = edge.count > 1 ? 3.0 : 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (edge.borderStyle == BorderStyleType.dashed) {
        canvas.drawPath(_createDashedPath(path, 6.0, 4.0), paint);
      } else {
        canvas.drawPath(path, paint);
      }

      if (edge.showTargetArrow) _drawArrowhead(canvas, path, edge.color, atEnd: true);
      if (edge.showSourceArrow) _drawArrowhead(canvas, path, edge.color, atEnd: false);
    }
  }

  // --- Helper Methods (Copied from EdgePainter for independence) ---

  static void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = Path();
    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(metric.extractPath(distance, distance + 5.0), Offset.zero);
        distance += 5.0 + 3.0;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  static Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final Path dashedPath = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(metric.extractPath(distance, distance + dashWidth), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    return dashedPath;
  }

  static void _drawArrowhead(Canvas canvas, Path path, Color color, {bool atEnd = true}) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = atEnd ? metrics.last : metrics.first;
    final offset = atEnd ? metric.length : 0.0;
    final tangent = metric.getTangentForOffset(offset);
    if (tangent == null) return;
    final dx = atEnd ? tangent.vector.dx : -tangent.vector.dx;
    final dy = atEnd ? tangent.vector.dy : -tangent.vector.dy;
    final angle = atan2(dy, dx);
    const arrowSize = 12.0;
    final arrowPath = Path()
      ..moveTo(tangent.position.dx, tangent.position.dy)
      ..lineTo(tangent.position.dx - arrowSize * cos(angle - pi / 6), tangent.position.dy - arrowSize * sin(angle - pi / 6))
      ..lineTo(tangent.position.dx - arrowSize * cos(angle + pi / 6), tangent.position.dy - arrowSize * sin(angle + pi / 6))
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = color..style = PaintingStyle.fill);
  }

  static Path _shortenPathToRect(Path originalPath, Rect targetRect) {
    final metrics = originalPath.computeMetrics().toList();
    if (metrics.isEmpty) return originalPath;
    final lastMetric = metrics.last;
    final endTangent = lastMetric.getTangentForOffset(lastMetric.length);
    if (endTangent == null || !targetRect.contains(endTangent.position)) return originalPath;
    double low = 0, high = lastMetric.length, targetOffset = lastMetric.length;
    for (int i = 0; i < 12; i++) {
      double mid = (low + high) / 2;
      final tangent = lastMetric.getTangentForOffset(mid);
      if (tangent != null && targetRect.contains(tangent.position)) { high = mid; targetOffset = mid; } else { low = mid; }
    }
    final newPath = Path();
    for (int i = 0; i < metrics.length - 1; i++) {
      newPath.addPath(metrics[i].extractPath(0, metrics[i].length), Offset.zero);
    }
    newPath.addPath(lastMetric.extractPath(0, targetOffset), Offset.zero);
    return newPath;
  }

  static Path _shortenPathFromSource(Path originalPath, Rect sourceRect) {
    final metrics = originalPath.computeMetrics().toList();
    if (metrics.isEmpty) return originalPath;
    final firstMetric = metrics.first;
    final startTangent = firstMetric.getTangentForOffset(0);
    if (startTangent == null || !sourceRect.contains(startTangent.position)) return originalPath;
    double low = 0, high = firstMetric.length, targetOffset = 0;
    for (int i = 0; i < 12; i++) {
      double mid = (low + high) / 2;
      final tangent = firstMetric.getTangentForOffset(mid);
      if (tangent != null && sourceRect.contains(tangent.position)) { low = mid; } else { high = mid; targetOffset = mid; }
    }
    final newPath = Path();
    newPath.addPath(firstMetric.extractPath(targetOffset, firstMetric.length), Offset.zero);
    for (int i = 1; i < metrics.length; i++) {
      newPath.addPath(metrics[i].extractPath(0, metrics[i].length), Offset.zero);
    }
    return newPath;
  }
}
