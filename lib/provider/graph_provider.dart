import 'package:flutter/material.dart';
import '../model/graph_models.dart';
import '../util/edge_routing_service.dart'; // Assicurati che il percorso sia corretto

class TempEdge {
  final String sourceId;
  Offset currentPosition;

  TempEdge({required this.sourceId, required this.currentPosition});
}

class GraphProvider extends ChangeNotifier {
  final List<GraphNode> _nodes = [];
  final List<GraphEdge> _edges = [];

  ToolType _activeTool = ToolType.pointer;
  List<String> _selection = []; // Selezioni dei Nodi
  List<String> _selectedEdgeIds = []; // === NUOVO: Selezioni delle Frecce ===

  String? _activeHoverId;
  Offset? _previewPosition;
  double? _zoomScale;
  bool _isTextEdit = false;
  Offset _panOffset = Offset.zero;

  // Stato per la creazione guidata dell'edge (Draft Edge)
  String? _draftEdgeSourceId;
  Offset? _draftEdgeTarget;

  bool get isTextEdit => _isTextEdit;

  List<GraphNode> get nodes => _nodes;

  List<GraphEdge> get edges => _edges;

  ToolType get activeTool => _activeTool;

  List<String> get selection => _selection;

  List<String> get selectedEdgeIds =>
      _selectedEdgeIds; // === NUOVO: Getter Frecce ===
  String? get activeHoverId => _activeHoverId;

  Offset? get previewPosition => _previewPosition;

  Offset get panOffset => _panOffset;

  int get zoomPercentage {
    double zoomScale = (_zoomScale ?? 1);
    double percentage = zoomScale * 100;
    return percentage.toInt();
  }

  double get zoomScale => _zoomScale ?? 1.0;

  TempEdge? get tempEdge {
    if (_draftEdgeSourceId != null && _draftEdgeTarget != null) {
      return TempEdge(
        sourceId: _draftEdgeSourceId!,
        currentPosition: _draftEdgeTarget!,
      );
    }
    return null;
  }

  bool get isCreatingEdge => _draftEdgeSourceId != null;

  String? get draftEdgeSourceId => _draftEdgeSourceId;

  Offset? get draftEdgeTarget => _draftEdgeTarget;

  void setIsTextEdit(bool isTextEdit) {
    _isTextEdit = isTextEdit;
  }

  // --- LOGICA DI AGGREGAZIONE FRECCE ---
  String _getVisibleEndpoint(String nodeId) {
    var current = _nodes.cast<GraphNode?>().firstWhere(
      (n) => n?.id == nodeId,
      orElse: () => null,
    );
    String visibleId = nodeId;

    while (current != null && current.parentId != null) {
      final parent = _nodes.cast<GraphNode?>().firstWhere(
        (n) => n?.id == current!.parentId,
        orElse: () => null,
      );
      if (parent != null && parent.isCollapsed) {
        visibleId = parent.id;
      }
      current = parent;
    }
    return visibleId;
  }

  List<AggregatedEdge> getAggregatedEdges() {
    Map<String, AggregatedEdge> aggregatedMap = {};

    for (var edge in _edges) {
      final visibleSource = _getVisibleEndpoint(edge.sourceId);
      final visibleTarget = _getVisibleEndpoint(edge.targetId);

      if (visibleSource == visibleTarget) continue;

      final key = '$visibleSource-$visibleTarget';
      if (aggregatedMap.containsKey(key)) {
        final existing = aggregatedMap[key]!;
        aggregatedMap[key] = AggregatedEdge(
          id: existing.id,
          sourceId: existing.sourceId,
          targetId: existing.targetId,
          count: existing.count + 1,
        );
      } else {
        aggregatedMap[key] = AggregatedEdge(
          id: key,
          sourceId: visibleSource,
          targetId: visibleTarget,
          count: 1,
        );
      }
    }
    return aggregatedMap.values.toList();
  }

  // --- METODI DEI TOOL E SELEZIONE ---
  void setSelection(List<String> ids) {
    _selection = ids;
    _selectedEdgeIds.clear(); // Reset delle frecce se viene forzata la selezione di nodi

    // --- NUOVA LOGICA: Porta in primo piano (Bring to Front) ---
    if (ids.isNotEmpty) {
      final Set<String> allIdsToFront = Set.from(ids);

      // Troviamo anche tutti i figli/nipoti, perché devono salire in primo piano assieme al parent
      void findDescendants(String parentId) {
        for (var node in _nodes) {
          if (node.parentId == parentId && !allIdsToFront.contains(node.id)) {
            allIdsToFront.add(node.id);
            findDescendants(node.id);
          }
        }
      }

      for (var id in ids) {
        findDescendants(id);
      }

      // Estraiamo i nodi coinvolti e li rimettiamo in fondo alla lista
      final nodesToFront = _nodes.where((n) => allIdsToFront.contains(n.id)).toList();
      _nodes.removeWhere((n) => allIdsToFront.contains(n.id));
      _nodes.addAll(nodesToFront);
    }

    notifyListeners();
  }

  void clearSelection() {
    _selection.clear();
    _selectedEdgeIds.clear();
    notifyListeners();
  }

  void setActiveHoverId(String? id) {
    if (_activeHoverId != id) {
      _activeHoverId = id;
      notifyListeners();
    }
  }

  // --- METODI DEI NODI ---
  void addNode(GraphNode node) {
    _nodes.add(node);
    notifyListeners();
  }

  void updateNameNode(String id, String name) {
    final index = _nodes.indexWhere((n) => n.id == id);
    _nodes[index] = _nodes[index].copyWith(name: name);
    notifyListeners();
  }

  // --- METODI GESTIONE EDGE ---
  void startEdge(String sourceNodeId) {
    _draftEdgeSourceId = sourceNodeId;
    _draftEdgeTarget = null;
    notifyListeners();
  }

  void updateDraftEdge(Offset pointerPosition) {
    if (!isCreatingEdge) return;
    _draftEdgeTarget = pointerPosition;
    notifyListeners();
  }

  void finishEdge(Offset position) {
    if (_draftEdgeSourceId == null) return;

    GraphNode? targetNode;
    for (var node in nodes.reversed) {
      if (node.id == _draftEdgeSourceId) continue;
      final rect = Rect.fromLTWH(
        node.position.dx,
        node.position.dy,
        node.size.width,
        node.size.height,
      );
      if (rect.contains(position)) {
        targetNode = node;
        break;
      }
    }

    if (targetNode != null) {
      bool edgeAlreadyExists = edges.any((edge) {
        bool isSameDirection =
            edge.sourceId == _draftEdgeSourceId &&
            edge.targetId == targetNode!.id;
        bool isOppositeDirection =
            edge.sourceId == targetNode!.id &&
            edge.targetId == _draftEdgeSourceId;

        return isSameDirection || isOppositeDirection;
      });

      if (!edgeAlreadyExists) {
        final newEdge = GraphEdge(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sourceId: _draftEdgeSourceId!,
          targetId: targetNode.id,
        );
        edges.add(newEdge);
      } else {
        debugPrint("Connessione già esistente tra questi nodi!");
      }
    }

    _draftEdgeSourceId = null;
    _draftEdgeTarget = null;
    notifyListeners();
  }

  // === NUOVO: SELEZIONE FRECCIA TRAMITE CLICK ===
  // === METODO SELEZIONE AL CLICK (COMPLETO DI PORT SLOTTING E OSTACOLI A*) ===
  void trySelectEdgeAt(Offset localPosition) {
    _selectedEdgeIds.clear();

    final aggregatedEdges = getAggregatedEdges();
    final Map<String, List<String>> edgesBySource = {};
    for (var edge in aggregatedEdges) {
      edgesBySource.putIfAbsent(edge.sourceId, () => []).add(edge.id);
    }

    for (var edge in aggregatedEdges) {
      final source = _nodes.cast<GraphNode?>().firstWhere(
        (n) => n?.id == edge.sourceId,
        orElse: () => null,
      );
      final target = _nodes.cast<GraphNode?>().firstWhere(
        (n) => n?.id == edge.targetId,
        orElse: () => null,
      );
      if (source == null || target == null) continue;

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

      final sourceIndex = edgesBySource[edge.sourceId]!.indexOf(edge.id);
      final sourceTotal = edgesBySource[edge.sourceId]!.length;

      final targetIndex = edgesBySource[edge.targetId]?.indexOf(edge.id) ?? 0;
      final targetTotal = edgesBySource[edge.targetId]?.length ?? 1;

      // Calcolo sdoppiamento porte
      final dx = tRect.center.dx - sRect.center.dx;
      final dy = tRect.center.dy - sRect.center.dy;

      Offset sOffset = Offset.zero;
      Offset tOffset = Offset.zero;

      if (dx.abs() > dy.abs()) {
        if (sourceTotal > 1) {
          final step = ((source.size.height * 0.6) / (sourceTotal - 1)).clamp(
            8.0,
            16.0,
          );
          sOffset = Offset(0, (sourceIndex - (sourceTotal - 1) / 2) * step);
        }
        if (targetTotal > 1) {
          final step = ((target.size.height * 0.6) / (targetTotal - 1)).clamp(
            8.0,
            16.0,
          );
          tOffset = Offset(0, (targetIndex - (targetTotal - 1) / 2) * step);
        }
      } else {
        if (sourceTotal > 1) {
          final step = ((source.size.width * 0.6) / (sourceTotal - 1)).clamp(
            8.0,
            16.0,
          );
          sOffset = Offset((sourceIndex - (sourceTotal - 1) / 2) * step, 0);
        }
        if (targetTotal > 1) {
          final step = ((target.size.width * 0.6) / (targetTotal - 1)).clamp(
            8.0,
            16.0,
          );
          tOffset = Offset((targetIndex - (targetTotal - 1) / 2) * step, 0);
        }
      }

      // ECCO I RETTANGOLI VIRTUALI
      final virtualSRect = sRect.shift(sOffset);
      final virtualTRect = tRect.shift(tOffset);

      final int globalIndex = aggregatedEdges.indexOf(edge);
      final double laneOffset = (globalIndex % 6) * 12.0;

      // Raccogliamo gli ostacoli
      List<Rect> obstacles = [];
      for (var node in _nodes) {
        if (node.id == edge.sourceId || node.id == edge.targetId) continue;
        obstacles.add(
          Rect.fromLTWH(
            node.position.dx,
            node.position.dy,
            node.size.width,
            node.size.height,
          ),
        );
      }

      // Calcoliamo la geometria della freccia usando lo stesso percorso di EdgePainter
      final points = EdgeRoutingService.calculateOrthogonalPoints(
        virtualSRect,
        virtualTRect,
        obstacles: obstacles,
        laneOffset: laneOffset, // <-- Assicurati di passare laneOffset qui
      );

      // Tolleranza di 12 pixel per cliccare la linea
      if (EdgeRoutingService.isPointNearEdge(localPosition, points, 12.0)) {
        _selectedEdgeIds.add(edge.id);
        _selection.clear();
        notifyListeners();
        return;
      }
    }
    notifyListeners();
  }

  // === METODO SELEZIONE RETTANGOLO (COMPLETO DI PORT SLOTTING E OSTACOLI A*) ===
  void updateSelectionFromRect(Rect selectionRect) {
    List<String> newSelection = [];
    List<String> newSelectedEdgeIds = [];

    // Seleziona nodi
    for (var node in _nodes) {
      final isCollapsedContainer = node.isContainer && node.isCollapsed;
      final width = isCollapsedContainer
          ? GraphNode.defaultNodeSize.width
          : node.size.width;
      final height = isCollapsedContainer
          ? GraphNode.defaultNodeSize.height
          : (node.isContainer ? node.size.height : node.size.width);

      final nodeRect = Rect.fromLTWH(
        node.position.dx,
        node.position.dy,
        width,
        height,
      );

      if (selectionRect.left <= nodeRect.left &&
          selectionRect.right >= nodeRect.right &&
          selectionRect.top <= nodeRect.top &&
          selectionRect.bottom >= nodeRect.bottom) {
        newSelection.add(node.id);
      }
    }

    // Seleziona frecce
    final aggregatedEdges = getAggregatedEdges();
    final Map<String, List<String>> edgesBySource = {};
    for (var edge in aggregatedEdges) {
      edgesBySource.putIfAbsent(edge.sourceId, () => []).add(edge.id);
    }

    for (var edge in aggregatedEdges) {
      final source = _nodes.cast<GraphNode?>().firstWhere(
        (n) => n?.id == edge.sourceId,
        orElse: () => null,
      );
      final target = _nodes.cast<GraphNode?>().firstWhere(
        (n) => n?.id == edge.targetId,
        orElse: () => null,
      );
      if (source == null || target == null) continue;

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

      final sourceIndex = edgesBySource[edge.sourceId]!.indexOf(edge.id);
      final sourceTotal = edgesBySource[edge.sourceId]!.length;

      final targetIndex = edgesBySource[edge.targetId]?.indexOf(edge.id) ?? 0;
      final targetTotal = edgesBySource[edge.targetId]?.length ?? 1;

      final dx = tRect.center.dx - sRect.center.dx;
      final dy = tRect.center.dy - sRect.center.dy;

      Offset sOffset = Offset.zero;
      Offset tOffset = Offset.zero;

      if (dx.abs() > dy.abs()) {
        if (sourceTotal > 1) {
          final step = ((source.size.height * 0.6) / (sourceTotal - 1)).clamp(
            8.0,
            16.0,
          );
          sOffset = Offset(0, (sourceIndex - (sourceTotal - 1) / 2) * step);
        }
        if (targetTotal > 1) {
          final step = ((target.size.height * 0.6) / (targetTotal - 1)).clamp(
            8.0,
            16.0,
          );
          tOffset = Offset(0, (targetIndex - (targetTotal - 1) / 2) * step);
        }
      } else {
        if (sourceTotal > 1) {
          final step = ((source.size.width * 0.6) / (sourceTotal - 1)).clamp(
            8.0,
            16.0,
          );
          sOffset = Offset((sourceIndex - (sourceTotal - 1) / 2) * step, 0);
        }
        if (targetTotal > 1) {
          final step = ((target.size.width * 0.6) / (targetTotal - 1)).clamp(
            8.0,
            16.0,
          );
          tOffset = Offset((targetIndex - (targetTotal - 1) / 2) * step, 0);
        }
      }

      final virtualSRect = sRect.shift(sOffset);
      final virtualTRect = tRect.shift(tOffset);

      final int globalIndex = aggregatedEdges.indexOf(edge);
      final double laneOffset = (globalIndex % 6) * 12.0;

      List<Rect> obstacles = [];
      for (var node in _nodes) {
        if (node.id == edge.sourceId || node.id == edge.targetId) continue;
        obstacles.add(
          Rect.fromLTWH(
            node.position.dx,
            node.position.dy,
            node.size.width,
            node.size.height,
          ),
        );
      }

      final points = EdgeRoutingService.calculateOrthogonalPoints(
        virtualSRect,
        virtualTRect,
        obstacles: obstacles,
        laneOffset: laneOffset, // <-- Assicurati di passare laneOffset qui
      );

      bool isCompletelyInside = points.every((p) => selectionRect.contains(p));
      if (isCompletelyInside) {
        newSelectedEdgeIds.add(edge.id);
      }
    }

    bool nodesChanged = _selection.toString() != newSelection.toString();
    bool edgesChanged =
        _selectedEdgeIds.toString() != newSelectedEdgeIds.toString();

    if (nodesChanged || edgesChanged) {
      _selection = newSelection;
      _selectedEdgeIds = newSelectedEdgeIds;
      notifyListeners();
    }
  }

  void updatePreviewPosition(Offset? pos) {
    _previewPosition = pos;
    notifyListeners();
  }

  void setTool(ToolType tool) {
    _activeTool = tool;
    _draftEdgeSourceId = null;
    _draftEdgeTarget = null;
    _previewPosition = null;
    notifyListeners();
  }

  // --- GERARCHIA E VISIBILITÀ ---
  List<GraphNode> get visibleNodes {
    return _nodes.where((node) {
      String? currentParentId = node.parentId;
      while (currentParentId != null) {
        final parentIndex = _nodes.indexWhere((n) => n.id == currentParentId);
        if (parentIndex == -1) break;

        final parent = _nodes[parentIndex];
        if (parent.isCollapsed) return false;
        currentParentId = parent.parentId;
      }
      return true;
    }).toList();
  }

  void handleNodeDrop(String nodeId) {
    final nodeIndex = _nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex == -1) return;

    final node = _nodes[nodeIndex];
    final nodeCenter = _getEffectiveRect(node).center;

    final validContainers = _nodes
        .where(
          (c) =>
              c.isContainer &&
              c.id != nodeId &&
              _getEffectiveRect(c).contains(nodeCenter),
        )
        .toList();

    if (validContainers.isNotEmpty) {
      final targetContainer = validContainers.last;
      _nodes[nodeIndex] = node.copyWith(parentId: targetContainer.id);
    } else {
      _nodes[nodeIndex] = node.copyWith(clearParent: true);
    }
    notifyListeners();
  }

  void autoAdoptNodes(GraphNode container) {
    final containerRect = _getEffectiveRect(container);

    for (var i = 0; i < _nodes.length; i++) {
      final child = _nodes[i];
      if (child.id == container.id || child.isContainer) continue;

      final childCenter = _getEffectiveRect(child).center;

      if (containerRect.contains(childCenter)) {
        _nodes[i] = child.copyWith(parentId: container.id);
      }
    }
    notifyListeners();
  }

  void toggleCollapse(String nodeId) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(
        isCollapsed: !_nodes[index].isCollapsed,
      );
      notifyListeners();
    }
  }

  void resizeNode(String id, Size newSize) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final width = newSize.width < 150 ? 150.0 : newSize.width;
      final height = newSize.height < 100 ? 100.0 : newSize.height;

      _nodes[index] = _nodes[index].copyWith(size: Size(width, height));
      notifyListeners();
    }
  }

  void updateContainerChildren(String containerId) {
    final containerIndex = _nodes.indexWhere((n) => n.id == containerId);
    if (containerIndex == -1) return;

    final container = _nodes[containerIndex];
    final containerRect = Rect.fromLTWH(
      container.position.dx,
      container.position.dy,
      container.size.width,
      container.size.height,
    );

    for (var i = 0; i < _nodes.length; i++) {
      final child = _nodes[i];
      if (child.id == container.id || child.isContainer) continue;

      final childCenter = Rect.fromLTWH(
        child.position.dx,
        child.position.dy,
        child.size.width,
        child.size.height,
      ).center;

      if (containerRect.contains(childCenter)) {
        if (child.parentId != container.id) {
          _nodes[i] = child.copyWith(parentId: container.id);
        }
      } else {
        if (child.parentId == container.id) {
          _nodes[i] = child.copyWith(clearParent: true);
        }
      }
    }
    notifyListeners();
  }

  Rect _getEffectiveRect(GraphNode node) {
    if (node.isContainer && node.isCollapsed) {
      return Rect.fromLTWH(
        node.position.dx,
        node.position.dy,
        GraphNode.defaultNodeSize.width,
        GraphNode.defaultNodeSize.height,
      );
    }
    return Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.isContainer ? node.size.height : node.size.width,
    );
  }

  void moveNode(String id, Offset delta) {
    // 1. Identifica i nodi che l'utente sta muovendo esplicitamente
    final Set<String> baseIdsToMove = _selection.contains(id)
        ? _selection.toSet()
        : {id};

    // 2. Prepara un Set per raccogliere i nodi espliciti + tutti i loro discendenti
    final Set<String> allIdsToMove = Set.from(baseIdsToMove);

    // 3. Funzione ricorsiva per trovare figli, nipoti, ecc.
    void findDescendants(String parentId) {
      for (var node in _nodes) {
        // Se il nodo ha come parent quello che stiamo controllando
        // e non è già stato aggiunto (evita doppi spostamenti se è già selezionato)
        if (node.parentId == parentId && !allIdsToMove.contains(node.id)) {
          allIdsToMove.add(node.id);
          findDescendants(node.id); // Cerca i figli di questo figlio
        }
      }
    }

    // 4. Popola il set con i discendenti di tutti i nodi "base"
    for (var baseId in baseIdsToMove) {
      findDescendants(baseId);
    }

    // 5. Applica il delta a tutto il blocco (parent e figli)
    for (var node in _nodes) {
      if (allIdsToMove.contains(node.id)) {
        node.position += delta;
      }
    }

    notifyListeners();
  }

  // --- AGGIORNATO: CANCELLAZIONE SINCRO CON LE FRECCE SELEZIONATE ---
  void deleteSelected() {
    if (_selection.isEmpty && _selectedEdgeIds.isEmpty) return;

    // 1. Rimuovi i nodi selezionati
    _nodes.removeWhere((node) => _selection.contains(node.id));

    // 2. Rimuovi gli edge reali partendo dalla mappatura di quelli aggregati selezionati
    _edges.removeWhere((edge) {
      // Regola A: Se l'arco è collegato a un nodo rimosso, eliminalo
      if (_selection.contains(edge.sourceId) ||
          _selection.contains(edge.targetId)) {
        return true;
      }

      // Regola B: Se l'arco fa parte di un gruppo aggregato rimosso, eliminalo
      final visibleSource = _getVisibleEndpoint(edge.sourceId);
      final visibleTarget = _getVisibleEndpoint(edge.targetId);
      final compositeKey = '$visibleSource-$visibleTarget';

      return _selectedEdgeIds.contains(compositeKey);
    });

    _selection.clear();
    _selectedEdgeIds.clear();
    notifyListeners();
  }

  void setZoomScale(double zoomScale) {
    _zoomScale = zoomScale;
    notifyListeners();
  }

  void panCanvas(Offset delta) {
    if (_activeTool == ToolType.pan) {
      _panOffset += delta;
      notifyListeners();
    }
  }
}
