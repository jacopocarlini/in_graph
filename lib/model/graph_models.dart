import 'package:flutter/material.dart';

/// Enumeratore per gli strumenti della Toolbar
enum ToolType {
  pointer,
  pan,
  node,
  container,
  edge
}

/// Modello per i Nodi (sia foglie che container)
class GraphNode {
  final String id;
  final String name;
  Offset position;
  Size size;
  final String? parentId;
  final bool isCollapsed;
  final Map<String, dynamic>? metadata;
  final bool isContainer;

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
    this.parentId,
    this.isCollapsed = false,
    this.isContainer = false,
    this.metadata,
  });

  /// Metodo helper per creare una copia immutabile del nodo modificando solo alcuni campi
  GraphNode copyWith({
    String? name,
    Offset? position,
    Size? size,
    String? parentId,
    bool? isCollapsed,
    bool? isContainer,
    Map<String, dynamic>? metadata,
    bool clearParent = false, // <-- FONDAMENTALE PER TIRARE FUORI I NODI
  }) {
    return GraphNode(
      id: id,
      name: name ?? this.name,
      position: position ?? this.position,
      size: size ?? this.size,
      parentId: clearParent ? null : (parentId ?? this.parentId), // <-- LA LOGICA QUI
      isCollapsed: isCollapsed ?? this.isCollapsed,
      isContainer: isContainer ?? this.isContainer,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Modello base per le connessioni (Frecce)
class GraphEdge {
  final String id;
  final String sourceId;
  final String targetId;
  final String? label;

  GraphEdge({
    required this.id,
    required this.sourceId,
    required this.targetId,
    this.label,
  });
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
  });
}