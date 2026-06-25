import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../model/graph_models.dart';
import '../provider/graph_provider.dart';

class NodeWidget extends StatefulWidget {
  final GraphNode node;
  final bool isGhost;
  final Function onTapOut;

  const NodeWidget({Key? key, required this.node, this.isGhost = false, required this.onTapOut})
    : super(key: key);

  @override
  State<NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<NodeWidget> {
  late TextEditingController _nameController;
  final FocusNode _textFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.node.name);
  }

  @override
  void didUpdateWidget(covariant NodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.name != widget.node.name &&
        _nameController.text != widget.node.name) {
      _nameController.text = widget.node.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var node = widget.node;
    final provider = context.watch<GraphProvider>();
    final isSelected = provider.selection.contains(node.id);
    final isHovered = provider.hoveredNodeId == node.id && provider.activeTool == ToolType.edge;

    final targetWidth = node.size.width;
    final targetHeight = node.size.height;

    final showTextBelow = !node.isContainer || node.isCollapsed;

    // Determina se mostrare le maniglie di ridimensionamento
    final showResizeHandles =
        isSelected && node.isContainer && !node.isCollapsed;

    return Stack(
      clipBehavior: Clip.none, // Fondamentale per far "sbordare" le maniglie
      children: [
        Positioned(
          left: node.position.dx,
          top: node.position.dy,
          child: Opacity(
            opacity: widget.isGhost ? 0.5 : 1.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                  // Il Box del Nodo/Container
                  Container(
                    width: targetWidth,
                    height: targetHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: node.borderStyle == BorderStyleType.solid
                          ? Border.all(
                              color: node.color,
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: node.borderStyle == BorderStyleType.dashed
                        ? CustomPaint(
                            painter: DashedBorderPainter(
                              color: node.color,
                              strokeWidth: 1.5,
                              borderRadius: 16,
                            ),
                            child: buildNode(node, provider),
                          )
                        : buildNode(node, provider),
                  ),

                  // Rettangolo di selezione esterno (Blue Glow/Border)
                  if (isSelected || isHovered)
                    Positioned(
                      left: -3,
                      top: -3,
                      right: -3,
                      bottom: -3,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.6),
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(19),
                          ),
                        ),
                      ),
                    ),

                  // ==========================================
                  // NUOVO: Maniglie e Cursori di Resize
                  // ==========================================
                  if (showResizeHandles &&
                      provider.activeTool == ToolType.pointer)
                    Positioned.fill(
                      // Chiamiamo il nuovo metodo
                      child: _buildContinuousResizeHandles(
                        targetWidth,
                        targetHeight,
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Testo in basso
        if (showTextBelow) ...[
          Positioned(
            left: node.position.dx - 30,
            top: node.position.dy + targetHeight + 4,
            child: SizedBox(
              width: targetWidth + 60,
              child: _buildTextField(provider),
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // METODI HELPER DA AGGIUNGERE ALLA CLASSE
  // ==========================================

  Widget _buildContinuousResizeHandles(double w, double h) {
    // Spessore dell'area sensibile invisibile lungo il bordo
    const double thickness = 20.0;
    const double halfThickness = thickness / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ------------------------------------------
        // 1. LE BARRE DEI BORDI (Lati)
        // ------------------------------------------

        // Bordo Ovest (Left)
        _buildEdgeBar(
          left: -halfThickness,
          top: halfThickness,
          // Inset di metà spessore per non sovrapporsi agli angoli
          width: thickness,
          height: h - thickness,
          cursor: SystemMouseCursors.resizeLeftRight,
        ),
        // Bordo Est (Right)
        _buildEdgeBar(
          left: w - halfThickness,
          top: halfThickness,
          width: thickness,
          height: h - thickness,
          cursor: SystemMouseCursors.resizeLeftRight,
        ),
        // Bordo Nord (Top)
        _buildEdgeBar(
          left: halfThickness,
          top: -halfThickness,
          width: w - thickness,
          height: thickness,
          cursor: SystemMouseCursors.resizeUpDown,
        ),
        // Bordo Sud (Bottom)
        _buildEdgeBar(
          left: halfThickness,
          top: h - halfThickness,
          width: w - thickness,
          height: thickness,
          cursor: SystemMouseCursors.resizeUpDown,
        ),

        // ------------------------------------------
        // 2. GLI ANGOLI (Sopra le barre)
        // Manteniamo dei quadrati specifici negli angoli per mostrare
        // i cursori diagonali corretti.
        // ------------------------------------------

        // Top-Left
        _buildCornerHandle(
          -halfThickness,
          -halfThickness,
          thickness,
          SystemMouseCursors.resizeUpLeftDownRight,
        ),
        // Top-Right
        _buildCornerHandle(
          w - halfThickness,
          -halfThickness,
          thickness,
          SystemMouseCursors.resizeUpRightDownLeft,
        ),
        // Bottom-Left
        _buildCornerHandle(
          -halfThickness,
          h - halfThickness,
          thickness,
          SystemMouseCursors.resizeUpRightDownLeft,
        ),
        // Bottom-Right
        _buildCornerHandle(
          w - halfThickness,
          h - halfThickness,
          thickness,
          SystemMouseCursors.resizeUpLeftDownRight,
        ),
      ],
    );
  }

  // Helper per creare una barra perimetrale
  Widget _buildEdgeBar({
    required double left,
    required double top,
    required double width,
    required double height,
    required SystemMouseCursor cursor,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor: cursor,
        child: Container(
          width: width,
          height: height,
          color: Colors.transparent, // Invisibile ma capta il mouse
        ),
      ),
    );
  }

  // Helper per creare l'angolo sensibile (uguale a prima ma trasparente)
  Widget _buildCornerHandle(
    double left,
    double top,
    double size,
    SystemMouseCursor cursor,
  ) {
    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor: cursor,
        child: Container(width: size, height: size, color: Colors.transparent),
      ),
    );
  }

  Widget buildExpanded(GraphNode node, GraphProvider provider) {
    final targetWidth = node.isCollapsed
        ? GraphNode.defaultNodeSize.width
        : node.size.width;

    return Stack(
      children: [
        Positioned(
          top: 4,
          left: 4,
          // RIMOSSO "right: 4": ora lasciamo la Row libera di stringersi sul contenuto
          child: Row(
            mainAxisSize: MainAxisSize.min,
            // Costringe la Row a stringersi al minimo
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  provider.toggleCollapse(node.id);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    node.isCollapsed ? Icons.unfold_more : Icons.unfold_less,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              Icon(
                node.icon ?? (node.isContainer ? Icons.folder : Icons.widgets),
                size: 20,
                color: node.color,
              ),

              const SizedBox(width: 8),

              // FIX: IntrinsicWidth stringe il TextField attorno al suo testo
              IntrinsicWidth(
                child: ConstrainedBox(
                  // Consiglio: metti dei limiti (constraints) di sicurezza
                  constraints: BoxConstraints(
                    minWidth: 60,
                    // Evita che il TextField diventi invisibile se cancelli tutto il testo
                    maxWidth:
                        targetWidth -
                        60, // Evita che uscendo dal box rompa il layout
                  ),
                  child: _buildTextField(provider),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildNode(GraphNode node, GraphProvider provider) {
    if (node.isContainer && !node.isCollapsed) {
      return buildExpanded(node, provider);
    } else {
      return buildCollapse(node, provider);
    }
  }

  Stack buildCollapse(GraphNode node, GraphProvider provider) {
    return Stack(
      children: [
        // Icona principale al centro del box
        Center(
          child: Icon(
            node.icon ?? (node.isContainer ? Icons.folder : Icons.widgets),
            size: 32,
            color: node.color,
          ),
        ),
        if (node.isContainer)
          Positioned(
            top: 4,
            left: 4,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // Assicurati di avere questo metodo nel tuo provider per gestire il collapse
                    provider.toggleCollapse(node.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      node.isCollapsed ? Icons.unfold_more : Icons.unfold_less,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(GraphProvider provider) {
    var containerCollapsed =
        widget.node.isContainer && !widget.node.isCollapsed;
    return TextField(
      controller: _nameController,
      onTap: () => provider.setIsTextEdit(true),
      onTapOutside: (_) {
        provider.setIsTextEdit(false);
        _textFocusNode.unfocus();
        FocusScope.of(context).unfocus();
        widget.onTapOut();
      },
      onEditingComplete: () {
        _textFocusNode.unfocus();
      },
      onSubmitted: (_) {
        _textFocusNode.unfocus();
      },
      onChanged: (val) => provider.updateNameNode(widget.node.id, val),
      focusNode: _textFocusNode,
      textAlign: containerCollapsed ? TextAlign.left : TextAlign.center,
      maxLines: null,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: widget.node.isContainer ? 'Container' : 'Node',
        // FIX: Hint text in grigio chiaro
        hintStyle: TextStyle(
          color: Colors.grey.shade400, // Colore grigio chiaro per l'hint
          fontWeight: FontWeight.normal,
        ),
      ),
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.borderRadius = 0,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);

    final Path dashedPath = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
