import 'dart:math';
import 'package:flutter/material.dart';
import 'provider/graph_provider.dart';
import './edge_routing_service.dart';

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

    // 1. Disegna gli Edge esistenti
    for (var edge in provider.getAggregatedEdges()) {
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

      final path = EdgeRoutingService.calculateOrthogonalPath(sRect, tRect);
      final isAggregated = edge.count > 1;

      canvas.drawPath(path, isAggregated ? aggregatedPaint : edgePaint);
      _drawArrowhead(
        canvas,
        path,
        isAggregated ? Colors.blueAccent : Colors.blueGrey,
      );
    }

    // 2. Disegna l'Edge temporaneo (Ghost Edge durante il drag)
    if (provider.tempEdge != null) {
      final temp = provider.tempEdge!;
      final source = provider.nodes.firstWhere((n) => n.id == temp.sourceId);
      final sRect = Rect.fromLTWH(
        source.position.dx,
        source.position.dy,
        source.size.width,
        source.size.height,
      );

      // Creiamo un Rect fittizio grande 0 nel punto del mouse per calcolare il path
      final mouseRect = Rect.fromCenter(
        center: temp.currentPosition,
        width: 0,
        height: 0,
      );

      final ghostPath = EdgeRoutingService.calculateOrthogonalPath(
        sRect,
        mouseRect,
        margin: 0,
      );

      final ghostPaint = Paint()
        ..color = Colors.grey.withOpacity(0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle
            .stroke; // Potresti usare un PathDash in Flutter con pacchetti esterni

      canvas.drawPath(ghostPath, ghostPaint);
      _drawArrowhead(canvas, ghostPath, Colors.grey.withOpacity(0.6));
    }
  }

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
