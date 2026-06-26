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

  // Controlla se la telecamera può muoversi: solo se il tool attivo è il PAN
  bool get canPanCanvas => _activeTool == ToolType.pan;

  InteractionMode get interactionMode => _interactionMode;

  // ==========================================
  // GETTER GENERALI
  // ==========================================
  Offset? get currentPosition => _currentPosition;

  List<GraphNode> get nodes => _nodes;

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
    clearSelection();
    notifyListeners();
  }

  void setZoomScale(double zoomScale) {
    _zoomScale = zoomScale;
    notifyListeners();
  }

  void updateCurrentPosition(Offset position) {
    _currentPosition = position;
    _updateHoverState(position);
  }

  void _updateHoverState(Offset position) {
    // Gestione Hover per il tool Edge o Explorer
    if (_activeTool == ToolType.edge || _activeTool == ToolType.explorer) {
      final hitNode = _hitTestNodes(position);
      if (_hoveredNodeId != hitNode?.id) {
        _hoveredNodeId = hitNode?.id;
        notifyListeners();
      }
    } else if (_hoveredNodeId != null) {
      _hoveredNodeId = null;
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  // ==========================================
  // GESTIONE SELEZIONE E RIMOZIONE
  // ==========================================
  void setSelection(String id) {
    _selectionNodes = [id];
    _isTextEdit = false;
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
    final Map<String, List<String>> nodePorts = {};

    for (var edge in aggregatedEdges) {
      final source = _nodes.cast<GraphNode?>().firstWhere(
        (n) => n?.id == edge.sourceId,
        orElse: () => null,
      );
      final target = _nodes.cast<GraphNode?>().firstWhere(
        (n) => n?.id == edge.targetId,
        orElse: () => null,
      );
      if (source == null || target == null || source.id == target.id) continue;

      nodePorts.putIfAbsent(source.id, () => []).add(edge.id);
      nodePorts.putIfAbsent(target.id, () => []).add(edge.id);
    }

    String? bestEdgeId;

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

      // Se il click è dentro il rettangolo di un nodo sorgente o target,
      // ignoriamo la freccia per dare precedenza al nodo.
      if (sRect.contains(localPosition) || tRect.contains(localPosition)) {
        continue;
      }

      final sourceIndex = nodePorts[source.id]!.indexOf(edge.id);
      final sourceTotal = nodePorts[source.id]!.length;

      final targetIndex = nodePorts[target.id]!.indexOf(edge.id);
      final targetTotal = nodePorts[target.id]!.length;

      final dx = tRect.center.dx - sRect.center.dx;
      final dy = tRect.center.dy - sRect.center.dy;

      Offset sOffset = Offset.zero;
      Offset tOffset = Offset.zero;

      const double minStep = 20.0;

      if (dx.abs() > dy.abs()) {
        if (sourceTotal > 1) {
          final step = ((source.size.height * 0.7) / (sourceTotal - 1)).clamp(
            minStep,
            25.0,
          );
          sOffset = Offset(0, (sourceIndex - (sourceTotal - 1) / 2) * step);
        }
        if (targetTotal > 1) {
          final step = ((target.size.height * 0.7) / (targetTotal - 1)).clamp(
            minStep,
            25.0,
          );
          tOffset = Offset(0, (targetIndex - (targetTotal - 1) / 2) * step);
        }
      } else {
        if (sourceTotal > 1) {
          final step = ((source.size.width * 0.7) / (sourceTotal - 1)).clamp(
            minStep,
            25.0,
          );
          sOffset = Offset((sourceIndex - (sourceTotal - 1) / 2) * step, 0);
        }
        if (targetTotal > 1) {
          final step = ((target.size.width * 0.7) / (targetTotal - 1)).clamp(
            minStep,
            25.0,
          );
          tOffset = Offset((targetIndex - (targetTotal - 1) / 2) * step, 0);
        }
      }

      final virtualSRect = sRect.shift(sOffset);
      final virtualTRect = tRect.shift(tOffset);

      final int globalIndex = aggregatedEdges.indexOf(edge);
      final double laneOffset = (globalIndex % 6) * 20.0;

      List<Rect> obstacles = [];
      for (var node in visibleNodes) {
        if (node.id == edge.sourceId || node.id == edge.targetId) continue;

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

      // Usiamo una soglia di hit-test un po' più generosa (16.0 pixel)
      if (EdgeRoutingService.isPointNearEdge(localPosition, points, 16.0)) {
        // Trovata! Invece di ritornare subito, cerchiamo se ce n'è una più vicina
        // (utile se sono molto ammassate)
        bestEdgeId = edge.id;
        break; // Per ora prendiamo la prima che capita ma con logica sincronizzata
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

      const double minStep = 20.0;

      if (dx.abs() > dy.abs()) {
        if (sourceTotal > 1) {
          final step = ((source.size.height * 0.7) / (sourceTotal - 1)).clamp(
            minStep,
            25.0,
          );
          sOffset = Offset(0, (sourceIndex - (sourceTotal - 1) / 2) * step);
        }
        if (targetTotal > 1) {
          final step = ((target.size.height * 0.7) / (targetTotal - 1)).clamp(
            minStep,
            25.0,
          );
          tOffset = Offset(0, (targetIndex - (targetTotal - 1) / 2) * step);
        }
      } else {
        if (sourceTotal > 1) {
          final step = ((source.size.width * 0.7) / (sourceTotal - 1)).clamp(
            minStep,
            25.0,
          );
          sOffset = Offset((sourceIndex - (sourceTotal - 1) / 2) * step, 0);
        }
        if (targetTotal > 1) {
          final step = ((target.size.width * 0.7) / (targetTotal - 1)).clamp(
            minStep,
            25.0,
          );
          tOffset = Offset((targetIndex - (targetTotal - 1) / 2) * step, 0);
        }
      }

      final virtualSRect = sRect.shift(sOffset);
      final virtualTRect = tRect.shift(tOffset);

      final int globalIndex = aggregatedEdges.indexOf(edge);
      final double laneOffset = (globalIndex % 6) * 20.0;

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
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(name: name);
      notifyListeners();
    }
  }

  void updateNodeIcon(String id, IconData? icon) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(
        icon: icon,
        clearIcon: icon == null,
      );
      notifyListeners();
    }
  }

  void updateNodeColor(String id, Color color) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(color: color);
      notifyListeners();
    }
  }

  void updateNodeBorderStyle(String id, BorderStyleType borderStyle) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(borderStyle: borderStyle);
      notifyListeners();
    }
  }

  void updateNodeCardinality(String id, CardinalityType cardinality) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(cardinality: cardinality);
      notifyListeners();
    }
  }

  void updateNodeCardinalityRange(String id, String? start, String? end) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(
        cardinalityStart: start,
        cardinalityEnd: end,
        clearCardinalityStart: start == null || start.isEmpty,
        clearCardinalityEnd: end == null || end.isEmpty,
      );
      notifyListeners();
    }
  }

  void updateEdgeColor(String id, Color color) {
    // Gestiamo sia edge reali che aggregati (usando la logica di mappatura se necessario)
    // Per ora, cerchiamo l'edge reale.
    final index = _edges.indexWhere((e) => e.id == id);
    if (index != -1) {
      _edges[index] = _edges[index].copyWith(color: color);
    } else {
      // Se è un edge aggregato, cerchiamo tutti gli edge reali sottostanti
      for (int i = 0; i < _edges.length; i++) {
        final visibleSource = _getVisibleEndpoint(_edges[i].sourceId);
        final visibleTarget = _getVisibleEndpoint(_edges[i].targetId);
        final compositeKey = '$visibleSource-$visibleTarget';
        if (compositeKey == id) {
          _edges[i] = _edges[i].copyWith(color: color);
        }
      }
    }
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

    // Lista di supporto per spostare i nodi in movimento in fondo all'array
    List<GraphNode> movedNodes = [];

    for (var node in _nodes) {
      if (allIdsToMove.contains(node.id)) {
        node.position += delta;
        movedNodes.add(node);
      }
    }

    // Portali in fondo alla lista per garantire il primo piano visivo DURANTE il drag
    if (movedNodes.isNotEmpty) {
      _nodes.removeWhere((n) => allIdsToMove.contains(n.id));
      _nodes.addAll(movedNodes);
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
    // 1. Portiamo la famiglia trascinata in primo piano visivo (Invariato)
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

    // ==========================================
    // 2. APPLICHIAMO LA REGOLA GEOMETRICA
    // ==========================================
    _recalculateHierarchyBasedOnGeometry();

    notifyListeners();
  }

  void autoAdoptNodes(GraphNode container) {
    // Appena viene creato un nuovo elemento, diamo una passata alla gerarchia
    // per vedere se ingloba qualcosa di pre-esistente
    _recalculateHierarchyBasedOnGeometry();
    notifyListeners();
  }

  // ==========================================
  // HELPER: GARANTISCE CHE I FIGLI SIANO SEMPRE SOPRA I PADRI
  // ==========================================
  void _enforceParentChildZOrder() {
    bool requiresSorting = true;

    // Continua a ciclare finché non ci sono più conflitti di Z-Index
    while (requiresSorting) {
      requiresSorting = false;

      for (int i = 0; i < _nodes.length; i++) {
        final node = _nodes[i];

        // Se il nodo ha un padre, verifichiamo dove si trova il padre
        if (node.parentId != null) {
          final parentIndex = _nodes.indexWhere((n) => n.id == node.parentId);

          // Se l'indice del padre è MAGGIORE di quello del figlio,
          // significa che il padre verrà disegnato DOPO e coprirà il figlio.
          if (parentIndex != -1 && parentIndex > i) {
            // 1. Rimuoviamo il figlio dalla sua posizione errata (sotto)
            final childToMove = _nodes.removeAt(i);

            // 2. Lo reinseriamo esattamente un livello SOPRA al padre.
            // (Nota: poiché abbiamo rimosso un elemento prima del padre,
            // il nuovo indice del padre è sceso di 1. Inserendo a `parentIndex`
            // lo mettiamo automaticamente subito DOPO il padre).
            _nodes.insert(parentIndex, childToMove);

            requiresSorting = true;
            break; // Rompiamo il ciclo `for` per ricominciare con gli indici aggiornati
          }
        }
      }
    }
  }

  void updateContainerChildren(String containerId) {
    // La logica geometrica ha stabilito che: "I figli devono rimanere invariati durante il resize"
    // Nessun nodo adotta o abbandona figli durante un resize.

    // Ci assicuriamo solo che il ridimensionamento non abbia rotto lo Z-Index
    _recalculateHierarchyBasedOnGeometry();
    notifyListeners();
  }

  // ==========================================
  // HELPER: Z-INDEX REAL-TIME PER IL RESIZE
  // ==========================================
  void _bringOverlappingNodesToFront(String containerId) {
    final containerIndex = _nodes.indexWhere((n) => n.id == containerId);
    if (containerIndex == -1) return;

    final container = _nodes[containerIndex];
    final containerRect = _getEffectiveRect(container);

    Set<String> overlappingIds = {};

    // 1. Trova tutti i nodi toccati dal container in espansione
    for (var n in _nodes) {
      // Ignora il container stesso, i suoi figli diretti (già gestiti) e i suoi antenati
      if (n.id == containerId ||
          n.parentId == containerId ||
          _isAncestor(n.id, containerId)) {
        continue;
      }

      // Se i rettangoli si intersecano (overlaps), segnala il nodo per il primo piano
      if (containerRect.overlaps(_getEffectiveRect(n))) {
        overlappingIds.add(n.id);
      }
    }

    if (overlappingIds.isEmpty) return;

    // 2. Recupera intere "famiglie" per non separare container inglobati dai loro stessi figli
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

    // 3. Estrai i nodi mantenendo il loro ordine visivo preesistente tra di loro
    List<GraphNode> nodesToFront = [];
    for (var n in _nodes) {
      if (familyIds.contains(n.id)) {
        nodesToFront.add(n);
      }
    }

    // 4. Rimuovili e accodali alla lista (posizione in fondo = primo piano)
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
      // Niente ricalcolo gerarchico, cambiamo solo l'estetica!
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
          color: edge.color,
          borderStyle: edge.borderStyle,
          showSourceArrow: edge.showSourceArrow,
          showTargetArrow: edge.showTargetArrow,
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
    _updateHoverState(pointerPosition);
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
  // HELPER GERARCHIA E OSTACOLI
  // ==========================================
  bool isAncestor(String ancestorId, String childId) {
    return _isAncestor(ancestorId, childId);
  }

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

  // ==========================================
  // HIT TESTING (Chi ho colpito?)
  // ==========================================
  GraphNode? _hitTestNodes(Offset position) {
    // Cicliamo al contrario: i nodi disegnati sopra (ultimi nella lista) hanno la precedenza
    for (var node in visibleNodes.reversed) {
      final rect = _getEffectiveRect(node);
      if (rect.contains(position)) return node;
    }
    return null;
  }

  // --- Dentro GraphProvider ---
  Alignment? _hitTestResizeHandles(Offset position) {
    if (_selectionNodes.isEmpty) return null;

    final node = _nodes.cast<GraphNode?>().firstWhere(
      (n) => n?.id == _selectionNodes.first,
      orElse: () => null,
    );

    if (node == null || !node.isContainer || node.isCollapsed) return null;

    final rect = _getEffectiveRect(node);

    // Deve combaciare con lo spessore definito nella UI (NodeWidget)
    const double thickness = 20.0;
    const double halfThickness = thickness / 2;

    // ==========================================
    // LOGICA DI HIT-TEST CONTINUA
    // Verifichiamo se il punto è dentro i rettangoli perimetrali
    // ==========================================

    // 1. Controllo PRIORITARIO degli Angoli
    // (Sono quadrati thickness x thickness posizionati a cavallo degli angoli reali)

    // Top-Left
    if (Rect.fromLTWH(
      rect.left - halfThickness,
      rect.top - halfThickness,
      thickness,
      thickness,
    ).contains(position)) {
      return Alignment.topLeft;
    }
    // Top-Right
    if (Rect.fromLTWH(
      rect.right - halfThickness,
      rect.top - halfThickness,
      thickness,
      thickness,
    ).contains(position)) {
      return Alignment.topRight;
    }
    // Bottom-Left
    if (Rect.fromLTWH(
      rect.left - halfThickness,
      rect.bottom - halfThickness,
      thickness,
      thickness,
    ).contains(position)) {
      return Alignment.bottomLeft;
    }
    // Bottom-Right
    if (Rect.fromLTWH(
      rect.right - halfThickness,
      rect.bottom - halfThickness,
      thickness,
      thickness,
    ).contains(position)) {
      return Alignment.bottomRight;
    }

    // 2. Controllo dei Bordi (le barre lunghe esclusi gli angoli)

    // Bordo Nord (Top)
    if (Rect.fromLTWH(
      rect.left + halfThickness,
      rect.top - halfThickness,
      rect.width - thickness,
      thickness,
    ).contains(position)) {
      return Alignment.topCenter;
    }
    // Bordo Sud (Bottom)
    if (Rect.fromLTWH(
      rect.left + halfThickness,
      rect.bottom - halfThickness,
      rect.width - thickness,
      thickness,
    ).contains(position)) {
      return Alignment.bottomCenter;
    }
    // Bordo Ovest (Left)
    if (Rect.fromLTWH(
      rect.left - halfThickness,
      rect.top + halfThickness,
      thickness,
      rect.height - thickness,
    ).contains(position)) {
      return Alignment.centerLeft;
    }
    // Bordo Est (Right)
    if (Rect.fromLTWH(
      rect.right - halfThickness,
      rect.top + halfThickness,
      thickness,
      rect.height - thickness,
    ).contains(position)) {
      return Alignment.centerRight;
    }

    return null;
  }

  // ==========================================
  // GESTIONE EVENTI RAW POINTER (Invocati dal Canvas)
  // ==========================================

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

    // 1. Tool Aggiunta Nodi/Container
    if (_activeTool == ToolType.node || _activeTool == ToolType.container) {
      // Se clicchiamo sopra un nodo esistente, non ne creiamo uno nuovo ma lo selezioniamo
      _isTextEdit = false;
      _createNewNodeAt(position);
      return;
    }

    // 2. Tool Creazione Archi
    if (_activeTool == ToolType.edge) {
      _isTextEdit = false;
      final node = _hitTestNodes(position);
      if (node != null) {
        startEdge(node.id);
        _interactionMode = InteractionMode.creatingEdge;
      }
      return;
    }

    // 3. Tool Puntatore (Selezione, Drag, Resize)
    if (_activeTool == ToolType.pointer) {
      // A. Ho colpito una maniglia di ridimensionamento?
      final handle = _hitTestResizeHandles(position);
      if (handle != null) {
        _isTextEdit = false;
        _interactionMode = InteractionMode.resizingNode;
        _activeResizeHandle = handle;
        _interactingNodeId = _selectionNodes.first;
        return;
      }

      // C. Ho colpito un Arco?
      if (trySelectEdgeAt(position)) {
        _isTextEdit = false;
        return;
      }

      // B. Ho colpito un Nodo?
      final node = _hitTestNodes(position);
      if (node != null) {
        // Se il nodo era già selezionato, forse stiamo cliccando sul testo.
        // NON resettiamo _isTextEdit qui se il click è dentro il nodo,
        // perché il TextField gestirà il suo stato.
        // Tuttavia, se è un click per trascinare, lo resettiamo dopo.

        _interactionMode = InteractionMode.draggingNode;
        _interactingNodeId = node.id;

        if (!selection.contains(node.id)) {
          setSelection(node.id);
          _isTextEdit = false;
        }
        return;
      }

      // D. Ho cliccato nel vuoto: iniziamo la selezione rettangolare
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
        // Aggiorna le coordinate del rettangolo
        _currentPosition = position;
        Rect rect = Rect.fromPoints(_startPosition!, _currentPosition!);
        updateSelectionFromRect(rect);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void handlePointerUp(Offset position) {
    if (_interactionMode == InteractionMode.creatingEdge) {
      finishEdge(position);
    } else if (_interactionMode == InteractionMode.draggingNode &&
        _interactingNodeId != null) {
      handleNodeDrop(_interactingNodeId!);
    } else if (_interactionMode == InteractionMode.resizingNode &&
        _interactingNodeId != null) {
      updateContainerChildren(_interactingNodeId!);
    }

    // Resetta lo stato
    _interactionMode = InteractionMode.idle;
    _activeResizeHandle = null;
    _interactingNodeId = null;
    _startPosition = null;
    notifyListeners();
  }

  void _applyResize(Offset rawDelta) {
    if (_interactingNodeId == null || _activeResizeHandle == null) return;

    final index = _nodes.indexWhere((n) => n.id == _interactingNodeId);
    if (index == -1) return;

    final node = _nodes[index];

    // Convertiamo il delta tenendo conto dello zoom
    final deltaX = rawDelta.dx / zoomScale;
    final deltaY = rawDelta.dy / zoomScale;

    double newWidth = node.size.width;
    double newHeight = node.size.height;
    double newX = node.position.dx;
    double newY = node.position.dy;

    // Dimensioni minime di sicurezza
    const double minWidth = 150.0;
    const double minHeight = 100.0;

    // 1. Asse X (Larghezza e Posizione Orizzontale)
    if (_activeResizeHandle == Alignment.centerRight ||
        _activeResizeHandle == Alignment.topRight ||
        _activeResizeHandle == Alignment.bottomRight) {
      newWidth += deltaX;
    } else if (_activeResizeHandle == Alignment.centerLeft ||
        _activeResizeHandle == Alignment.topLeft ||
        _activeResizeHandle == Alignment.bottomLeft) {
      final proposedWidth = newWidth - deltaX;
      if (proposedWidth >= minWidth) {
        newWidth = proposedWidth;
        newX += deltaX; // Se riduco da sinistra, il punto di origine avanza
      }
    }

    // 2. Asse Y (Altezza e Posizione Verticale)
    if (_activeResizeHandle == Alignment.bottomCenter ||
        _activeResizeHandle == Alignment.bottomLeft ||
        _activeResizeHandle == Alignment.bottomRight) {
      newHeight += deltaY;
    } else if (_activeResizeHandle == Alignment.topCenter ||
        _activeResizeHandle == Alignment.topLeft ||
        _activeResizeHandle == Alignment.topRight) {
      final proposedHeight = newHeight - deltaY;
      if (proposedHeight >= minHeight) {
        newHeight = proposedHeight;
        newY += deltaY; // Se riduco dall'alto, il punto di origine scende
      }
    }

    // 3. Forziamo il blocco finale delle dimensioni minime
    newWidth = newWidth < minWidth ? minWidth : newWidth;
    newHeight = newHeight < minHeight ? minHeight : newHeight;

    // 4. Aggiorniamo il nodo
    _nodes[index] = node.copyWith(
      size: Size(newWidth, newHeight),
      position: Offset(newX, newY),
    );

    // ========================================================
    // 5. NOVITÀ: Portiamo in primo piano gli elementi inglobati
    // ========================================================
    _bringOverlappingNodesToFront(_interactingNodeId!);

    notifyListeners();
  }

  void _createNewNodeAt(Offset position) {
    final isContainer = _activeTool == ToolType.container;
    final nodeSize = isContainer
        ? GraphNode.defaultContainerSize
        : GraphNode.defaultNodeSize;

    // Centra il nodo rispetto al click del mouse
    final centeredPosition = Offset(
      position.dx - nodeSize.width / 2,
      position.dy - nodeSize.height / 2,
    );

    var nodeToAdd = GraphNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: isContainer ? 'New Container' : 'New Node',
      position: centeredPosition,
      size: nodeSize,
      oldSize: isContainer ? nodeSize : null,
      isContainer: isContainer,
    );

    addNode(nodeToAdd);

    if (isContainer) {
      autoAdoptNodes(nodeToAdd);
    }

    // Torna automaticamente al tool puntatore e seleziona il nuovo nodo
    setTool(ToolType.pointer);
    setSelection(nodeToAdd.id);
  }

  void handleToolChange(ToolType tool) {
    _startPosition = null;
    _currentPosition = null;
    setTool(tool);
  }

  // ==========================================
  // MOTORE DI GERARCHIA GEOMETRICA
  // ==========================================
  // ==========================================
  // MOTORE DI GERARCHIA GEOMETRICA
  // ==========================================
  void _recalculateHierarchyBasedOnGeometry() {
    Map<String, Rect> rects = {};
    for (var n in _nodes) {
      rects[n.id] = _getEffectiveRect(n);
    }

    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];

      // 1. PROTEZIONE COLLAPSE: Se il nodo si trova dentro un container collassato,
      // la sua gerarchia è "congelata". Saltiamo il ricalcolo per lui.
      if (_isNodeHiddenByCollapsedParent(node)) {
        continue;
      }

      String? newParentId;
      double minArea = double.infinity;

      for (var container in _nodes) {
        if (!container.isContainer || container.id == node.id) continue;

        // Opzionale ma consigliato: un container attualmente collassato
        // non dovrebbe inglobare nuovi elementi estranei.
        if (container.isCollapsed) continue;

        final cRect = rects[container.id]!;
        final nRect = rects[node.id]!;

        final inflatedCRect = cRect.inflate(0.5);

        if (inflatedCRect.contains(nRect.topLeft) &&
            inflatedCRect.contains(nRect.bottomRight)) {
          final area = cRect.width * cRect.height;
          if (area < minArea) {
            minArea = area;
            newParentId = container.id;
          }
        }
      }

      if (newParentId != null) {
        _nodes[i] = node.copyWith(parentId: newParentId);
      } else {
        _nodes[i] = node.copyWith(clearParent: true);
      }
    }

    _enforceParentChildZOrder();
  }

  // HELPER: Controlla se il nodo ha un antenato attualmente collassato
  bool _isNodeHiddenByCollapsedParent(GraphNode node) {
    String? currentParentId = node.parentId;
    while (currentParentId != null) {
      final pIndex = _nodes.indexWhere((n) => n.id == currentParentId);
      if (pIndex == -1) break;
      if (_nodes[pIndex].isCollapsed)
        return true; // Trovato un nonno/padre chiuso!
      currentParentId = _nodes[pIndex].parentId;
    }
    return false;
  }

  // ==========================================
  // NUOVO: LOGICA EXPLORER TOOL
  // ==========================================
  Set<String> get explorerActiveNodes {
    if (_activeTool != ToolType.explorer || _hoveredNodeId == null) return {};

    Set<String> group = {_hoveredNodeId!};
    for (var node in _nodes) {
      if (_isAncestor(_hoveredNodeId!, node.id)) {
        group.add(node.id);
      }
    }

    Set<String> active = Set.from(group);

    for (var edge in getAggregatedEdges()) {
      if (group.contains(edge.sourceId)) {
        active.add(edge.targetId);
      }
      if (group.contains(edge.targetId)) {
        active.add(edge.sourceId);
      }
    }
    for (var edge in _edges) {
      if (group.contains(edge.sourceId)) {
        active.add(edge.targetId);
      }
      if (group.contains(edge.targetId)) {
        active.add(edge.sourceId);
      }
    }
    return active;
  }

  Set<String> get explorerActiveEdges {
    if (_activeTool != ToolType.explorer || _hoveredNodeId == null) return {};

    Set<String> group = {_hoveredNodeId!};
    for (var node in _nodes) {
      if (_isAncestor(_hoveredNodeId!, node.id)) {
        group.add(node.id);
      }
    }

    Set<String> activeEdges = {};
    for (var edge in getAggregatedEdges()) {
      if (group.contains(edge.sourceId) || group.contains(edge.targetId)) {
        activeEdges.add(edge.id);
      }
    }
    for (var edge in _edges) {
      if (group.contains(edge.sourceId) || group.contains(edge.targetId)) {
        activeEdges.add(edge.id);
      }
    }
    return activeEdges;
  }
}
