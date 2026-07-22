import 'package:flutter/material.dart';
import '../model/graph_models.dart';
import '../util/edge_routing_service.dart';

enum InteractionMode {
  idle,
  tool,
  panning,
  clicking,
  draggingNode,
  resizingNode,
  rectSelecting,
  creatingEdge,
}

class GraphProvider extends ChangeNotifier {
  // ==========================================
  // VARIABILI DI STATO
  // ==========================================
  InteractionMode _interactionMode = InteractionMode.idle;

  final List<GraphNode> _nodes = [];
  Map<String, GraphNode> _nodesMap = {};
  final List<GraphEdge> _edges = [];

  ToolType _activeTool = ToolType.pointer;
  List<String> _selectionNodes = [];
  List<String> _selectedEdges = [];

  Offset? _startPosition;
  Offset? _currentPosition;
  double? _zoomScale;
  bool _isTextEdit = false;

  String? _draftEdgeSourceId;
  Offset? _draftEdgeTarget;
  Alignment? _activeResizeHandle;
  String? _interactingNodeId;
  String? _hoveredNodeId;

  // ==========================================
  // CACHE E OTTIMIZZAZIONI
  // ==========================================
  List<AggregatedEdge>? _cachedAggregatedEdges;
  final Map<String, List<Offset>> _edgePathCache = {};

  void _invalidateCache({bool pathsOnly = false}) {
    _edgePathCache.clear();
    if (!pathsOnly) {
      _cachedAggregatedEdges = null;
    }
  }

  bool get _isInteracting =>
      _interactionMode == InteractionMode.draggingNode ||
      _interactionMode == InteractionMode.resizingNode ||
      _interactionMode == InteractionMode.rectSelecting ||
      _interactionMode == InteractionMode.creatingEdge;

  /// GlobalKey usata dal GraphCanvas per identificare il RepaintBoundary del canvas.
  /// La toolbar la usa per catturare il PNG dell'intero grafo.
  final GlobalKey canvasBoundaryKey = GlobalKey();

  // Controlla se la telecamera può muoversi: solo se il tool attivo è il PAN
  bool get canPanCanvas => _activeTool == ToolType.pan;

  InteractionMode get interactionMode => _interactionMode;

  // ==========================================
  // GETTER GENERALI
  // ==========================================
  Offset? get currentPosition => _currentPosition;

  List<GraphNode> get nodes => _nodes;

  Map<String, GraphNode> get nodesMap => _nodesMap;

  List<GraphEdge> get edges => _edges;

  ToolType get activeTool => _activeTool;

  List<String> get selection => _selectionNodes;

  List<String> get selectedEdgeIds => _selectedEdges;

  Offset? get startPosition => _startPosition;

  bool get isTextEdit => _isTextEdit;

  double get zoomScale => _zoomScale ?? 1.0;

  String? get hoveredNodeId => _hoveredNodeId;

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
    _invalidateCache();
    clearSelection();
    notifyListeners();
  }

  void setZoomScale(double zoomScale) {
    _zoomScale = zoomScale;
    notifyListeners();
  }

  void updateCurrentPosition(Offset position) {
    if (_currentPosition == position) return;
    _currentPosition = position;
    final hoverChanged = _updateHoverState(position);
    final shouldUpdateGhost =
        _activeTool == ToolType.node || _activeTool == ToolType.container;

    if (hoverChanged || shouldUpdateGhost) {
      notifyListeners();
    }
  }

  bool _updateHoverState(Offset position) {
    // Gestione Hover per il tool Edge o Explorer
    if (_activeTool == ToolType.edge || _activeTool == ToolType.explorer) {
      final hitNode = _hitTestNodes(position);
      if (_hoveredNodeId != hitNode?.id) {
        _hoveredNodeId = hitNode?.id;
        return true;
      }
    } else if (_hoveredNodeId != null) {
      _hoveredNodeId = null;
      return true;
    }
    return false;
  }

  // ==========================================
  // GESTIONE SELEZIONE E RIMOZIONE
  // ==========================================
  void setSelection(String id) {
    _selectionNodes = [id];
    _isTextEdit = false;
    _selectedEdges.clear();
    notifyListeners();
  }

  void clearSelection() {
    _selectionNodes.clear();
    _selectedEdges.clear();
    _invalidateCache();
    notifyListeners();
  }

  bool trySelectEdgeAt(Offset localPosition) {
    _selectedEdges.clear();

    final aggregatedEdges = getAggregatedEdges();
    String? bestEdgeId;

    for (var edge in aggregatedEdges) {
      final points = getEdgePath(edge);

      // Usiamo una soglia di hit-test un po' più generosa (16.0 pixel)
      if (EdgeRoutingService.isPointNearEdge(localPosition, points, 16.0)) {
        bestEdgeId = edge.id;
        break;
      }
    }

    if (bestEdgeId != null) {
      _selectedEdges.add(bestEdgeId);
      _selectionNodes.clear();
      notifyListeners();
      return true;
    }

    notifyListeners();
    return false;
  }

  void updateSelectionFromRect(Rect selectionRect) {
    List<String> newSelection = [];
    List<String> newSelectedEdgeIds = [];

    // Seleziona nodi
    for (var node in _nodes) {
      final width = node.size.width;
      final height = node.size.height;

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
    for (var edge in aggregatedEdges) {
      final points = getEdgePath(edge);

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
    final deletedNodeIds = _selectionNodes.toSet();
    _nodes.removeWhere((node) => deletedNodeIds.contains(node.id));
    for (var id in deletedNodeIds) {
      _nodesMap.remove(id);
    }

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
    _invalidateCache();
    notifyListeners();
  }

  // ==========================================
  // METODI DI IMPORTAZIONE
  // ==========================================
  void loadFromGraphData(List<GraphNode> newNodes, List<GraphEdge> newEdges) {
    _nodes.clear();
    _edges.clear();
    _nodes.addAll(newNodes);
    _nodesMap = {for (var n in _nodes) n.id: n};
    _edges.addAll(newEdges);
    _selectionNodes.clear();
    _selectedEdges.clear();
    _draftEdgeSourceId = null;
    _draftEdgeTarget = null;
    _invalidateCache();
    notifyListeners();
  }

  // ==========================================
  // GESTIONE SELEZIONE
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
    _nodesMap[node.id] = node;
    _invalidateCache();
    notifyListeners();
  }

  void updateNameNode(String id, String name) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(name: name);
      _nodesMap[id] = _nodes[index];
      notifyListeners();
    }
  }

  void updateNodeIcon(
    String id, {
    IconData? icon,
    String? iconAssetPath,
    bool clearIcon = false,
    bool clearIconAsset = false,
  }) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(
        icon: icon,
        iconAssetPath: iconAssetPath,
        clearIcon: clearIcon,
        clearIconAsset: clearIconAsset,
      );
      _nodesMap[id] = _nodes[index];
      notifyListeners();
    }
  }

  void updateNodeColor(String id, Color color) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(color: color);
      _nodesMap[id] = _nodes[index];
      notifyListeners();
    }
  }

  void updateNodeBorderStyle(String id, BorderStyleType borderStyle) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(borderStyle: borderStyle);
      _nodesMap[id] = _nodes[index];
      notifyListeners();
    }
  }

  void updateEdgeColor(String id, Color color) {
    final index = _edges.indexWhere((e) => e.id == id);
    if (index != -1) {
      _edges[index] = _edges[index].copyWith(color: color);
    } else {
      for (int i = 0; i < _edges.length; i++) {
        final visibleSource = _getVisibleEndpoint(_edges[i].sourceId);
        final visibleTarget = _getVisibleEndpoint(_edges[i].targetId);
        final compositeKey = '$visibleSource-$visibleTarget';
        if (compositeKey == id) {
          _edges[i] = _edges[i].copyWith(color: color);
        }
      }
    }
    _invalidateCache();
    notifyListeners();
  }

  void updateEdgeBorderStyle(String id, BorderStyleType style) {
    final index = _edges.indexWhere((e) => e.id == id);
    if (index != -1) {
      _edges[index] = _edges[index].copyWith(borderStyle: style);
    } else {
      for (int i = 0; i < _edges.length; i++) {
        final visibleSource = _getVisibleEndpoint(_edges[i].sourceId);
        final visibleTarget = _getVisibleEndpoint(_edges[i].targetId);
        final compositeKey = '$visibleSource-$visibleTarget';
        if (compositeKey == id) {
          _edges[i] = _edges[i].copyWith(borderStyle: style);
        }
      }
    }
    _invalidateCache();
    notifyListeners();
  }

  void updateEdgeLabel(String id, String label) {
    final index = _edges.indexWhere((e) => e.id == id);
    if (index != -1) {
      _edges[index] = _edges[index].copyWith(label: label);
    } else {
      for (int i = 0; i < _edges.length; i++) {
        final visibleSource = _getVisibleEndpoint(_edges[i].sourceId);
        final visibleTarget = _getVisibleEndpoint(_edges[i].targetId);
        final compositeKey = '$visibleSource-$visibleTarget';
        if (compositeKey == id) {
          _edges[i] = _edges[i].copyWith(label: label);
        }
      }
    }
    _invalidateCache();
    notifyListeners();
  }

  void updateEdgeArrows(String id, {bool? showSource, bool? showTarget}) {
    final index = _edges.indexWhere((e) => e.id == id);
    if (index != -1) {
      _edges[index] = _edges[index].copyWith(
        showSourceArrow: showSource,
        showTargetArrow: showTarget,
      );
    } else {
      for (int i = 0; i < _edges.length; i++) {
        final visibleSource = _getVisibleEndpoint(_edges[i].sourceId);
        final visibleTarget = _getVisibleEndpoint(_edges[i].targetId);
        final compositeKey = '$visibleSource-$visibleTarget';
        if (compositeKey == id) {
          _edges[i] = _edges[i].copyWith(
            showSourceArrow: showSource,
            showTargetArrow: showTarget,
          );
        }
      }
    }
    _invalidateCache();
    notifyListeners();
  }

  void resizeNode(String id, Size newSize) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final width = newSize.width < 150 ? 150.0 : newSize.width;
      final height = newSize.height < 100 ? 100.0 : newSize.height;

      _nodes[index] = _nodes[index].copyWith(size: Size(width, height));
      _nodesMap[id] = _nodes[index];
      _invalidateCache(pathsOnly: true);
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

    // Lista di supporto per spostare i nodi in movimento in fondo all'array
    List<GraphNode> movedNodes = [];

    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      if (allIdsToMove.contains(node.id)) {
        _nodes[i] = node.copyWith(position: node.position + delta);
        _nodesMap[node.id] = _nodes[i];
        movedNodes.add(_nodes[i]);
      }
    }

    // Portali in fondo alla lista per garantire il primo piano visivo DURANTE il drag
    if (movedNodes.isNotEmpty) {
      _nodes.removeWhere((n) => allIdsToMove.contains(n.id));
      _nodes.addAll(movedNodes);
    }

    _invalidateCache(pathsOnly: true);
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
    final Set<String> familyIds = {nodeId};
    void findDescendants(String parentId) {
      for (var n in _nodes) {
        if (n.parentId == parentId && !familyIds.contains(n.id)) {
          familyIds.add(n.id);
          findDescendants(n.id);
        }
      }
    }

    findDescendants(nodeId);

    List<GraphNode> familyNodes = [];
    for (var n in _nodes) {
      if (familyIds.contains(n.id)) {
        familyNodes.add(n);
      }
    }

    if (familyNodes.isNotEmpty) {
      _nodes.removeWhere((n) => familyIds.contains(n.id));
      _nodes.addAll(familyNodes);
    }

    _recalculateHierarchyBasedOnGeometry();
    notifyListeners();
  }

  void autoAdoptNodes(GraphNode container) {
    _recalculateHierarchyBasedOnGeometry();
    notifyListeners();
  }

  void _enforceParentChildZOrder() {
    bool requiresSorting = true;
    while (requiresSorting) {
      requiresSorting = false;
      for (int i = 0; i < _nodes.length; i++) {
        final node = _nodes[i];
        if (node.parentId != null) {
          final parentIndex = _nodes.indexWhere((n) => n.id == node.parentId);
          if (parentIndex != -1 && parentIndex > i) {
            final childToMove = _nodes.removeAt(i);
            _nodes.insert(parentIndex, childToMove);
            requiresSorting = true;
            break;
          }
        }
      }
    }
  }

  void updateContainerChildren(String containerId) {
    _recalculateHierarchyBasedOnGeometry();
    notifyListeners();
  }

  void _bringOverlappingNodesToFront(String containerId) {
    final containerIndex = _nodes.indexWhere((n) => n.id == containerId);
    if (containerIndex == -1) return;

    final container = _nodes[containerIndex];
    final containerRect = _getEffectiveRect(container);

    Set<String> overlappingIds = {};
    for (var n in _nodes) {
      if (n.id == containerId ||
          n.parentId == containerId ||
          _isAncestor(n.id, containerId)) {
        continue;
      }
      if (containerRect.overlaps(_getEffectiveRect(n))) {
        overlappingIds.add(n.id);
      }
    }

    if (overlappingIds.isEmpty) return;

    Set<String> familyIds = Set.from(overlappingIds);
    void findDescendants(String parentId) {
      for (var n in _nodes) {
        if (n.parentId == parentId && !familyIds.contains(n.id)) {
          familyIds.add(n.id);
          findDescendants(n.id);
        }
      }
    }

    for (var id in overlappingIds) {
      findDescendants(id);
    }

    List<GraphNode> nodesToFront = [];
    for (var n in _nodes) {
      if (familyIds.contains(n.id)) {
        nodesToFront.add(n);
      }
    }

    if (nodesToFront.isNotEmpty) {
      _nodes.removeWhere((n) => familyIds.contains(n.id));
      _nodes.addAll(nodesToFront);
    }
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
      _nodesMap[nodeId] = _nodes[index];
      _invalidateCache();
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
    Set<String> visited = {nodeId};

    while (current != null && current.parentId != null) {
      if (visited.contains(current.parentId!)) break;
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
    if (_cachedAggregatedEdges != null) return _cachedAggregatedEdges!;

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
          label: existing.label,
          color: existing.color,
          borderStyle: existing.borderStyle,
          showSourceArrow: existing.showSourceArrow,
          showTargetArrow: existing.showTargetArrow,
        );
      } else {
        aggregatedMap[key] = AggregatedEdge(
          id: key,
          sourceId: visibleSource,
          targetId: visibleTarget,
          count: 1,
          label: edge.label,
          color: edge.color,
          borderStyle: edge.borderStyle,
          showSourceArrow: edge.showSourceArrow,
          showTargetArrow: edge.showTargetArrow,
        );
      }
    }
    _cachedAggregatedEdges = aggregatedMap.values.toList();
    return _cachedAggregatedEdges!;
  }

  List<Offset> getEdgePath(AggregatedEdge edge) {
    if (_edgePathCache.containsKey(edge.id)) return _edgePathCache[edge.id]!;

    final source = _nodes.cast<GraphNode?>().firstWhere(
      (n) => n?.id == edge.sourceId,
      orElse: () => null,
    );
    final target = _nodes.cast<GraphNode?>().firstWhere(
      (n) => n?.id == edge.targetId,
      orElse: () => null,
    );

    if (source == null || target == null) return [];

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

    final aggregatedEdges = getAggregatedEdges();
    final Map<String, List<String>> nodePorts = {};
    for (var e in aggregatedEdges) {
      nodePorts.putIfAbsent(e.sourceId, () => []).add(e.id);
      nodePorts.putIfAbsent(e.targetId, () => []).add(e.id);
    }

    final sourceIndex = nodePorts[source.id]?.indexOf(edge.id) ?? 0;
    final sourceTotal = nodePorts[source.id]?.length ?? 1;
    final targetIndex = nodePorts[target.id]?.indexOf(edge.id) ?? 0;
    final targetTotal = nodePorts[target.id]?.length ?? 1;

    final dx = tRect.center.dx - sRect.center.dx;
    final dy = tRect.center.dy - sRect.center.dy;

    Offset sOffset = Offset.zero;
    Offset tOffset = Offset.zero;
    const double minStep = 20.0;

    if (dx.abs() > dy.abs()) {
      if (sourceTotal > 1) {
        final step = ((source.size.height * 0.7) / (sourceTotal - 1)).clamp(minStep, 25.0);
        sOffset = Offset(0, (sourceIndex - (sourceTotal - 1) / 2) * step);
      }
      if (targetTotal > 1) {
        final step = ((target.size.height * 0.7) / (targetTotal - 1)).clamp(minStep, 25.0);
        tOffset = Offset(0, (targetIndex - (targetTotal - 1) / 2) * step);
      }
    } else {
      if (sourceTotal > 1) {
        final step = ((source.size.width * 0.7) / (sourceTotal - 1)).clamp(minStep, 25.0);
        sOffset = Offset((sourceIndex - (sourceTotal - 1) / 2) * step, 0);
      }
      if (targetTotal > 1) {
        final step = ((target.size.width * 0.7) / (targetTotal - 1)).clamp(minStep, 25.0);
        tOffset = Offset((targetIndex - (targetTotal - 1) / 2) * step, 0);
      }
    }

    final virtualSRect = sRect.shift(sOffset);
    final virtualTRect = tRect.shift(tOffset);

    if (_isInteracting) {
      return [
        virtualSRect.center,
        Offset(virtualSRect.center.dx, virtualTRect.center.dy),
        virtualTRect.center,
      ];
    }

    final int globalIndex = aggregatedEdges.indexOf(edge);
    final double laneOffset = (globalIndex % 6) * 20.0;

    List<Rect> obstacles = [];
    for (var node in visibleNodes) {
      if (node.id == source.id || node.id == target.id) continue;
      if (node.isContainer && (_isAncestor(node.id, source.id) || _isAncestor(node.id, target.id))) continue;
      obstacles.add(Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height));
    }

    final points = EdgeRoutingService.calculateOrthogonalPoints(
      virtualSRect,
      virtualTRect,
      obstacles: obstacles,
      laneOffset: laneOffset,
    );

    _edgePathCache[edge.id] = points;
    return points;
  }

  void startEdge(String sourceNodeId) {
    _draftEdgeSourceId = sourceNodeId;
    _draftEdgeTarget = null;
    notifyListeners();
  }

  void updateDraftEdge(Offset pointerPosition) {
    if (!isCreatingEdge) return;
    _draftEdgeTarget = pointerPosition;
    _updateHoverState(pointerPosition);
    notifyListeners();
  }

  bool finishEdge(Offset position) {
    bool message = false;
    if (_draftEdgeSourceId == null) return message;

    GraphNode? targetNode;
    for (var node in nodes.reversed) {
      if (node.id == _draftEdgeSourceId) continue;
      final rect = Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);
      if (rect.contains(position)) {
        targetNode = node;
        break;
      }
    }

    if (targetNode != null) {
      bool edgeAlreadyExists = edges.any((edge) {
        return (edge.sourceId == _draftEdgeSourceId && edge.targetId == targetNode!.id) ||
               (edge.sourceId == targetNode!.id && edge.targetId == _draftEdgeSourceId);
      });

      if (!edgeAlreadyExists) {
        final newEdge = GraphEdge(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sourceId: _draftEdgeSourceId!,
          targetId: targetNode.id,
        );
        edges.add(newEdge);
        _invalidateCache();
        _selectedEdges.clear();
        _selectedEdges.add(newEdge.id);
      } else {
        message = true;
      }
    }

    _draftEdgeSourceId = null;
    _draftEdgeTarget = null;
    notifyListeners();
    return message;
  }

  bool isAncestor(String ancestorId, String childId) => _isAncestor(ancestorId, childId);

  bool _isAncestor(String ancestorId, String childId) {
    String? currentId = childId;
    Set<String> visited = {childId};
    while (currentId != null) {
      final nodeIndex = _nodes.indexWhere((n) => n.id == currentId);
      if (nodeIndex == -1) break;
      final parentId = _nodes[nodeIndex].parentId;
      if (parentId == ancestorId) return true;
      if (parentId != null) {
        if (visited.contains(parentId)) break;
        visited.add(parentId);
      }
      currentId = parentId;
    }
    return false;
  }

  GraphNode? _hitTestNodes(Offset position) {
    for (var node in visibleNodes.reversed) {
      if (_getEffectiveRect(node).contains(position)) return node;
    }
    return null;
  }

  /// Ritorna solo il nodo non-container più in alto colpito dalla posizione.
  GraphNode? _hitTestNonContainerNodes(Offset position) {
    for (var node in visibleNodes.reversed) {
      if (!node.isContainer && _getEffectiveRect(node).contains(position)) {
        return node;
      }
    }
    return null;
  }

  /// Ritorna solo il container più in alto colpito dalla posizione.
  GraphNode? _hitTestContainerNodes(Offset position) {
    for (var node in visibleNodes.reversed) {
      if (node.isContainer && _getEffectiveRect(node).contains(position)) {
        return node;
      }
    }
    return null;
  }

  Alignment? _hitTestResizeHandles(Offset position) {
    if (_selectionNodes.isEmpty) return null;
    final node = _nodes.cast<GraphNode?>().firstWhere((n) => n?.id == _selectionNodes.first, orElse: () => null);
    if (node == null || !node.isContainer || node.isCollapsed) return null;

    final rect = _getEffectiveRect(node);
    const double thickness = 20.0;
    const double halfThickness = thickness / 2;

    if (Rect.fromLTWH(rect.left - halfThickness, rect.top - halfThickness, thickness, thickness).contains(position)) return Alignment.topLeft;
    if (Rect.fromLTWH(rect.right - halfThickness, rect.top - halfThickness, thickness, thickness).contains(position)) return Alignment.topRight;
    if (Rect.fromLTWH(rect.left - halfThickness, rect.bottom - halfThickness, thickness, thickness).contains(position)) return Alignment.bottomLeft;
    if (Rect.fromLTWH(rect.right - halfThickness, rect.bottom - halfThickness, thickness, thickness).contains(position)) return Alignment.bottomRight;

    if (Rect.fromLTWH(rect.left + halfThickness, rect.top - halfThickness, rect.width - thickness, thickness).contains(position)) return Alignment.topCenter;
    if (Rect.fromLTWH(rect.left + halfThickness, rect.bottom - halfThickness, rect.width - thickness, thickness).contains(position)) return Alignment.bottomCenter;
    if (Rect.fromLTWH(rect.left - halfThickness, rect.top + halfThickness, thickness, rect.height - thickness).contains(position)) return Alignment.centerLeft;
    if (Rect.fromLTWH(rect.right - halfThickness, rect.top + halfThickness, thickness, rect.height - thickness).contains(position)) return Alignment.centerRight;

    return null;
  }

  // ==========================================
  // GESTIONE LAYER (Z-INDEX)
  // ==========================================
  void reorderNodes(int oldVisualIndex, int newVisualIndex) {
    // 1. Compensazione standard di Flutter per la UI quando si trascina verso il basso
    if (oldVisualIndex < newVisualIndex) {
      newVisualIndex -= 1;
    }

    final int N = _nodes.length;

    // 2. Traduciamo gli indici visuali (dove 0 è il primo piano)
    // negli indici reali (dove N-1 è il primo piano)
    int actualOldIndex = N - 1 - oldVisualIndex;
    int actualNewIndex = N - 1 - newVisualIndex;

    // 3. Eseguiamo lo spostamento nella lista reale
    final GraphNode node = _nodes.removeAt(actualOldIndex);
    _nodes.insert(actualNewIndex, node);

    notifyListeners();
  }

  void handlePointerDown(Offset position) {
    if (_activeTool == ToolType.pan) {
      _interactionMode = InteractionMode.panning;
      _isTextEdit = false;
      notifyListeners();
      return;
    }

    _interactionMode = InteractionMode.clicking;

    if (_activeTool == ToolType.node || _activeTool == ToolType.container) {
      _isTextEdit = false;
      _createNewNodeAt(position);
      return;
    }

    if (_activeTool == ToolType.edge) {
      _isTextEdit = false;
      final node = _hitTestNodes(position);
      if (node != null) {
        startEdge(node.id);
        updateDraftEdge(position);
        _interactionMode = InteractionMode.creatingEdge;
      }
      return;
    }

    if (_activeTool == ToolType.pointer) {
      final handle = _hitTestResizeHandles(position);
      if (handle != null) {
        _isTextEdit = false;
        _interactionMode = InteractionMode.resizingNode;
        _activeResizeHandle = handle;
        _interactingNodeId = _selectionNodes.first;
        return;
      }

      // PRIORITÀ 1: nodi non-container (icone/nodi foglia)
      final nonContainerNode = _hitTestNonContainerNodes(position);
      if (nonContainerNode != null) {
        _interactionMode = InteractionMode.draggingNode;
        _interactingNodeId = nonContainerNode.id;
        if (!selection.contains(nonContainerNode.id)) {
          setSelection(nonContainerNode.id);
          _isTextEdit = false;
        }
        return;
      }

      // PRIORITÀ 2: frecce (anche quelle dentro container)
      if (trySelectEdgeAt(position)) {
        _isTextEdit = false;
        return;
      }

      // PRIORITÀ 3: container
      final containerNode = _hitTestContainerNodes(position);
      if (containerNode != null) {
        _interactionMode = InteractionMode.draggingNode;
        _interactingNodeId = containerNode.id;
        if (!selection.contains(containerNode.id)) {
          setSelection(containerNode.id);
          _isTextEdit = false;
        }
        return;
      }

      _isTextEdit = false;
      clearSelection();
      _interactionMode = InteractionMode.rectSelecting;
      _startPosition = position;
      _currentPosition = null;
    }
  }

  void handlePointerMove(Offset position, Offset delta) {
    switch (_interactionMode) {
      case InteractionMode.draggingNode:
        if (_interactingNodeId != null) moveNode(_interactingNodeId!, delta);
        break;
      case InteractionMode.resizingNode:
        _applyResize(delta);
        break;
      case InteractionMode.creatingEdge:
        updateDraftEdge(position);
        break;
      case InteractionMode.rectSelecting:
        _currentPosition = position;
        Rect rect = Rect.fromPoints(_startPosition!, _currentPosition!);
        updateSelectionFromRect(rect);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  bool handlePointerUp(Offset position) {
    bool message = false;
    if (_interactionMode == InteractionMode.creatingEdge) {
      message = finishEdge(position);
    } else if (_interactionMode == InteractionMode.draggingNode && _interactingNodeId != null) {
      handleNodeDrop(_interactingNodeId!);
    } else if (_interactionMode == InteractionMode.resizingNode && _interactingNodeId != null) {
      updateContainerChildren(_interactingNodeId!);
    }
    _interactionMode = InteractionMode.idle;
    _activeResizeHandle = null;
    _interactingNodeId = null;
    _startPosition = null;
    notifyListeners();
    return message;
  }

  void _applyResize(Offset rawDelta) {
    if (_interactingNodeId == null || _activeResizeHandle == null) return;
    final index = _nodes.indexWhere((n) => n.id == _interactingNodeId);
    if (index == -1) return;

    final node = _nodes[index];
    final deltaX = rawDelta.dx / zoomScale;
    final deltaY = rawDelta.dy / zoomScale;

    double newWidth = node.size.width;
    double newHeight = node.size.height;
    double newX = node.position.dx;
    double newY = node.position.dy;

    const double minWidth = 150.0;
    const double minHeight = 100.0;

    if (_activeResizeHandle == Alignment.centerRight || _activeResizeHandle == Alignment.topRight || _activeResizeHandle == Alignment.bottomRight) {
      newWidth += deltaX;
    } else if (_activeResizeHandle == Alignment.centerLeft || _activeResizeHandle == Alignment.topLeft || _activeResizeHandle == Alignment.bottomLeft) {
      final proposedWidth = newWidth - deltaX;
      if (proposedWidth >= minWidth) {
        newWidth = proposedWidth;
        newX += deltaX;
      }
    }

    if (_activeResizeHandle == Alignment.bottomCenter || _activeResizeHandle == Alignment.bottomLeft || _activeResizeHandle == Alignment.bottomRight) {
      newHeight += deltaY;
    } else if (_activeResizeHandle == Alignment.topCenter || _activeResizeHandle == Alignment.topLeft || _activeResizeHandle == Alignment.topRight) {
      final proposedHeight = newHeight - deltaY;
      if (proposedHeight >= minHeight) {
        newHeight = proposedHeight;
        newY += deltaY;
      }
    }

    newWidth = newWidth < minWidth ? minWidth : newWidth;
    newHeight = newHeight < minHeight ? minHeight : newHeight;

    _nodes[index] = node.copyWith(size: Size(newWidth, newHeight), position: Offset(newX, newY));
    _nodesMap[_interactingNodeId!] = _nodes[index];
    _invalidateCache(pathsOnly: true);
    _bringOverlappingNodesToFront(_interactingNodeId!);
    notifyListeners();
  }

  void _createNewNodeAt(Offset position) {
    final isContainer = _activeTool == ToolType.container;
    final nodeSize = isContainer ? GraphNode.defaultContainerSize : GraphNode.defaultNodeSize;
    final centeredPosition = Offset(position.dx - nodeSize.width / 2, position.dy - nodeSize.height / 2);
    var nodeToAdd = GraphNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: isContainer ? 'New Container' : 'New Node',
      position: centeredPosition,
      size: nodeSize,
      oldSize: isContainer ? nodeSize : null,
      isContainer: isContainer,
    );
    addNode(nodeToAdd);
    if (isContainer) autoAdoptNodes(nodeToAdd);
    setTool(ToolType.pointer);
    setSelection(nodeToAdd.id);
  }

  void handleToolChange(ToolType tool) {
    _startPosition = null;
    _currentPosition = null;
    setTool(tool);
  }

  void _recalculateHierarchyBasedOnGeometry() {
    Map<String, Rect> rects = {};
    for (var n in _nodes) {
      rects[n.id] = _getEffectiveRect(n);
    }

    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      if (_isNodeHiddenByCollapsedParent(node)) continue;

      String? newParentId;
      double minArea = double.infinity;

      for (var container in _nodes) {
        if (!container.isContainer || container.id == node.id || container.isCollapsed) continue;
        final cRect = rects[container.id]!;
        final nRect = rects[node.id]!;
        final inflatedCRect = cRect.inflate(0.5);

        if (inflatedCRect.contains(nRect.topLeft) && inflatedCRect.contains(nRect.bottomRight)) {
          final area = cRect.width * cRect.height;
          if (area < minArea) {
            minArea = area;
            newParentId = container.id;
          }
        }
      }

      if (newParentId != null) {
        _nodes[i] = node.copyWith(parentId: newParentId);
        _nodesMap[node.id] = _nodes[i];
      } else {
        _nodes[i] = node.copyWith(clearParent: true);
        _nodesMap[node.id] = _nodes[i];
      }
    }
    _enforceParentChildZOrder();
  }

  bool _isNodeHiddenByCollapsedParent(GraphNode node) {
    String? currentParentId = node.parentId;
    while (currentParentId != null) {
      final pIndex = _nodes.indexWhere((n) => n.id == currentParentId);
      if (pIndex == -1) break;
      if (_nodes[pIndex].isCollapsed) return true;
      currentParentId = _nodes[pIndex].parentId;
    }
    return false;
  }

  Set<String> get explorerActiveNodes {
    if (_activeTool != ToolType.explorer || _hoveredNodeId == null) return {};
    Set<String> group = {_hoveredNodeId!};
    for (var node in _nodes) if (_isAncestor(_hoveredNodeId!, node.id)) group.add(node.id);
    Set<String> active = Set.from(group);
    for (var edge in getAggregatedEdges()) {
      if (group.contains(edge.sourceId)) active.add(edge.targetId);
      if (group.contains(edge.targetId)) active.add(edge.sourceId);
    }
    for (var edge in _edges) {
      if (group.contains(edge.sourceId)) active.add(edge.targetId);
      if (group.contains(edge.targetId)) active.add(edge.sourceId);
    }
    return active;
  }

  Set<String> get explorerActiveEdges {
    if (_activeTool != ToolType.explorer || _hoveredNodeId == null) return {};
    Set<String> group = {_hoveredNodeId!};
    for (var node in _nodes) if (_isAncestor(_hoveredNodeId!, node.id)) group.add(node.id);
    Set<String> activeEdges = {};
    for (var edge in getAggregatedEdges()) {
      if (group.contains(edge.sourceId) || group.contains(edge.targetId)) activeEdges.add(edge.id);
    }
    for (var edge in _edges) {
      if (group.contains(edge.sourceId) || group.contains(edge.targetId)) activeEdges.add(edge.id);
    }
    return activeEdges;
  }
}
