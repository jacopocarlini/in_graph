import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../model/graph_models.dart';
import '../provider/graph_provider.dart';
import 'NodeWidget.dart';
import '../util/edge_painter.dart';

class GraphCanvas extends StatefulWidget {
  const GraphCanvas({super.key});

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<GraphCanvas>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  final FocusNode _canvasFocusNode = FocusNode();
  AnimationController? _animationController;

  Offset? _selectionStart;
  Offset? _selectionCurrent;
  bool _isDragging = false;
  Offset? localPosition;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_handleTransformChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Aspetta che il layout sia costruito, poi sposta la telecamera al centro dei 10000x10000
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      final centerX = -(10000.0 / 2) + (size.width / 2);
      final centerY = -(10000.0 / 2) + (size.height / 2);

      _transformController.value = Matrix4.identity()
        ..translate(centerX, centerY);
    });
  }

  void _handleTransformChanged() {
    setState(() {});
  }

  void _handleZoom(bool zoomIn) {
    final Matrix4 matrix = _transformController.value;

    final double currentScale = sqrt(
      matrix.entry(0, 0) * matrix.entry(0, 0) +
          matrix.entry(1, 0) * matrix.entry(1, 0),
    );

    // 1. Calcoliamo il nuovo target e il delta
    double targetScale = zoomIn ? currentScale * 1.2 : currentScale * 0.8;
    targetScale = targetScale.clamp(0.3, 3.0);
    if (targetScale == currentScale) return;

    final double scaleChange = targetScale / currentScale;

    // 2. Troviamo il centro dello schermo (pivot)
    final Size size = MediaQuery.of(context).size;
    final double pivotX = size.width / 2;
    final double pivotY = size.height / 2;

    // 3. Costruiamo la matrice di zoom attorno al pivot
    // Questo equivale a: sposta il centro a 0,0 -> scala -> riporta il centro dov'era
    final Matrix4 zoomMatrix = Matrix4.identity()
      ..translate(pivotX, pivotY)
      ..scale(scaleChange, scaleChange, 1.0)
      ..translate(-pivotX, -pivotY);

    // 4. Moltiplichiamo la matrice di zoom PER la matrice attuale (pre-moltiplicazione)
    _transformController.value = zoomMatrix * matrix;

    // 5. Aggiorniamo il provider
    context.read<GraphProvider>().setZoomScale(targetScale);
  }

  @override
  void dispose() {
    _transformController.removeListener(_handleTransformChanged);
    _transformController.dispose();
    _canvasFocusNode.dispose();
    _animationController
        ?.dispose(); // <-- Ricordati di fare il dispose del controller dell'animazione
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GraphProvider>();
    final activeTool = provider.activeTool;

    return Scaffold(
      body: Stack(
        children: [
          // 1. IL CANVAS (Il tuo codice originale dentro Focus)
          buildMouseHandler(provider, activeTool),

          // 2. I PULSANTI DI ZOOM
          buildZoomChip(provider),
        ],
      ),
    );
  }

  Focus buildMouseHandler(GraphProvider provider, ToolType activeTool) {
    final bool canUseGestures = provider.activeTool != ToolType.pan;

    var gestureDetector = GestureDetector(
      // FONDAMENTALE: cattura i click e i drag anche sullo spazio "vuoto" e trasparente del canvas
      // impedendo all'InteractiveViewer sottostante di reagire al drag del mouse.
      behavior: HitTestBehavior.opaque,

      onPanStart: (details) {
        if (activeTool == ToolType.edge) return;
        if (activeTool == ToolType.pointer) {
          _canvasFocusNode.requestFocus();
          setState(() {
            _selectionStart = details.localPosition;
            _selectionCurrent = _selectionStart;
          });
        }
      },
      onPanUpdate: (details) {
        if (activeTool == ToolType.edge) return;
        if (activeTool == ToolType.pointer && _selectionStart != null) {
          setState(() {
            _selectionCurrent = details.localPosition;
          });
          final rect = Rect.fromPoints(
            _selectionStart!,
            _selectionCurrent!,
          );
          provider.updateSelectionFromRect(rect);
        }
      },
      onPanEnd: (details) {
        if (activeTool == ToolType.pointer) {
          setState(() {
            _selectionStart = null;
            _selectionCurrent = null;
          });
        }
      },
      onTapUp: (details) {
        _canvasFocusNode.requestFocus();

        if (activeTool == ToolType.pointer) {
          provider.trySelectEdgeAt(details.localPosition);
        }
        if (activeTool == ToolType.node || activeTool == ToolType.container) {
          final isContainer = activeTool == ToolType.container;
          final nodeSize = isContainer
              ? GraphNode.defaultContainerSize
              : GraphNode.defaultNodeSize;

          final centeredPosition = Offset(
            details.localPosition.dx - nodeSize.width / 2,
            details.localPosition.dy - nodeSize.height / 2,
          );

          var node2Add = GraphNode(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: isContainer ? 'New Container' : 'New Node',
            position: centeredPosition,
            size: nodeSize,
            oldSize: isContainer ? nodeSize : null,
            isContainer: isContainer,
          );

          provider.addNode(node2Add);
          if (isContainer) {
            provider.autoAdoptNodes(node2Add);
          }
          provider.setTool(ToolType.pointer);
          provider.setSelection([node2Add.id]);
        }
      },
      child: buildCanvas(provider, activeTool),
    );

    var mouseRegion = MouseRegion(
      cursor: getCursor(provider),
      onExit: (_) {
        provider.updatePreviewPosition(null);
      },
      // Se il tool è PAN, bypassiamo il GestureDetector: i gesti del mouse
      // arriveranno dritti all'InteractiveViewer permettendogli di muovere il canvas.
      child: canUseGestures ? gestureDetector : buildCanvas(provider, activeTool),
    );

    var listener = Listener(
      onPointerMove: (event) {
        if (provider.isCreatingEdge) {
          provider.updateDraftEdge(event.localPosition);
        }
      },
      onPointerDown: (event) {
        setState(() {
          _isDragging = true;
        });
      },
      onPointerUp: (event) {
        if (provider.isCreatingEdge) {
          provider.finishEdge(event.localPosition);
        }
        setState(() {
          _isDragging = false;
        });
      },
      onPointerHover: (event) {
        setState(() {
          localPosition = event.localPosition;
        });
        if (activeTool == ToolType.node || activeTool == ToolType.container) {
          provider.updatePreviewPosition(event.localPosition);
        } else if (provider.previewPosition != null) {
          provider.updatePreviewPosition(null);
        }
      },
      child: mouseRegion,
    );

    return Focus(
      focusNode: _canvasFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            provider.setTool(ToolType.pointer);
          }
        }
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            provider.setTool(ToolType.pan);
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            provider.setTool(ToolType.pointer);
          }
          if ((event.logicalKey == LogicalKeyboardKey.backspace ||
              event.logicalKey == LogicalKeyboardKey.delete) &&
              !provider.isTextEdit) {
            provider.deleteSelected();
            return KeyEventResult.handled;
          }
          if (event.character == '1') {
            provider.setTool(ToolType.pointer);
          }
          if (event.character == '2') {
            provider.setTool(ToolType.pan);
          }
          if (event.character == '3') {
            provider.setTool(ToolType.node);
            provider.updatePreviewPosition(localPosition);
          }
          if (event.character == '4') {
            provider.setTool(ToolType.container);
            provider.updatePreviewPosition(localPosition);
          }
          if (event.character == '5') {
            provider.setTool(ToolType.edge);
            provider.setSelection([]);
          }
        }
        return KeyEventResult.ignored;
      },
      child: InteractiveViewer(
        transformationController: _transformController,
        panEnabled: true,
        scaleEnabled: true,
        minScale: 0.3,
        maxScale: 3.0,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        onInteractionEnd: (scaleData) {
          provider.setZoomScale(
            _transformController.value.getMaxScaleOnAxis(),
          );
        },
        child: listener,
      ),
    );
  }
  SystemMouseCursor getCursor(GraphProvider provider) {
    if (provider.activeTool == ToolType.edge) {
      return SystemMouseCursors.precise;
    }
    if (provider.activeTool == ToolType.pan) {
      return _isDragging
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.grab;
    }

    return SystemMouseCursors.basic;
  }

  Positioned buildZoomChip(GraphProvider provider) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Center(
        child: Card(
          elevation: 4,
          color: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => _handleZoom(false),
                  tooltip: "Zoom Out",
                ),
                // Indicatore percentuale attuale
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "${provider.zoomPercentage}%",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _handleZoom(true),
                  tooltip: "Zoom In",
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.center_focus_strong),
                  iconSize: 20,
                  onPressed: () {
                    _animationController?.stop();

                    // Ricalcoliamo il centro del canvas 10000x10000
                    final size = MediaQuery.of(context).size;
                    final centerX = -(10000.0 / 2) + (size.width / 2);
                    final centerY = -(10000.0 / 2) + (size.height / 2);

                    _transformController.value = Matrix4.identity()
                      ..translate(centerX, centerY);
                    provider.setZoomScale(1.0);
                  },
                  tooltip: "Reset Zoom",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SizedBox buildCanvas(GraphProvider provider, ToolType activeTool) {
    return SizedBox(
      width: 10000,
      height: 10000,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. PRIMA disegniamo i nodi (staranno sotto)
          ...buildNodes(provider),

          // 2. DOPO disegniamo le frecce (staranno SOPRA ai nodi)
          Positioned.fill(
            // Importante: IgnorePointer assicura che le frecce visivamente
            // in primo piano non blocchino i tap sui nodi sottostanti
            child: IgnorePointer(
              child: CustomPaint(painter: EdgePainter(provider: provider)),
            ),
          ),

          // 3. Ghost preview e Selezione rettangolare (primissimo piano)
          if (provider.previewPosition != null &&
              (activeTool == ToolType.node || activeTool == ToolType.container))
            (() {
              return buildGhost(activeTool, provider);
            })(),
          if (_selectionStart != null && _selectionCurrent != null)
            buildRectSelection(),
        ],
      ),
    );
  }

  List<NodeWidget> buildNodes(GraphProvider provider) {
    var nodesToRender = List<GraphNode>.from(provider.visibleNodes);

    int getDepth(GraphNode node) {
      int depth = 0;
      String? currentParentId = node.parentId;
      while (currentParentId != null) {
        depth++;
        final parentIndex = provider.nodes.indexWhere(
          (n) => n.id == currentParentId,
        );
        if (parentIndex == -1) break;
        currentParentId = provider.nodes[parentIndex].parentId;
      }
      return depth;
    }

    nodesToRender.sort((a, b) {
      final depthA = getDepth(a);
      final depthB = getDepth(b);

      // 1. Ordina per profondità (i parent sotto, i figli sopra)
      if (depthA != depthB) return depthA.compareTo(depthB);

      // 2. A parità di profondità, i container stanno sotto ai nodi normali
      if (a.isContainer && !b.isContainer) return -1;
      if (!a.isContainer && b.isContainer) return 1;

      // 3. NUOVO: A parità di tutto il resto, chi sta più in fondo nella
      // lista del provider (perché appena cliccato/mosso) viene disegnato sopra.
      final indexA = provider.nodes.indexWhere((n) => n.id == a.id);
      final indexB = provider.nodes.indexWhere((n) => n.id == b.id);
      return indexA.compareTo(indexB);
    });

    return nodesToRender.map((node) {
      return NodeWidget(key: ValueKey(node.id), node: node);
    }).toList();
  }

  NodeWidget buildGhost(ToolType activeTool, GraphProvider provider) {
    final isContainer = activeTool == ToolType.container;
    final previewSize = isContainer
        ? GraphNode.defaultContainerSize
        : GraphNode.defaultNodeSize;
    return NodeWidget(
      isGhost: true,
      node: GraphNode(
        id: 'temp_ghost',
        name: '',
        size: previewSize,
        isContainer: isContainer,
        position: Offset(
          provider.previewPosition!.dx - previewSize.width / 2,
          provider.previewPosition!.dy - previewSize.height / 2,
        ),
      ),
    );
  }

  Positioned buildRectSelection() {
    return Positioned.fromRect(
      rect: Rect.fromPoints(_selectionStart!, _selectionCurrent!),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          border: Border.all(
            color: Colors.blue,
            width: 1.0 / _transformController.value.getMaxScaleOnAxis(),
          ),
        ),
      ),
    );
  }
}
