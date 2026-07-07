import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../model/graph_models.dart';
import '../provider/graph_provider.dart';
import 'NodeWidget.dart';
import '../util/edge_painter.dart';
import 'PropertySidebar.dart';

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

  Offset? localPosition;

  int _zoom = 100;

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
    setState(() {
      final Matrix4 matrix = _transformController.value;
      final double scale = sqrt(
        matrix.entry(0, 0) * matrix.entry(0, 0) +
            matrix.entry(1, 0) * matrix.entry(1, 0),
      );
      double percentage = scale * 100;
      _zoom = percentage.toInt();
    });
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
    var activeTool = provider.activeTool;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Focus(
                    focusNode: _canvasFocusNode,
                    autofocus: true,
                    onKeyEvent: (node, event) {
                      return handleShortcut(node, event, provider);
                    }, // I tuoi shortcut
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      // panEnabled a true permette SEMPRE il pan tramite trackpad
                      panEnabled: true,
                      trackpadScrollCausesScale: false,
                      scaleEnabled: true,
                      minScale: 0.3,
                      maxScale: 3.0,
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(10000),
                      child: GestureDetector(
                        // Se non siamo in modalita 'pan', consumiamo l'evento di drag (mouse)
                        // così l'InteractiveViewer non sposta la telecamera col mouse.
                        // Gli eventi del trackpad invece bypassano la gesture arena e
                        // vengono comunque gestiti dall'InteractiveViewer!
                        onPanDown: provider.canPanCanvas ? null : (_) {},
                        onPanUpdate: provider.canPanCanvas ? null : (_) {},
                        child: Listener(
                          // IL CUORE DELL'INPUT CENTRALIZZATO
                          onPointerDown: (event) {
                            if (!_canvasFocusNode.hasFocus) {
                              _canvasFocusNode.requestFocus();
                            }
                            provider.handlePointerDown(event.localPosition);
                          },
                          onPointerMove: (event) => provider.handlePointerMove(
                            event.localPosition,
                            event.localDelta,
                          ),
                          onPointerUp: (event) {
                            var message = provider.handlePointerUp(event.localPosition);
                            if (message){
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('The edge already exists'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          onPointerHover: (event) =>
                              provider.updateCurrentPosition(event.localPosition),
                          child: MouseRegion(
                            cursor: buildCursor(provider),
                            child: RepaintBoundary(
                              key: provider.canvasBoundaryKey,
                              child: SizedBox(
                                width: 10000,
                                height: 10000,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Selector<GraphProvider, List<GraphNode>>(
                                      selector: (_, p) => p.visibleNodes,
                                      shouldRebuild: (prev, next) {
                                        if (prev.length != next.length) {
                                          return true;
                                        }
                                        for (int i = 0; i < prev.length; i++) {
                                          if (prev[i] != next[i]) return true;
                                        }
                                        return false;
                                      },
                                      builder: (context, visibleNodes, _) {
                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: visibleNodes.map((node) {
                                            return NodeWidget(
                                              key: ValueKey(node.id),
                                              node: node,
                                              onTapOut: () {
                                                _canvasFocusNode.requestFocus();
                                              },
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter:
                                              EdgePainter(provider: provider),
                                        ),
                                      ),
                                    ),
                                    if (provider.currentPosition != null &&
                                        (provider.activeTool == ToolType.node ||
                                            activeTool == ToolType.container))
                                      (() {
                                        return buildGhost(activeTool, provider);
                                      })(),
                                    Selector<GraphProvider,
                                        ({Offset? start, Offset? current})>(
                                      selector: (_, p) => (
                                        start: p.startPosition,
                                        current: p.currentPosition
                                      ),
                                      builder: (context, data, _) {
                                        if (data.start != null &&
                                            data.current != null) {
                                          return buildRectSelection(
                                            data.start!,
                                            data.current!,
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                buildZoomChip(provider),
              ],
            ),
          ),
          const PropertySidebar(),
        ],
      ),
    );
  }

  SystemMouseCursor buildCursor(GraphProvider provider) {
    if (provider.interactionMode == InteractionMode.panning) {
      return SystemMouseCursors.grabbing;
    }
    if (provider.activeTool == ToolType.edge) {
      return SystemMouseCursors.precise;
    }
    if (provider.activeTool == ToolType.explorer) {
      return SystemMouseCursors.help;
    }
    return provider.activeTool == ToolType.pan
        ? SystemMouseCursors.grab
        : SystemMouseCursors.basic;
  }

  KeyEventResult handleShortcut(node, event, GraphProvider provider) {
    if (provider.isTextEdit) return KeyEventResult.ignored;

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
      }
      if (event.character == '4') {
        provider.setTool(ToolType.container);
      }
      if (event.character == '5') {
        provider.setTool(ToolType.edge);
        provider.clearSelection();
      }
      if (event.character == '6') {
        provider.setTool(ToolType.explorer);
        provider.clearSelection();
      }
    }
    return KeyEventResult.ignored;
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
                    "${_zoom}%",
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

  NodeWidget buildGhost(ToolType activeTool, GraphProvider provider) {
    final isContainer = activeTool == ToolType.container;
    Size previewSize = isContainer
        ? GraphNode.defaultContainerSize
        : GraphNode.defaultNodeSize;

    return NodeWidget(
      isGhost: true,
      onTapOut: () {},
      node: GraphNode(
        id: 'temp_ghost',
        name: '',
        size: previewSize,
        isContainer: isContainer,
        position: Offset(
          provider.currentPosition!.dx - previewSize.width / 2,
          provider.currentPosition!.dy - previewSize.height / 2,
        ),
      ),
    );
  }

  Positioned buildRectSelection(Offset start, Offset current) {
    return Positioned.fromRect(
      rect: Rect.fromPoints(start, current),
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
