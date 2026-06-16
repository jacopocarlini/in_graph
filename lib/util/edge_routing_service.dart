import 'dart:math';
import 'package:flutter/material.dart';

class _AStarNode {
  final Offset point;
  double g = 0;
  double h = 0;
  _AStarNode? parent;

  _AStarNode(this.point);
  double get f => g + h;
}

class EdgeRoutingService {
  static List<Offset> calculateOrthogonalPoints(
      Rect source,
      Rect target, {
        List<Rect> obstacles = const [],
        double margin = 20.0,
        double laneOffset = 0.0, // === NUOVO: Definisce la "corsia" parallela ===
      }) {
    final start = source.center;
    final end = target.center;

    // Il margine effettivo cresce in base alla corsia assegnata alla freccia
    final double effectiveMargin = margin + laneOffset;

    Set<double> xs = {start.dx, end.dx};
    Set<double> ys = {start.dy, end.dy};

    for (var obs in obstacles) {
      xs.addAll([obs.left - effectiveMargin, obs.right + effectiveMargin]);
      ys.addAll([obs.top - effectiveMargin, obs.bottom + effectiveMargin]);
    }

    final minX = xs.reduce(min) - effectiveMargin * 2;
    final maxX = xs.reduce(max) + effectiveMargin * 2;
    final minY = ys.reduce(min) - effectiveMargin * 2;
    final maxY = ys.reduce(max) + effectiveMargin * 2;
    xs.addAll([minX, maxX]);
    ys.addAll([minY, maxY]);

    final sortedX = xs.toList()..sort();
    final sortedY = ys.toList()..sort();

    List<_AStarNode> openList = [];
    List<_AStarNode> closedList = [];

    _AStarNode startNode = _AStarNode(start);
    openList.add(startNode);

    _AStarNode? targetNode;

    while (openList.isNotEmpty) {
      openList.sort((a, b) => a.f.compareTo(b.f));
      _AStarNode current = openList.removeAt(0);
      closedList.add(current);

      if ((current.point.dx - end.dx).abs() < 1 && (current.point.dy - end.dy).abs() < 1) {
        targetNode = current;
        break;
      }

      List<Offset> neighbors = _getNeighbors(current.point, sortedX, sortedY);

      for (var nextPoint in neighbors) {
        if (closedList.any((n) => (n.point.dx - nextPoint.dx).abs() < 0.1 && (n.point.dy - nextPoint.dy).abs() < 0.1)) continue;

        // Controlla la collisione usando il margine base di sicurezza (non quello della corsia)
        if (_segmentIntersectsObstacles(current.point, nextPoint, obstacles, margin)) continue;

        double tentativeG = current.g + (current.point - nextPoint).distance;

        if (current.parent != null) {
          final dir1 = (current.point - current.parent!.point).direction;
          final dir2 = (nextPoint - current.point).direction;
          if ((dir1 - dir2).abs() > 0.01) tentativeG += 10.0;
        }

        _AStarNode? neighborNode = openList.where((n) => (n.point.dx - nextPoint.dx).abs() < 0.1 && (n.point.dy - nextPoint.dy).abs() < 0.1).firstOrNull;

        if (neighborNode == null) {
          neighborNode = _AStarNode(nextPoint)
            ..g = tentativeG
            ..h = (nextPoint - end).distance
            ..parent = current;
          openList.add(neighborNode);
        } else if (tentativeG < neighborNode.g) {
          neighborNode.g = tentativeG;
          neighborNode.parent = current;
        }
      }
    }

    if (targetNode != null) {
      List<Offset> path = [];
      _AStarNode? curr = targetNode;
      while (curr != null) {
        path.add(curr.point);
        curr = curr.parent;
      }
      return _simplifyPath(path.reversed.toList());
    }

    return _calculateFallbackPath(source, target);
  }

  static List<Offset> _getNeighbors(Offset p, List<double> xs, List<double> ys) {
    List<Offset> neighbors = [];
    int ix = xs.indexWhere((x) => (x - p.dx).abs() < 0.1);
    int iy = ys.indexWhere((y) => (y - p.dy).abs() < 0.1);

    if (ix == -1) ix = xs.indexWhere((x) => x > p.dx) - 1;
    if (iy == -1) iy = ys.indexWhere((y) => y > p.dy) - 1;

    if (ix > 0) neighbors.add(Offset(xs[ix - 1], p.dy));
    if (ix < xs.length - 1 && ix != -1) neighbors.add(Offset(xs[ix + 1], p.dy));
    if (iy > 0) neighbors.add(Offset(p.dx, ys[iy - 1]));
    if (iy < ys.length - 1 && iy != -1) neighbors.add(Offset(p.dx, ys[iy + 1]));

    return neighbors;
  }

  static bool _segmentIntersectsObstacles(Offset p1, Offset p2, List<Rect> obstacles, double margin) {
    final isVertical = (p1.dx - p2.dx).abs() < 0.1;
    final isHorizontal = (p1.dy - p2.dy).abs() < 0.1;
    final safeMargin = margin * 0.8; // Permette alle corsie di viaggiare vicino ai nodi

    for (var rect in obstacles) {
      final expandedRect = Rect.fromLTRB(
        rect.left - safeMargin, rect.top - safeMargin, rect.right + safeMargin, rect.bottom + safeMargin,
      );

      if (isVertical) {
        double minY = min(p1.dy, p2.dy);
        double maxY = max(p1.dy, p2.dy);
        if (p1.dx > expandedRect.left && p1.dx < expandedRect.right && minY < expandedRect.bottom && maxY > expandedRect.top) return true;
      } else if (isHorizontal) {
        double minX = min(p1.dx, p2.dx);
        double maxX = max(p1.dx, p2.dx);
        if (p1.dy > expandedRect.top && p1.dy < expandedRect.bottom && minX < expandedRect.right && maxX > expandedRect.left) return true;
      }
    }
    return false;
  }

  static List<Offset> _simplifyPath(List<Offset> path) {
    if (path.length <= 2) return path;
    List<Offset> simplified = [path.first];

    for (int i = 1; i < path.length - 1; i++) {
      final prev = simplified.last;
      final curr = path[i];
      final next = path[i + 1];

      // Rimuove i punti inutili senza deformare la linea calcolata da A*
      final isCollinear = ((prev.dx - curr.dx).abs() < 0.1 && (curr.dx - next.dx).abs() < 0.1) ||
          ((prev.dy - curr.dy).abs() < 0.1 && (curr.dy - next.dy).abs() < 0.1);
      if (!isCollinear) {
        simplified.add(curr);
      }
    }
    simplified.add(path.last);
    return simplified;
  }

  static List<Offset> _calculateFallbackPath(Rect source, Rect target) {
    return [source.center, Offset(source.center.dx, target.center.dy), target.center];
  }

  static Path calculateOrthogonalPath(Rect source, Rect target, {List<Rect> obstacles = const [], double laneOffset = 0.0}) {
    final points = calculateOrthogonalPoints(source, target, obstacles: obstacles, laneOffset: laneOffset);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) path.lineTo(points[i].dx, points[i].dy);
    return path;
  }

  static bool isPointNearEdge(Offset click, List<Offset> points, double threshold) {
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if ((p1.dy - p2.dy).abs() < 0.1) {
        final minX = min(p1.dx, p2.dx);
        final maxX = max(p1.dx, p2.dx);
        if (click.dx >= minX - threshold && click.dx <= maxX + threshold && (click.dy - p1.dy).abs() <= threshold) return true;
      } else if ((p1.dx - p2.dx).abs() < 0.1) {
        final minY = min(p1.dy, p2.dy);
        final maxY = max(p1.dy, p2.dy);
        if (click.dy >= minY - threshold && click.dy <= maxY + threshold && (click.dx - p1.dx).abs() <= threshold) return true;
      }
    }
    return false;
  }
}