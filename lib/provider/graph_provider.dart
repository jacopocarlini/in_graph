import 'package:flutter/material.dart';
import '../model/graph_models.dart';
import '../util/edge_routing_service.dart';

class GraphProvider extends ChangeNotifier {
  // ==========================================
  // VARIABILI DI STATO
  // ==========================================
  final List<GraphNode> _nodes = [];
  final List<GraphEdge> _edges = [];

  ToolType _activeTool = ToolType.pointer;
  List<String> _selectionNodes = [];
  List<String> _selectedEdges = [];

  Offset? _previewPosition;
  double? _zoomScale;
  bool _isTextEdit = false;

  String? _draftEdgeSourceId;
  Offset? _draftEdgeTarget;

  // ==========================================
  // GETTER GENERALI
  // ==========================================
  List<GraphNode> get nodes => _nodes;

  List<GraphEdge> get edges => _edges;

  ToolType get activeTool => _activeTool;

  List<String> get selection => _selectionNodes;

  List<String> get selectedEdgeIds => _selectedEdges;

  Offset? get previewPosition => _previewPosition;

  bool get isTextEdit => _isTextEdit;

  double get zoomScale => _zoomScale ?? 1.0;

  int get zoomPercentage {
    double scale = (_zoomScale ?? 1);
    double percentage = scale * 100;
    return percentage.toInt();
  }

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

  // ==========================================
  // GESTIONE CANVAS E STATO GLOBALE
  // ==========================================
  void setTool(ToolType tool) {
    _activeTool = tool;
    _draftEdgeSourceId = null;
    _draftEdgeTarget = null;
    _previewPosition = null;
    notifyListeners();
  }

  void setZoomScale(double zoomScale) {
    _zoomScale = zoomScale;
    notifyListeners();
  }

  void updatePreviewPosition(Offset? pos) {
    _previewPosition = pos;
    notifyListeners();
  }

  // ==========================================
  // GESTIONE SELEZIONE E RIMOZIONE
  // ==========================================
  void setSelection(String id) {
    _selectionNodes = [id];
    _selectedEdges.clear();

    // Porta in primo piano (Bring to Front)
    /*
    if (ids.isNotEmpty) {
      final Set<String> allIdsToFront = Set.from(ids);

      // Troviamo anche tutti i figli/nipoti
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

      final nodesToFront = _nodes
          .where((n) => allIdsToFront.contains(n.id))
          .toList();
      _nodes.removeWhere((n) => allIdsToFront.contains(n.id));
      _nodes.addAll(nodesToFront);
    }
*/
    notifyListeners();
  }

  void clearSelection() {
    _selectionNodes.clear();
    _selectedEdges.clear();
    notifyListeners();
  }

  bool trySelectEdgeAt(Offset localPosition) {
    _selectedEdges.clear();

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

      // ==========================================
      // MODIFICA QUI: GESTIONE OSTACOLI
      // ==========================================
      List<Rect> obstacles = [];
      for (var node in _nodes) {
        // Ignora i nodi sorgente e target
        if (node.id == edge.sourceId || node.id == edge.targetId) continue;

        // Ignora i container se racchiudono la sorgente o il target della freccia
        if (node.isContainer &&
            (_isAncestor(node.id, edge.sourceId) ||
                _isAncestor(node.id, edge.targetId))) {
          continue;
        }

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
        laneOffset: laneOffset,
      );

      if (EdgeRoutingService.isPointNearEdge(localPosition, points, 12.0)) {
        _selectedEdges.add(edge.id);
        _selectionNodes.clear();
        notifyListeners();
        return true; // <--- AGGIUNGI QUESTO: Freccia trovata!
      }
    }
    notifyListeners();
    return false; // <--- AGGIUNGI QUESTO: Nessuna freccia
  }

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
        laneOffset: laneOffset,
      );

      bool isCompletelyInside = points.every((p) => selectionRect.contains(p));
      if (isCompletelyInside) {
        newSelectedEdgeIds.add(edge.id);
      }
    }

    bool nodesChanged = _selectionNodes.toString() != newSelection.toString();
    bool edgesChanged =
        _selectedEdges.toString() != newSelectedEdgeIds.toString();

    if (nodesChanged || edgesChanged) {
      _selectionNodes = newSelection;
      _selectedEdges = newSelectedEdgeIds;
      notifyListeners();
    }
  }

  void deleteSelected() {
    if (_selectionNodes.isEmpty && _selectedEdges.isEmpty) return;

    // 1. Rimuovi i nodi selezionati
    _nodes.removeWhere((node) => _selectionNodes.contains(node.id));

    // 2. Rimuovi gli edge reali partendo dalla mappatura di quelli aggregati selezionati
    _edges.removeWhere((edge) {
      if (_selectionNodes.contains(edge.sourceId) ||
          _selectionNodes.contains(edge.targetId)) {
        return true;
      }

      final visibleSource = _getVisibleEndpoint(edge.sourceId);
      final visibleTarget = _getVisibleEndpoint(edge.targetId);
      final compositeKey = '$visibleSource-$visibleTarget';

      return _selectedEdges.contains(compositeKey);
    });

    _selectionNodes.clear();
    _selectedEdges.clear();
    notifyListeners();
  }

  // ==========================================
  // GESTIONE NODI
  // ==========================================
  List<GraphNode> get visibleNodes {
    return _nodes.where((node) {
      String? currentParentId = node.parentId;
      Set<String> visited = {node.id}; // Sicurezza anti-loop

      while (currentParentId != null) {
        if (visited.contains(currentParentId)) break; // Esce se trova un loop
        visited.add(currentParentId);

        final parentIndex = _nodes.indexWhere((n) => n.id == currentParentId);
        if (parentIndex == -1) break;

        final parent = _nodes[parentIndex];
        if (parent.isCollapsed) return false;
        currentParentId = parent.parentId;
      }
      return true;
    }).toList();
  }

  void setIsTextEdit(bool isTextEdit) {
    _isTextEdit = isTextEdit;
    notifyListeners();
  }

  void addNode(GraphNode node) {
    _nodes.add(node);
    notifyListeners();
  }

  void updateNameNode(String id, String name) {
    final index = _nodes.indexWhere((n) => n.id == id);
    _nodes[index] = _nodes[index].copyWith(name: name);
    notifyListeners();
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

  void moveNode(String id, Offset delta) {
    final Set<String> baseIdsToMove = _selectionNodes.toSet();
    final Set<String> allIdsToMove = Set.from(baseIdsToMove);

    void findDescendants(String parentId) {
      for (var node in _nodes) {
        if (node.parentId == parentId && !allIdsToMove.contains(node.id)) {
          allIdsToMove.add(node.id);
          findDescendants(node.id);
        }
      }
    }

    if (baseIdsToMove.length == 1) {
      findDescendants(baseIdsToMove.first);
    }

    for (var node in _nodes) {
      if (allIdsToMove.contains(node.id)) {
        node.position += delta;
      }
    }

    notifyListeners();
  }

  Rect _getEffectiveRect(GraphNode node) {
    return Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.isContainer ? node.size.height : node.size.width,
    );
  }

  // ==========================================
  // GESTIONE CONTAINER (DRAG, DROP, COLLAPSE)
  // ==========================================
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
      GraphNode? targetContainer;
      // Cerchiamo il primo container valido che NON crei un loop circolare
      for (var container in validContainers.reversed) {
        if (!_wouldCreateCycle(node.id, container.id)) {
          targetContainer = container;
          break;
        }
      }

      if (targetContainer != null) {
        _nodes[nodeIndex] = node.copyWith(parentId: targetContainer.id);
      } else {
        _nodes[nodeIndex] = node.copyWith(clearParent: true);
      }
    } else {
      _nodes[nodeIndex] = node.copyWith(clearParent: true);
    }
    notifyListeners();
  }

  void autoAdoptNodes(GraphNode container) {
    final containerRect = _getEffectiveRect(container);

    for (var i = 0; i < _nodes.length; i++) {
      final child = _nodes[i];
      if (child.id == container.id) continue;

      final childCenter = _getEffectiveRect(child).center;

      if (containerRect.contains(childCenter)) {
        if (!_wouldCreateCycle(child.id, container.id)) {
          _nodes[i] = child.copyWith(parentId: container.id);
        }
      }
    }
    notifyListeners();
  }

  void updateContainerChildren(String containerId) {
    final containerIndex = _nodes.indexWhere((n) => n.id == containerId);
    if (containerIndex == -1) return;

    final container = _nodes[containerIndex];
    final containerRect = _getEffectiveRect(container);

    for (var i = 0; i < _nodes.length; i++) {
      final child = _nodes[i];

      if (child.id == container.id) continue;

      final childCenter = _getEffectiveRect(child).center;

      if (containerRect.contains(childCenter)) {
        if (child.parentId != container.id &&
            !_wouldCreateCycle(child.id, container.id)) {
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

  void toggleCollapse(String nodeId) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      var size = !_nodes[index].isCollapsed
          ? GraphNode.defaultNodeSize
          : _nodes[index].oldSize;

      _nodes[index] = _nodes[index].copyWith(
        size: size,
        oldSize: _nodes[index].size,
        isCollapsed: !_nodes[index].isCollapsed,
      );
      notifyListeners();
    }
  }

  // ==========================================
  // GESTIONE EDGE (ARCHI)
  // ==========================================
  String _getVisibleEndpoint(String nodeId) {
    var current = _nodes.cast<GraphNode?>().firstWhere(
      (n) => n?.id == nodeId,
      orElse: () => null,
    );
    String visibleId = nodeId;
    Set<String> visited = {nodeId}; // Sicurezza anti-loop

    while (current != null && current.parentId != null) {
      if (visited.contains(current.parentId!)) break; // Esce se trova un loop
      visited.add(current.parentId!);

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

  // ==========================================
  // HELPER PER PREVENZIONE CICLI
  // ==========================================
  bool _wouldCreateCycle(String childId, String newParentId) {
    String? current = newParentId;
    Set<String> visited = {childId};

    while (current != null) {
      if (visited.contains(current)) {
        return true; // Rilevato un loop!
      }
      visited.add(current);

      final parentIndex = _nodes.indexWhere((n) => n.id == current);
      if (parentIndex == -1) break;
      current = _nodes[parentIndex].parentId;
    }
    return false;
  }

  // ==========================================
  // HELPER GERARCHIA E OSTACOLI
  // ==========================================
  bool _isAncestor(String ancestorId, String childId) {
    String? currentId = childId;
    Set<String> visited = {childId}; // Sicurezza anti-loop

    while (currentId != null) {
      final nodeIndex = _nodes.indexWhere((n) => n.id == currentId);
      if (nodeIndex == -1) break;

      final parentId = _nodes[nodeIndex].parentId;
      if (parentId == ancestorId) return true;

      if (parentId != null) {
        if (visited.contains(parentId)) break; // Esce se trova un loop
        visited.add(parentId);
      }
      currentId = parentId;
    }
    return false;
  }
}
