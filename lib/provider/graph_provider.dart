import 'package:flutter/material.dart';
import '../model/graph_models.dart';

class TempEdge {
  final String sourceId;
  Offset currentPosition;

  TempEdge({required this.sourceId, required this.currentPosition});
}

class GraphProvider extends ChangeNotifier {
  final List<GraphNode> _nodes = [];
  final List<GraphEdge> _edges = [];

  ToolType _activeTool = ToolType.pointer;
  List<String> _selection = [];
  String? _activeHoverId;
  TempEdge? _tempEdge;
  Offset? _previewPosition;
  double? _zoomScale;
  bool _isTextEdit = false;

  bool get isTextEdit => _isTextEdit;

  List<GraphNode> get nodes => _nodes;

  int get zoomPercentage {
    double zoomScale = (_zoomScale ?? 1);
    double percentage = zoomScale * 100;
    return percentage.toInt();
  }

  double get zoomScale => _zoomScale ?? 1.0;

  List<GraphEdge> get edges => _edges;

  ToolType get activeTool => _activeTool;

  List<String> get selection => _selection;

  String? get activeHoverId => _activeHoverId;

  TempEdge? get tempEdge => _tempEdge;

  Offset? get previewPosition => _previewPosition;

  void setIsTextEdit(bool isTextEdit){
    _isTextEdit = isTextEdit;
  }

  // --- LOGICA DI AGGREGAZIONE FRECCE ---
  List<AggregatedEdge> getAggregatedEdges() {
    // Trova il nodo visibile più alto nella gerarchia (se il padre è collassato)
    String getVisibleEndpoint(String nodeId) {
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

    Map<String, AggregatedEdge> aggregatedMap = {};

    for (var edge in _edges) {
      final visibleSource = getVisibleEndpoint(edge.sourceId);
      final visibleTarget = getVisibleEndpoint(edge.targetId);

      // Se entrambi i capi della freccia finiscono in un container collassato, nascondiamo la freccia
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

  // --- METODI DELLE FRECCE (EDGES) ---
  void startTempEdge(String sourceId, Offset startPos) {
    _tempEdge = TempEdge(sourceId: sourceId, currentPosition: startPos);
    notifyListeners();
  }

  void updateTempEdge(Offset newPos) {
    if (_tempEdge != null) {
      _tempEdge!.currentPosition = newPos;
      notifyListeners();
    }
  }

  void clearTempEdge() {
    _tempEdge = null;
    notifyListeners();
  }

  void addEdge(String sourceId, String targetId) {
    // Evita loop su se stesso
    if (sourceId == targetId) return;
    // Evita duplicati esatti
    if (_edges.any((e) => e.sourceId == sourceId && e.targetId == targetId))
      return;

    _edges.add(
      GraphEdge(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourceId: sourceId,
        targetId: targetId,
      ),
    );
    notifyListeners();
  }

  // 3. Aggiungi il metodo per aggiornarla (o pulirla)
  void updatePreviewPosition(Offset? pos) {
    _previewPosition = pos;
    notifyListeners();
  }

  // 4. (Opzionale ma consigliato) Nel metodo setTool esistente, pulisci l'anteprima quando cambi strumento:
  void setTool(ToolType tool) {
    _activeTool = tool;
    _tempEdge = null;
    _previewPosition = null; // <-- Aggiungi questa riga
    notifyListeners();
  }

  /// Ritorna solo i nodi visibili (nasconde i figli dei container collassati)
  List<GraphNode> get visibleNodes {
    return _nodes.where((node) {
      String? currentParentId = node.parentId;
      while (currentParentId != null) {
        final parentIndex = _nodes.indexWhere((n) => n.id == currentParentId);
        if (parentIndex == -1) break;

        final parent = _nodes[parentIndex];
        if (parent.isCollapsed)
          return false; // Nascondi se un genitore è chiuso
        currentParentId = parent.parentId;
      }
      return true;
    }).toList();
  }

  /// Eseguito nell'onPanEnd: valuta se il nodo è stato rilasciato dentro un container
  void handleNodeDrop(String nodeId) {
    final nodeIndex = _nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex == -1) return;

    final node = _nodes[nodeIndex];
    // Usiamo l'helper per trovare il vero centro del nodo trascinato
    final nodeCenter = _getEffectiveRect(node).center;

    // Cerca i container validi la cui "Area Effettiva" contiene il nodo
    final validContainers = _nodes
        .where(
          (c) =>
              c.isContainer &&
              c.id != nodeId &&
              _getEffectiveRect(c).contains(nodeCenter), // <-- FIX QUI
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

  /// Ingloba i nodi quando si crea un nuovo container
  void autoAdoptNodes(GraphNode container) {
    final containerRect = _getEffectiveRect(container); // <-- FIX QUI

    for (var i = 0; i < _nodes.length; i++) {
      final child = _nodes[i];
      if (child.id == container.id || child.isContainer) continue;

      final childCenter = _getEffectiveRect(child).center; // <-- FIX QUI

      if (containerRect.contains(childCenter)) {
        _nodes[i] = child.copyWith(parentId: container.id);
      }
    }
    notifyListeners();
  }

  /// Inverte lo stato Aperto/Chiuso del container
  void toggleCollapse(String nodeId) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(
        isCollapsed: !_nodes[index].isCollapsed,
      );
      notifyListeners();
    }
  }

  /// Ridimensiona un nodo (usato per i container)
  void resizeNode(String id, Size newSize) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      // Impostiamo delle dimensioni minime per evitare che scompaia (es. 150x100)
      final width = newSize.width < 150 ? 150.0 : newSize.width;
      final height = newSize.height < 100 ? 100.0 : newSize.height;

      _nodes[index] = _nodes[index].copyWith(size: Size(width, height));
      notifyListeners();
    }
  }

  /// Scansiona i nodi e aggiorna i figli in base ai nuovi confini del container.
  /// Da chiamare alla fine di un resize o di un drop.
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

      // Se il centro del nodo è dentro il container, lo adottiamo
      if (containerRect.contains(childCenter)) {
        if (child.parentId != container.id) {
          _nodes[i] = child.copyWith(parentId: container.id);
        }
      } else {
        // Se era un figlio ma ora è fuori dai bordi (perché il container è stato rimpicciolito), lo espelliamo
        if (child.parentId == container.id) {
          _nodes[i] = child.copyWith(clearParent: true);
        }
      }
    }
    notifyListeners();
  }

  Rect _getEffectiveRect(GraphNode node) {
    // Se è un container chiuso, l'area di collisione si restringe al quadrato di default
    if (node.isContainer && node.isCollapsed) {
      return Rect.fromLTWH(
        node.position.dx,
        node.position.dy,
        GraphNode.defaultNodeSize.width,
        GraphNode.defaultNodeSize.height,
      );
    }
    // Altrimenti usa le sue dimensioni normali
    return Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.isContainer ? node.size.height : node.size.width,
    );
  }

  // --- DA INSERIRE IN GraphProvider ---

  /// Elimina i nodi selezionati e tutti i loro figli in modo ricorsivo
  void deleteSelectedNodes() {
    if (selection.isEmpty) return;

    // Sotto-funzione ricorsiva per raccogliere l'ID corrente e tutti i figli/nipoti
    void collectAllChildrenIds(String nodeId, Set<String> idsToDelete) {
      idsToDelete.add(nodeId);

      // Trova i figli diretti di questo nodo
      final children = _nodes
          .where((n) => n.parentId == nodeId)
          .map((n) => n.id)
          .toList();

      for (var childId in children) {
        collectAllChildrenIds(childId, idsToDelete); // Ricorsione
      }
    }

    // Insieme di tutti gli ID da cancellare (evita duplicati)
    final Set<String> allIdsToDelete = {};

    for (var selectedId in selection) {
      collectAllChildrenIds(selectedId, allIdsToDelete);
    }

    // 1. Rimuoviamo i nodi dalla lista principale
    _nodes.removeWhere((node) => allIdsToDelete.contains(node.id));

    // 2. OPZIONALE: Se hai una lista di archi (Edge), rimuoviamo anche i collegamenti interrotti
    // _edges.removeWhere((edge) => allIdsToDelete.contains(edge.sourceId) || allIdsToDelete.contains(edge.targetId));

    // 3. Svuotiamo la selezione corrente poiché i nodi non esistono più
    setSelection([]);

    notifyListeners();
  }

  // 2. STATO PER LA FRECCIA "IN CORSO" (Ghost Edge)
  String? _draftEdgeSourceId;
  Offset? _draftEdgeTarget;

  String? get draftEdgeSourceId => _draftEdgeSourceId;

  Offset? get draftEdgeTarget => _draftEdgeTarget;

  bool get isCreatingEdge => _draftEdgeSourceId != null;

  // -- METODI PER GESTIRE GLI EDGE --

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

  void finishEdge(Offset pointerPosition) {
    if (!isCreatingEdge) return;

    // Troviamo se il mouse è stato rilasciato sopra un nodo
    GraphNode? targetNode;
    // Iteriamo al contrario per prendere il nodo "più in alto" in caso di sovrapposizioni
    for (var node in _nodes.reversed) {
      final rect = Rect.fromLTWH(
        node.position.dx,
        node.position.dy,
        node.size.width,
        node.size.height,
      );
      if (rect.contains(pointerPosition)) {
        targetNode = node;
        break;
      }
    }

    // Se abbiamo trovato un nodo bersaglio valido (e non è lo stesso nodo di partenza)
    if (targetNode != null && targetNode.id != _draftEdgeSourceId) {
      final newEdge = GraphEdge(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourceId: _draftEdgeSourceId!,
        targetId: targetNode.id,
      );
      _edges.add(newEdge);
    }

    // Resettiamo lo stato
    _draftEdgeSourceId = null;
    _draftEdgeTarget = null;
    notifyListeners();
  }

  // 1. SELEZIONE LIVE DURANTE IL TRASCINAMENTO DEL RETTANGOLO
  void updateSelectionFromRect(Rect selectionRect) {
    List<String> newSelection = [];

    for (var node in _nodes) {
      // Calcoliamo la dimensione reale del nodo (tenendo conto se è un container collassato)
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

      // CRITERIO: Il nodo deve essere COMPLETAMENTE dentro il rettangolo di selezione
      if (selectionRect.left <= nodeRect.left &&
          selectionRect.right >= nodeRect.right &&
          selectionRect.top <= nodeRect.top &&
          selectionRect.bottom >= nodeRect.bottom) {
        newSelection.add(node.id);
      }
    }

    // Aggiorna la selezione solo se è cambiata, per evitare cicli di widget rebuild inutili
    if (_selection.toString() != newSelection.toString()) {
      _selection = newSelection;
      notifyListeners();
    }
  }

  // 2. TRASCINAMENTO DI GRUPPO AGGIORNATO
  void moveNode(String id, Offset delta) {
    // Se il nodo trascinato fa parte della selezione, muoviamo TUTTI i nodi selezionati
    if (_selection.contains(id)) {
      for (var node in _nodes) {
        if (_selection.contains(node.id)) {
          node.position += delta;
        }
      }
    } else {
      // Altrimenti muoviamo solo il singolo nodo (e opzionalmente svuotiamo la selezione)
      final node = _nodes.firstWhere((n) => n.id == id);
      node.position += delta;
    }
    notifyListeners();
  }

  // 3. ELIMINAZIONE DEGLI ELEMENTI SELEZIONATI
  void deleteSelected() {
    if (_selection.isEmpty) return;

    // Rimuove i nodi selezionati
    _nodes.removeWhere((node) => _selection.contains(node.id));

    // Rimuove tutti i collegamenti (edges) associati ai nodi eliminati
    // Nota: Assicurati che '_edges' sia il nome della tua lista di canali/frecce nel provider
    _edges.removeWhere(
      (edge) =>
          _selection.contains(edge.sourceId) ||
          _selection.contains(edge.targetId),
    );

    // Svuota la selezione
    _selection.clear();
    notifyListeners();
  }

  void setZoomScale(double zoomScale) {
    _zoomScale = zoomScale;
    notifyListeners();
  }
}
