import 'package:flutter/material.dart';

/// Enumeratore per gli strumenti della Toolbar
enum ToolType { pointer, pan, node, container, edge, explorer }

enum BorderStyleType { solid, dashed }

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
  final String? iconAssetPath;
  final Color color;
  final BorderStyleType borderStyle;

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
    IconData? icon,
    this.iconAssetPath,
    this.color = Colors.grey,
    this.borderStyle = BorderStyleType.solid,
  }) : icon = icon ?? (isContainer ? Icons.folder : Icons.widgets);

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
    String? iconAssetPath,
    Color? color,
    BorderStyleType? borderStyle,
    Map<String, dynamic>? metadata,
    bool clearParent = false,
    bool clearIcon = false,
    bool clearIconAsset = false,
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
      iconAssetPath: clearIconAsset
          ? null
          : (iconAssetPath ?? this.iconAssetPath),
      color: color ?? this.color,
      borderStyle: borderStyle ?? this.borderStyle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'position': {'dx': position.dx, 'dy': position.dy},
      'size': {'width': size.width, 'height': size.height},
      'oldSize': oldSize != null
          ? {'width': oldSize!.width, 'height': oldSize!.height}
          : null,
      'parentId': parentId,
      'isCollapsed': isCollapsed,
      'isContainer': isContainer,
      'icon': icon != null
          ? {
              'codePoint': icon!.codePoint,
              'fontFamily': icon!.fontFamily,
              'fontPackage': icon!.fontPackage,
            }
          : null,
      'iconAssetPath': iconAssetPath,
      'color': color.value,
      'borderStyle': borderStyle.name,
    };
  }

  factory GraphNode.fromMap(Map<dynamic, dynamic> map) {
    return GraphNode(
      id: map['id'],
      name: map['name'],
      position: Offset(
        (map['position']['dx'] as num).toDouble(),
        (map['position']['dy'] as num).toDouble(),
      ),
      size: Size(
        (map['size']['width'] as num).toDouble(),
        (map['size']['height'] as num).toDouble(),
      ),
      oldSize: map['oldSize'] != null
          ? Size(
              (map['oldSize']['width'] as num).toDouble(),
              (map['oldSize']['height'] as num).toDouble(),
            )
          : null,
      parentId: map['parentId'],
      isCollapsed: map['isCollapsed'] ?? false,
      isContainer: map['isContainer'] ?? false,
      icon: map['icon'] != null
          ? IconData(
              map['icon']['codePoint'] as int,
              fontFamily: map['icon']['fontFamily'] as String?,
              fontPackage: map['icon']['fontPackage'] as String?,
            )
          : null,
      iconAssetPath: map['iconAssetPath'] as String?,
      color: map['color'] != null ? Color(map['color'] as int) : Colors.grey,
      borderStyle: map['borderStyle'] != null
          ? BorderStyleType.values.firstWhere(
              (e) => e.name == map['borderStyle'],
              orElse: () => BorderStyleType.solid,
            )
          : BorderStyleType.solid,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sourceId': sourceId,
      'targetId': targetId,
      'label': label,
      'color': color.value,
      'borderStyle': borderStyle.name,
      'showSourceArrow': showSourceArrow,
      'showTargetArrow': showTargetArrow,
    };
  }

  factory GraphEdge.fromMap(Map<dynamic, dynamic> map) {
    return GraphEdge(
      id: map['id'],
      sourceId: map['sourceId'],
      targetId: map['targetId'],
      label: map['label'],
      color: map['color'] != null
          ? Color(map['color'] as int)
          : Colors.blueGrey,
      borderStyle: map['borderStyle'] != null
          ? BorderStyleType.values.firstWhere(
              (e) => e.name == map['borderStyle'],
              orElse: () => BorderStyleType.solid,
            )
          : BorderStyleType.solid,
      showSourceArrow: map['showSourceArrow'] ?? false,
      showTargetArrow: map['showTargetArrow'] ?? true,
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
