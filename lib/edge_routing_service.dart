import 'package:flutter/material.dart';

class EdgeRoutingService {
  static Path calculateOrthogonalPath(Rect source, Rect target, {double margin = 10.0}) {
    Offset startPoint = source.center;
    Offset endPoint = target.center;

    // Decidiamo i lati di uscita e di entrata (fermando l'endPoint prima del bordo)
    if (source.right < target.left) {
      startPoint = Offset(source.right, source.center.dy);
      endPoint = Offset(target.left - margin, target.center.dy);
    } else if (source.left > target.right) {
      startPoint = Offset(source.left, source.center.dy);
      endPoint = Offset(target.right + margin, target.center.dy);
    } else if (source.bottom < target.top) {
      startPoint = Offset(source.center.dx, source.bottom);
      endPoint = Offset(target.center.dx, target.top - margin);
    } else {
      startPoint = Offset(source.center.dx, source.top);
      endPoint = Offset(target.center.dx, target.bottom + margin);
    }

    final path = Path()..moveTo(startPoint.dx, startPoint.dy);

    // Routing a gomito
    if (startPoint.dx == source.right || startPoint.dx == source.left) {
      final midX = (startPoint.dx + endPoint.dx) / 2;
      if ((startPoint.dy - endPoint.dy).abs() > 5) {
        path.lineTo(midX, startPoint.dy);
        path.lineTo(midX, endPoint.dy);
      }
    } else {
      final midY = (startPoint.dy + endPoint.dy) / 2;
      if ((startPoint.dx - endPoint.dx).abs() > 5) {
        path.lineTo(startPoint.dx, midY);
        path.lineTo(endPoint.dx, midY);
      }
    }

    path.lineTo(endPoint.dx, endPoint.dy);
    return path;
  }
}