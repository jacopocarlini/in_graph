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
    buffer.write('<rect width="100%" height="100%" fill="white" />');
    buffer.write('<g transform="translate(${-offsetX}, ${-offsetY})">');

    // 2. Disegna gli Edge (Archi)
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
      
      // Target Arrowhead (semplice triangolo)
      if (edge.showTargetArrow && points.length >= 2) {
        final p1 = points[points.length - 2];
        final p2 = points.last;
        final angle = atan2(p2.dy - p1.dy, p2.dx - p1.dx);
        buffer.write(_getArrowheadSvg(p2, angle, colorHex));
      }
    }

    // 3. Disegna i nodi
    for (final node in nodes) {
      final colorHex = '#${node.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      
      // Box
      buffer.write('<rect x="${node.position.dx}" y="${node.position.dy}" width="${node.size.width}" height="${node.size.height}" rx="16" ry="16" fill="white" stroke="$colorHex" stroke-width="1.5" ');
      if (node.borderStyle == BorderStyleType.dashed) {
        buffer.write('stroke-dasharray="5,3" ');
      }
      buffer.write('/>');

      // Testo
      final showTextBelow = !node.isContainer || node.isCollapsed;
      if (showTextBelow) {
        buffer.write('<text x="${node.position.dx + node.size.width / 2}" y="${node.position.dy + node.size.height + 20}" text-anchor="middle" font-family="sans-serif" font-size="13" font-weight="bold" fill="#222">${_escapeXml(node.name)}</text>');
      } else {
        buffer.write('<text x="${node.position.dx + 40}" y="${node.position.dy + 20}" text-anchor="start" font-family="sans-serif" font-size="13" font-weight="bold" fill="#222">${_escapeXml(node.name)}</text>');
      }
      
      // Icon placeholder
      final iconX = node.isContainer && !node.isCollapsed ? node.position.dx + 20 : node.position.dx + node.size.width / 2;
      final iconY = node.isContainer && !node.isCollapsed ? node.position.dy + 20 : node.position.dy + node.size.height / 2;
      buffer.write('<circle cx="$iconX" cy="$iconY" r="${node.isContainer && !node.isCollapsed ? 8 : 15}" fill="$colorHex" opacity="0.3" />');
    }

    buffer.write('</g>');
    buffer.write('</svg>');

    return buffer.toString();
  }

  static String _getArrowheadSvg(Offset p, double angle, String color) {
    const size = 10.0;
    final x1 = p.dx - size * cos(angle - pi / 6);
    final y1 = p.dy - size * sin(angle - pi / 6);
    final x2 = p.dx - size * cos(angle + pi / 6);
    final y2 = p.dy - size * sin(angle + pi / 6);
    return '<polygon points="${p.dx},${p.dy} $x1,$y1 $x2,$y2" fill="$color" />';
  }

  static String _escapeXml(String input) {
    return input.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
  }
}
