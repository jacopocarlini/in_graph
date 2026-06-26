import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/graph_models.dart';
import '../provider/graph_provider.dart';

class PropertySidebar extends StatefulWidget {
  const PropertySidebar({Key? key}) : super(key: key);

  @override
  State<PropertySidebar> createState() => _PropertySidebarState();
}

class _PropertySidebarState extends State<PropertySidebar> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GraphProvider>();
    final selection = provider.selection;
    final selectedEdgeIds = provider.selectedEdgeIds;

    if (selection.isEmpty && selectedEdgeIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final isEdge = selectedEdgeIds.isNotEmpty;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: isEdge
          ? _buildEdgeSidebar(provider, selectedEdgeIds.first)
          : _buildNodeSidebar(provider, selection.first),
    );
  }

  Widget _buildNodeSidebar(GraphProvider provider, String nodeId) {
    final node = provider.nodes.firstWhere((n) => n.id == nodeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            node.name.isEmpty
                ? (node.isContainer ? "Container" : "Node")
                : node.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle("Icon"),
              const SizedBox(height: 8),
              _buildIconSelector(node, provider),
              const SizedBox(height: 24),
              _buildSectionTitle("Style"),
              const SizedBox(height: 16),
              _buildNodeColorSelector(node, provider),
              const SizedBox(height: 16),
              _buildNodeBorderSelector(node, provider),
              const SizedBox(height: 24),
              _buildSectionTitle("Layering"),
              const SizedBox(height: 8),
              _buildLayeringList(provider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEdgeSidebar(GraphProvider provider, String edgeId) {
    final aggregatedEdges = provider.getAggregatedEdges();
    final GraphEdge edge = aggregatedEdges.cast<GraphEdge>().firstWhere(
      (e) => e.id == edgeId,
      orElse: () => provider.edges.firstWhere((e) => e.id == edgeId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Arrow Options",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle("Style"),
              const SizedBox(height: 16),
              _buildEdgeColorSelector(edge, provider),
              const SizedBox(height: 16),
              _buildEdgeBorderSelector(edge, provider),
              const SizedBox(height: 24),
              _buildSectionTitle("Arrowheads"),
              const SizedBox(height: 16),
              _buildArrowheadsSelector(edge, provider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        fontSize: 14,
      ),
    );
  }

  Widget _buildIconSelector(GraphNode node, GraphProvider provider) {
    final icons = {
      "Default": node.isContainer ? Icons.folder : Icons.widgets,
      "Function": Icons.flash_on,
      "Database": Icons.storage,
      "Cloud": Icons.cloud,
      "User": Icons.person,
      "Settings": Icons.settings,
    };

    final currentIcon = node.icon;
    final bool iconExists = icons.values.contains(currentIcon);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<IconData?>(
          value: iconExists ? currentIcon : icons.values.first,
          isExpanded: true,
          items: icons.entries.map((e) {
            return DropdownMenuItem<IconData?>(
              value: e.value,
              child: Row(
                children: [
                  Icon(e.value, size: 20, color: Colors.blue),
                  const SizedBox(width: 12),
                  Text(e.key),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            provider.updateNodeIcon(node.id, val);
          },
        ),
      ),
    );
  }

  Widget _buildNodeColorSelector(GraphNode node, GraphProvider provider) {
    final colors = [
      Colors.grey,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
    ];
    return Row(
      children: [
        const Text(
          "Color",
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const Spacer(),
        ...colors.map((color) {
          final isSelected = node.color.value == color.value;
          return GestureDetector(
            onTap: () => provider.updateNodeColor(node.id, color),
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 12, color: Colors.white),
                    )
                  : null,
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildEdgeColorSelector(GraphEdge edge, GraphProvider provider) {
    final colors = [
      Colors.blueGrey,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
    ];
    return Row(
      children: [
        const Text(
          "Color",
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const Spacer(),
        ...colors.map((color) {
          final isSelected = edge.color.value == color.value;
          return GestureDetector(
            onTap: () => provider.updateEdgeColor(edge.id, color),
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 12, color: Colors.white),
                    )
                  : null,
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildNodeBorderSelector(GraphNode node, GraphProvider provider) {
    return Row(
      children: [
        const Text(
          "Border",
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const Spacer(),
        _buildToggleOption(
          "Solid",
          Icons.maximize,
          node.borderStyle == BorderStyleType.solid,
          () => provider.updateNodeBorderStyle(node.id, BorderStyleType.solid),
        ),
        const SizedBox(width: 8),
        _buildToggleOption(
          "Dashed",
          Icons.more_horiz,
          node.borderStyle == BorderStyleType.dashed,
          () => provider.updateNodeBorderStyle(node.id, BorderStyleType.dashed),
        ),
      ],
    );
  }

  Widget _buildEdgeBorderSelector(GraphEdge edge, GraphProvider provider) {
    return Row(
      children: [
        const Text(
          "Style",
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const Spacer(),
        _buildToggleOption(
          "Solid",
          Icons.maximize,
          edge.borderStyle == BorderStyleType.solid,
          () => provider.updateEdgeBorderStyle(edge.id, BorderStyleType.solid),
        ),
        const SizedBox(width: 8),
        _buildToggleOption(
          "Dashed",
          Icons.more_horiz,
          edge.borderStyle == BorderStyleType.dashed,
          () => provider.updateEdgeBorderStyle(edge.id, BorderStyleType.dashed),
        ),
      ],
    );
  }

  Widget _buildArrowheadsSelector(GraphEdge edge, GraphProvider provider) {
    return Row(
      children: [
        const Text(
          "Heads",
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const Spacer(),
        _buildToggleOption(
          "Source",
          Icons.west,
          edge.showSourceArrow,
          () => provider.updateEdgeArrows(
            edge.id,
            showSource: !edge.showSourceArrow,
            showTarget: edge.showTargetArrow,
          ),
        ),
        const SizedBox(width: 8),
        _buildToggleOption(
          "Target",
          Icons.east,
          edge.showTargetArrow,
          () => provider.updateEdgeArrows(
            edge.id,
            showSource: edge.showSourceArrow,
            showTarget: !edge.showTargetArrow,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleOption(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey.shade50,
          border: Border.all(
            color: isSelected
                ? Colors.blue.withOpacity(0.5)
                : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.blue : Colors.black54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.blue : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayeringList(GraphProvider provider) {
    final selection = provider.selection;
    if (selection.isEmpty) return const SizedBox.shrink();

    // 1. Identifichiamo tutti i nodi "parenti" (antenati e discendenti) dei selezionati
    final Set<String> relatedIds = {};

    void collectHierarchy(String nodeId) {
      if (relatedIds.contains(nodeId)) return;
      relatedIds.add(nodeId);

      // Risaliamo verso l'alto (Padri/Antenati)
      final node = provider.nodes.cast<GraphNode?>().firstWhere(
        (n) => n?.id == nodeId,
        orElse: () => null,
      );
      if (node?.parentId != null) {
        collectHierarchy(node!.parentId!);
      }

      // Scendiamo verso il basso (Figli/Discendenti)
      for (var n in provider.nodes) {
        if (n.parentId == nodeId) {
          collectHierarchy(n.id);
        }
      }
    }

    for (var id in selection) {
      collectHierarchy(id);
    }

    // 2. Filtriamo la lista dei nodi del provider mantenendo l'ordine di Z-Index (dal primo piano allo sfondo)
    final filteredNodes = provider.nodes.reversed
        .where((n) => relatedIds.contains(n.id))
        .toList();

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false, // Disabilitiamo le maniglie di default
      itemCount: filteredNodes.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) newIndex -= 1;

        final nodeToMove = filteredNodes[oldIndex];
        final targetNode = filteredNodes[newIndex];

        final List<GraphNode> allNodesReversed = provider.nodes.reversed
            .toList();
        final int visualOldIndex = allNodesReversed.indexOf(nodeToMove);
        final int visualNewIndex = allNodesReversed.indexOf(targetNode);

        provider.reorderNodes(visualOldIndex, visualNewIndex);
      },
      itemBuilder: (context, index) {
        final n = filteredNodes[index];
        final isSelected = selection.contains(n.id);
        return ReorderableDragStartListener(
          key: ValueKey(n.id),
          index: index,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.white,
              border: Border.all(
                color: isSelected
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.grey.shade200,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_handle, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.name.isEmpty
                            ? (n.isContainer ? "Container" : "Node")
                            : n.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        n.isContainer ? "CONTAINER" : "ICON",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Icona del nodo a destra (rimossa l'icona di trascinamento duplicata)
                Icon(
                  n.icon ?? (n.isContainer ? Icons.folder : Icons.widgets),
                  size: 16,
                  color: n.color,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper per trovare l'indice visuale corretto nella lista globale partendo dalla filtrata
  int allAllNodesIndex(
    List<GraphNode> all,
    List<GraphNode> filtered,
    int targetFilteredIndex,
  ) {
    final targetNode = filtered[targetFilteredIndex];
    return all.indexOf(targetNode);
  }
}
