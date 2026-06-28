import 'dart:math';
import 'package:flutter/material.dart';
import '../model/graph_models.dart';
import '../provider/graph_provider.dart';
import 'edge_routing_service.dart';

class SvgExportService {
  static const double _padding = 60.0;

  static String exportAsSvg(GraphProvider provider) {
    final nodes = provider.visibleNodes;
    final aggregatedEdges = provider.getAggregatedEdges();

    if (nodes.isEmpty) {
      return '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"></svg>';
    }

    // 1. Calcola bounding box
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

    // Spazio per testo sotto
    maxY += 40;

    final width = maxX - minX + (_padding * 2);
    final height = maxY - minY + (_padding * 2);
    final offsetX = minX - _padding;
    final offsetY = minY - _padding;

    final buffer = StringBuffer();
    buffer.write('<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">');

    // Font Material Icons via @font-face per rendere le icone
    buffer.write('<defs>');
    buffer.write('<style>');
    buffer.write('@font-face { font-family: "Material Icons"; font-style: normal; font-weight: 400; src: url(https://fonts.gstatic.com/s/materialicons/v142/flUhRq6tzZclQEJ-Vdg-IuiaDsNc.woff2) format("woff2"); }');
    buffer.write('.material-icon { font-family: "Material Icons"; font-weight: normal; font-style: normal; font-size: 24px; display: inline-block; direction: ltr; -webkit-font-smoothing: antialiased; text-rendering: optimizeLegibility; }');
    buffer.write('</style>');
    buffer.write('</defs>');

    buffer.write('<rect width="100%" height="100%" fill="white" />');
    buffer.write('<g transform="translate(${-offsetX}, ${-offsetY})">');

    // 2. Prima i container (sfondo)
    for (final node in nodes.where((n) => n.isContainer && !n.isCollapsed)) {
      _writeNodeSvg(buffer, node);
    }

    // 3. Disegna gli Edge (Archi) — sopra i container, sotto i nodi normali
    _writeEdgesSvg(buffer, provider, aggregatedEdges, nodes);

    // 4. Poi i nodi normali e i container collassati (in primo piano)
    for (final node in nodes.where((n) => !n.isContainer || n.isCollapsed)) {
      _writeNodeSvg(buffer, node);
    }

    buffer.write('</g>');
    buffer.write('</svg>');

    return buffer.toString();
  }

  static void _writeNodeSvg(StringBuffer buffer, GraphNode node) {
    final colorHex = '#${node.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';

    // Box
    buffer.write('<rect x="${node.position.dx}" y="${node.position.dy}" width="${node.size.width}" height="${node.size.height}" rx="16" ry="16" fill="white" stroke="$colorHex" stroke-width="1.5" ');
    if (node.borderStyle == BorderStyleType.dashed) {
      buffer.write('stroke-dasharray="5,3" ');
    }
    buffer.write('/>');

    // Testo (nome nodo) — sempre centrato sotto il box
    buffer.write('<text x="${node.position.dx + node.size.width / 2}" y="${node.position.dy + node.size.height + 20}" text-anchor="middle" font-family="sans-serif" font-size="13" font-weight="bold" fill="#222">${_escapeXml(node.name)}</text>');

    // Icona Material Icons
    if (node.icon != null) {
      final iconChar = String.fromCharCode(node.icon!.codePoint);
      final isExpandedContainer = node.isContainer && !node.isCollapsed;
      final iconSize = isExpandedContainer ? 20.0 : 32.0;
      final iconX = isExpandedContainer
          ? node.position.dx + 12
          : node.position.dx + node.size.width / 2;
      final iconY = isExpandedContainer
          ? node.position.dy + 12 + iconSize
          : node.position.dy + node.size.height / 2 + iconSize / 2;

      final anchor = isExpandedContainer ? 'start' : 'middle';
      buffer.write('<text x="$iconX" y="$iconY" text-anchor="$anchor" font-family="Material Icons" font-size="$iconSize" fill="$colorHex">$iconChar</text>');
    }
  }

  static void _writeEdgesSvg(StringBuffer buffer, GraphProvider provider, List<AggregatedEdge> aggregatedEdges, List<GraphNode> nodes) {
    final Map<String, List<String>> nodePorts = {};
    for (var edge in aggregatedEdges) {
      nodePorts.putIfAbsent(edge.sourceId, () => []).add(edge.id);
      nodePorts.putIfAbsent(edge.targetId, () => []).add(edge.id);
    }

    for (final edge in aggregatedEdges) {
      final source = nodes.firstWhere((n) => n.id == edge.sourceId, orElse: () => nodes.first);
      final target = nodes.firstWhere((n) => n.id == edge.targetId, orElse: () => nodes.first);
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
      if (dx.abs() > dy.abs()) {
        if (sourceTotal > 1) {
          final step = ((source.size.height * 0.7) / (sourceTotal - 1)).clamp(20.0, 25.0);
          sOffset = Offset(0, (sourceIndex - (sourceTotal - 1) / 2) * step);
        }
        if (targetTotal > 1) {
          final step = ((target.size.height * 0.7) / (targetTotal - 1)).clamp(20.0, 25.0);
          tOffset = Offset(0, (targetIndex - (targetTotal - 1) / 2) * step);
        }
      } else {
        if (sourceTotal > 1) {
          final step = ((source.size.width * 0.7) / (sourceTotal - 1)).clamp(20.0, 25.0);
          sOffset = Offset((sourceIndex - (sourceTotal - 1) / 2) * step, 0);
        }
        if (targetTotal > 1) {
          final step = ((target.size.width * 0.7) / (targetTotal - 1)).clamp(20.0, 25.0);
          tOffset = Offset((targetIndex - (targetTotal - 1) / 2) * step, 0);
        }
      }

      final virtualSRect = sRect.shift(sOffset);
      final virtualTRect = tRect.shift(tOffset);
      final int globalIndex = aggregatedEdges.indexOf(edge);
      final double laneOffset = (globalIndex % 6) * 20.0;

      List<Rect> obstacles = [];
      for (var node in nodes) {
        if (node.id == source.id || node.id == target.id) continue;
        if (node.isContainer && (provider.isAncestor(node.id, source.id) || provider.isAncestor(node.id, target.id))) continue;
        obstacles.add(Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height));
      }

      final points = EdgeRoutingService.calculateOrthogonalPoints(virtualSRect, virtualTRect, obstacles: obstacles, laneOffset: laneOffset);

      final colorHex = '#${edge.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      final strokeWidth = edge.count > 1 ? 3 : 2;

      buffer.write('<polyline points="');
      for (var p in points) {
        buffer.write('${p.dx},${p.dy} ');
      }
      buffer.write('" fill="none" stroke="$colorHex" stroke-width="$strokeWidth" stroke-linecap="round" ');
      if (edge.borderStyle == BorderStyleType.dashed) {
        buffer.write('stroke-dasharray="6,4" ');
      }
      buffer.write('/>');

      // Target Arrowhead
      if (edge.showTargetArrow && points.length >= 2) {
        final p1 = points[points.length - 2];
        final p2 = points.last;
        final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
        buffer.write(_getArrowheadSvg(p2, angle, colorHex));
      }

      // Source Arrowhead
      if (edge.showSourceArrow && points.length >= 2) {
        final p1 = points[1];
        final p2 = points.first;
        final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
        buffer.write(_getArrowheadSvg(p2, angle, colorHex));
      }

      // Edge Label
      if (edge.label != null && edge.label!.isNotEmpty) {
        final midPoint = _getPathMidpoint(points);
        buffer.write('<rect x="${midPoint.dx - 2}" y="${midPoint.dy - 14}" width="${edge.label!.length * 7 + 4}" height="16" fill="white" opacity="0.85" rx="2"/>');
        buffer.write('<text x="${midPoint.dx}" y="${midPoint.dy}" text-anchor="middle" font-family="sans-serif" font-size="12" font-weight="bold" fill="$colorHex">${_escapeXml(edge.label!)}</text>');
      }
    }
  }

  static String _getArrowheadSvg(Offset p, double angle, String color) {
    const size = 10.0;
    final x1 = p.dx - size * cos(angle - pi / 6);
    final y1 = p.dy - size * sin(angle - pi / 6);
    final x2 = p.dx - size * cos(angle + pi / 6);
    final y2 = p.dy - size * sin(angle + pi / 6);
    return '<polygon points="${p.dx},${p.dy} $x1,$y1 $x2,$y2" fill="$color" />';
  }

  static Offset _getPathMidpoint(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    if (points.length == 1) return points.first;

    double totalLength = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalLength += (points[i + 1] - points[i]).distance;
    }

    double halfLength = totalLength / 2;
    double currentLength = 0;

    for (int i = 0; i < points.length - 1; i++) {
      double segmentLength = (points[i + 1] - points[i]).distance;
      if (currentLength + segmentLength >= halfLength) {
        double t = (halfLength - currentLength) / segmentLength;
        return Offset(
          points[i].dx + (points[i + 1].dx - points[i].dx) * t,
          points[i].dy + (points[i + 1].dy - points[i].dy) * t,
        );
      }
      currentLength += segmentLength;
    }
    return points.last;
  }

  static String _escapeXml(String input) {
    return input.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
  }
}
