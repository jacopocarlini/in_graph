import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../model/graph_models.dart';
import '../provider/graph_provider.dart';

class NodeWidget extends StatefulWidget {
  final GraphNode node;
  final bool isGhost;

  const NodeWidget({Key? key, required this.node, this.isGhost = false})
    : super(key: key);

  @override
  State<NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<NodeWidget> {
  bool _isDragging = false;
  bool _isResizing = false;
  late TextEditingController _nameController;
  final FocusNode _textFocusNode = FocusNode();

  final double _resizeHandleThickness = 8.0;

  bool _isHover = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.node.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  bool isSelected(GraphProvider provider) {
    return provider.selection.contains(widget.node.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GraphProvider>();
    final activeTool = widget.isGhost ? null : provider.activeTool;

    final isExpandedContainer =
        widget.node.isContainer && !widget.node.isCollapsed;
    final isCollapsedContainer =
        widget.node.isContainer && widget.node.isCollapsed;

    // Dimensioni del nodo
    final targetWidth = isCollapsedContainer
        ? GraphNode.defaultNodeSize.width
        : widget.node.size.width;
    final targetHeight = isCollapsedContainer
        ? GraphNode.defaultNodeSize.height
        : (widget.node.isContainer
              ? widget.node.size.height
              : widget.node.size.width);

    final bool showBottomLabel = !isExpandedContainer;
    final double textWidth = targetWidth * 1.5;
    final double textLeftOffset = (textWidth - targetWidth) / 2;

    Widget buildTextField({required bool isTopBar}) {
      return TextField(
        focusNode: _textFocusNode,
        controller: _nameController,
        textAlign: isTopBar ? TextAlign.left : TextAlign.center,
        maxLines: isTopBar ? 1 : null,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: isTopBar
              ? const EdgeInsets.only(bottom: 2)
              : const EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
          hintText: widget.node.isContainer ? 'New Container' : 'New Node',
        ),
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        onTap: () {
          provider.setIsTextEdit(true);
        },
        onChanged: (newValue) {
          provider.setIsTextEdit(true);
          provider.updateNameNode(widget.node.id, newValue);
        },
        onTapOutside: (e) {
          provider.setIsTextEdit(false);
        },
      );
    }

    Widget buildResizeHandle({
      required Alignment alignment,
      required SystemMouseCursor cursor,
      required Function(DragUpdateDetails) onResize,
    }) {
      return Positioned(
        top:
            alignment == Alignment.topCenter ||
                alignment == Alignment.topLeft ||
                alignment == Alignment.topRight
            ? 0
            : null,
        bottom:
            alignment == Alignment.bottomCenter ||
                alignment == Alignment.bottomLeft ||
                alignment == Alignment.bottomRight
            ? 0
            : null,
        left:
            alignment == Alignment.centerLeft ||
                alignment == Alignment.topLeft ||
                alignment == Alignment.bottomLeft
            ? 0
            : null,
        right:
            alignment == Alignment.centerRight ||
                alignment == Alignment.topRight ||
                alignment == Alignment.bottomRight
            ? 0
            : null,
        width:
            alignment == Alignment.topCenter ||
                alignment == Alignment.bottomCenter
            ? targetWidth
            : _resizeHandleThickness,
        height:
            alignment == Alignment.centerLeft ||
                alignment == Alignment.centerRight
            ? targetHeight
            : _resizeHandleThickness,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            setState(() => _isResizing = true);
            _textFocusNode.unfocus();
          },
          onPanUpdate: onResize,
          onPanEnd: (_) {
            setState(() => _isResizing = false);
            provider.resizeNode(widget.node.id, widget.node.size);
            provider.updateContainerChildren(widget.node.id);
          },
          onPanCancel: () => setState(() => _isResizing = false),
          child: MouseRegion(
            cursor: cursor,
            child: Container(color: Colors.transparent),
          ),
        ),
      );
    }

    return Positioned(
      left: widget.node.position.dx - (showBottomLabel ? textLeftOffset : 0),
      top: widget.node.position.dy,
      child: Opacity(
        opacity: widget.isGhost ? 0.5 : 1.0,
        child: IgnorePointer(
          ignoring: widget.isGhost,
          child: TapRegion(
            behavior: HitTestBehavior.translucent,
            onTapOutside: (pointerDownEvent) {
              // Se questo nodo è selezionato e l'utente clicca fuori con il tool pointer
              if (isSelected(provider)) {
                provider.setSelection([]);
                _textFocusNode.unfocus();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              // Centra il nodo rispetto alla label in basso
              children: [
                // 1. IL NODO VERO E PROPRIO (Box + Resize Handles)
                buildBox(
                  targetWidth,
                  targetHeight,
                  activeTool,
                  provider,
                  isExpandedContainer,
                  buildTextField,
                  buildResizeHandle,
                ),

                // 2. LABEL TESTUALE IN BASSO
                if (showBottomLabel) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: textWidth,
                    child: buildTextField(isTopBar: false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  SizedBox buildBox(
    double targetWidth,
    double targetHeight,
    ToolType? activeTool,
    GraphProvider provider,
    bool isExpandedContainer,
    buildTextField,
    buildResizeHandle,
  ) {
    return SizedBox(
      width: targetWidth,
      height: targetHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Box Principale
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (activeTool == ToolType.pointer || activeTool == ToolType.pan) {
                  provider.setSelection([widget.node.id]);
                  setState(() => _isDragging = true);
                }
              },
              onTapDown: (event) {
                if (activeTool == ToolType.pointer|| activeTool == ToolType.pan) {
                  provider.setSelection([widget.node.id]);
                  setState(() => _isDragging = true);
                }
              },
              onTapUp: (event) {
                if (activeTool == ToolType.pointer|| activeTool == ToolType.pan) {
                  setState(() => _isDragging = false);
                }
              },
              onPanStart: provider.activeTool != ToolType.pan
                  ? (details) {
                      if (_textFocusNode.hasFocus) return;
                      // --- NUOVA LOGICA: Se il tool è Edge, iniziamo a tracciare la linea
                      if (activeTool == ToolType.edge) {
                        provider.startEdge(widget.node.id);
                        return; // Fermiamo l'esecuzione, non vogliamo trascinare il nodo
                      }
                      setState(() => _isDragging = true);
                      provider.setSelection([widget.node.id]);
                    }
                  : null,
              onPanUpdate: provider.activeTool != ToolType.pan
                  ? (details) {
                      if (_isDragging) {
                        provider.moveNode(widget.node.id, details.delta);
                      }
                    }
                  : null,
              onPanEnd: provider.activeTool != ToolType.pan
                  ? (details) {
                      if (_isDragging) {
                        setState(() => _isDragging = false);
                        provider.handleNodeDrop(widget.node.id);
                      }
                    }
                  : null,
              onPanCancel: provider.activeTool != ToolType.pan
                  ? () {
                      if (_isDragging) {
                        setState(() => _isDragging = false);
                      }
                    }
                  : null,
              child: MouseRegion(
                cursor: getCursor(provider),
                onHover: (event) {
                  if (provider.activeTool == ToolType.edge) {
                    setState(() {
                      _isHover = true;
                    });
                  }
                },
                onExit: (event) {
                  if (provider.activeTool == ToolType.edge) {
                    setState(() {
                      _isHover = false;
                    });
                  }
                },
                onEnter: (event) {
                  if (provider.activeTool == ToolType.edge) {
                    setState(() {
                      _isHover = true;
                    });
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected(provider)
                          ? Colors.blue
                          : Colors.grey.shade300,
                      width: isSelected(provider) ? 2.0 : 1.0,
                    ),
                    boxShadow: _isHover && provider.activeTool == ToolType.edge
                        ? [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.5),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: Offset(
                                0,
                                3,
                              ), // changes position of shadow
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        if (!isExpandedContainer)
                          Center(
                            child: Icon(
                              widget.node.isContainer
                                  ? Icons.folder
                                  : Icons.widgets_rounded,
                              size: targetWidth * 0.5,
                              color: Colors.black54,
                            ),
                          ),

                        if (widget.node.isContainer)
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      provider.toggleCollapse(widget.node.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Icon(
                                      widget.node.isCollapsed
                                          ? Icons.unfold_more
                                          : Icons.unfold_less,
                                      size: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!widget.node.isCollapsed)
                                  const Icon(
                                    Icons.folder_open,
                                    size: 20,
                                    color: Colors.black54,
                                  ),
                                const SizedBox(width: 8),
                                if (isExpandedContainer)
                                  Expanded(
                                    child: buildTextField(isTopBar: true),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Copertura Resize sui Bordi
          // Copertura Resize sui Bordi (Corretta con details.delta / provider.zoomScale)
          if (isExpandedContainer && !widget.isGhost) ...[
            buildResizeHandle(
              alignment: Alignment.centerRight,
              cursor: SystemMouseCursors.resizeLeftRight,
              onResize: (details) {
                setState(() {
                  final deltaX =
                      details.delta.dx / provider.zoomScale; // <--- Corretto
                  widget.node.size = Size(
                    (widget.node.size.width + deltaX).clamp(150.0, 2000.0),
                    widget.node.size.height,
                  );
                });
              },
            ),
            buildResizeHandle(
              alignment: Alignment.bottomCenter,
              cursor: SystemMouseCursors.resizeUpDown,
              onResize: (details) {
                setState(() {
                  final deltaY =
                      details.delta.dy / provider.zoomScale; // <--- Corretto
                  widget.node.size = Size(
                    widget.node.size.width,
                    (widget.node.size.height + deltaY).clamp(100.0, 2000.0),
                  );
                });
              },
            ),
            buildResizeHandle(
              alignment: Alignment.centerLeft,
              cursor: SystemMouseCursors.resizeLeftRight,
              onResize: (details) {
                setState(() {
                  final deltaX =
                      details.delta.dx / provider.zoomScale; // <--- Corretto
                  final oldWidth = widget.node.size.width;
                  final newWidth = (oldWidth - deltaX).clamp(150.0, 2000.0);
                  final actualDeltaX = oldWidth - newWidth;

                  widget.node.size = Size(newWidth, widget.node.size.height);
                  widget.node.position = Offset(
                    widget.node.position.dx + actualDeltaX,
                    widget.node.position.dy,
                  );
                });
              },
            ),
            buildResizeHandle(
              alignment: Alignment.topCenter,
              cursor: SystemMouseCursors.resizeUpDown,
              onResize: (details) {
                setState(() {
                  final deltaY =
                      details.delta.dy / provider.zoomScale; // <--- Corretto
                  final oldHeight = widget.node.size.height;
                  final newHeight = (oldHeight - deltaY).clamp(100.0, 2000.0);
                  final actualDeltaY = oldHeight - newHeight;

                  widget.node.size = Size(widget.node.size.width, newHeight);
                  widget.node.position = Offset(
                    widget.node.position.dx,
                    widget.node.position.dy + actualDeltaY,
                  );
                });
              },
            ),
            buildResizeHandle(
              alignment: Alignment.bottomRight,
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              onResize: (details) {
                setState(() {
                  final deltaX =
                      details.delta.dx / provider.zoomScale; // <--- Corretto
                  final deltaY =
                      details.delta.dy / provider.zoomScale; // <--- Corretto
                  widget.node.size = Size(
                    (widget.node.size.width + deltaX).clamp(150.0, 2000.0),
                    (widget.node.size.height + deltaY).clamp(100.0, 2000.0),
                  );
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  SystemMouseCursor getCursor(GraphProvider provider) {
    if (provider.activeTool == ToolType.pan) {
      return SystemMouseCursors.grab;
    }
    if (provider.activeTool == ToolType.edge) {
      return SystemMouseCursors.precise;
    }
    if (provider.activeTool == ToolType.pointer) {
      return _isDragging
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.grab;
    }

    return SystemMouseCursors.basic;
  }
}
