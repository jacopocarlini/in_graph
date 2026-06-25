import 'package:flutter/material.dart';

/// Enumeratore per gli strumenti della Toolbar
enum ToolType { pointer, pan, node, container, edge }

enum BorderStyleType { solid, dashed }
enum CardinalityType { single, multiple }

/// Modello per i Nodi (sia foglie che container)
class GraphNode {
  final String id;
  final String name;
  Offset position;
  Size size;
  Size? oldSize;
  final String? parentId;
  final bool isCollapsed;
  final bool isContainer;
  final IconData? icon;
  final Color color;
  final BorderStyleType borderStyle;
  final CardinalityType cardinality;
  final String? cardinalityStart;
  final String? cardinalityEnd;

  // --- AGGIUNTA LOGICA SIZE GESTITA DAL MODELLO ---
  /// Dimensioni di default per un Nodo foglia (Quadrato 120x120)
  static const defaultNodeSize = Size(80, 80);

  /// Dimensioni di default per un Container (Rettangolo 300x200)
  static const defaultContainerSize = Size(300, 200);

  GraphNode({
    required this.id,
    required this.name,
    required this.position,
    required this.size,
    this.oldSize,
    this.parentId,
    this.isCollapsed = false,
    this.isContainer = false,
    this.icon,
    this.color = Colors.grey,
    this.borderStyle = BorderStyleType.solid,
    this.cardinality = CardinalityType.single,
    this.cardinalityStart,
    this.cardinalityEnd,
  });

  /// Metodo helper per creare una copia immutabile del nodo modificando solo alcuni campi
  GraphNode copyWith({
    String? name,
    Offset? position,
    Size? size,
    Size? oldSize,
    String? parentId,
    bool? isCollapsed,
    bool? isContainer,
    IconData? icon,
    Color? color,
    BorderStyleType? borderStyle,
    CardinalityType? cardinality,
    String? cardinalityStart,
    String? cardinalityEnd,
    Map<String, dynamic>? metadata,
    bool clearParent = false,
    bool clearIcon = false,
    bool clearCardinalityStart = false,
    bool clearCardinalityEnd = false,
  }) {
    return GraphNode(
      id: id,
      name: name ?? this.name,
      position: position ?? this.position,
      size: size ?? this.size,
      oldSize: oldSize ?? this.oldSize,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      isCollapsed: isCollapsed ?? this.isCollapsed,
      isContainer: isContainer ?? this.isContainer,
      icon: clearIcon ? null : (icon ?? this.icon),
      color: color ?? this.color,
      borderStyle: borderStyle ?? this.borderStyle,
      cardinality: cardinality ?? this.cardinality,
      cardinalityStart: clearCardinalityStart ? null : (cardinalityStart ?? this.cardinalityStart),
      cardinalityEnd: clearCardinalityEnd ? null : (cardinalityEnd ?? this.cardinalityEnd),
    );
  }
}

/// Modello base per le connessioni (Frecce)
class GraphEdge {
  final String id;
  final String sourceId;
  final String targetId;
  final String? label;
  final Color color;
  final BorderStyleType borderStyle;
  final bool showSourceArrow;
  final bool showTargetArrow;

  GraphEdge({
    required this.id,
    required this.sourceId,
    required this.targetId,
    this.label,
    this.color = Colors.blueGrey,
    this.borderStyle = BorderStyleType.solid,
    this.showSourceArrow = false,
    this.showTargetArrow = true,
  });

  GraphEdge copyWith({
    String? label,
    Color? color,
    BorderStyleType? borderStyle,
    bool? showSourceArrow,
    bool? showTargetArrow,
  }) {
    return GraphEdge(
      id: id,
      sourceId: sourceId,
      targetId: targetId,
      label: label ?? this.label,
      color: color ?? this.color,
      borderStyle: borderStyle ?? this.borderStyle,
      showSourceArrow: showSourceArrow ?? this.showSourceArrow,
      showTargetArrow: showTargetArrow ?? this.showTargetArrow,
    );
  }
}

/// Modello esteso per le connessioni aggregate (quando i container sono collassati)
class AggregatedEdge extends GraphEdge {
  final int count;

  AggregatedEdge({
    required super.id,
    required super.sourceId,
    required super.targetId,
    required this.count,
    super.label,
    super.color,
    super.borderStyle,
    super.showSourceArrow,
    super.showTargetArrow,
  });
}

class TempEdge {
  final String sourceId;
  Offset currentPosition;

  TempEdge({required this.sourceId, required this.currentPosition});
}
