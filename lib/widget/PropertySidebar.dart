import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/graph_models.dart';
import '../provider/graph_provider.dart';
import '../util/azure_icon_catalog.dart';
import 'azure_icon_picker_dialog.dart';
import 'node_icon.dart';
import 'package:material_symbols_icons/symbols.dart';

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

    GraphEdge? edge;
    try {
      // Cerchiamo prima tra quelli aggregati (quelli visibili a video)
      edge = aggregatedEdges.firstWhere((e) => e.id == edgeId);
    } catch (_) {
      try {
        // Poi tra quelli reali (nel caso fosse un riferimento diretto)
        edge = provider.edges.firstWhere((e) => e.id == edgeId);
      } catch (_) {
        edge = null;
      }
    }

    if (edge == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Select an item",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

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
              _buildSectionTitle("Label"),
              const SizedBox(height: 8),
              _buildEdgeLabelInput(edge, provider),
              const SizedBox(height: 24),
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

  Widget _buildEdgeLabelInput(GraphEdge edge, GraphProvider provider) {
    return _EdgeLabelInput(
      key: ValueKey(edge.id),
      edge: edge,
      provider: provider,
    );
  }
}

class _EdgeLabelInput extends StatefulWidget {
  final GraphEdge edge;
  final GraphProvider provider;

  const _EdgeLabelInput({Key? key, required this.edge, required this.provider})
    : super(key: key);

  @override
  State<_EdgeLabelInput> createState() => _EdgeLabelInputState();
}

class _EdgeLabelInputState extends State<_EdgeLabelInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.edge.label);
  }

  @override
  void didUpdateWidget(covariant _EdgeLabelInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.edge.label != widget.edge.label &&
        _controller.text != widget.edge.label) {
      _controller.text = widget.edge.label ?? "";
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: "Enter label...",
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: (val) => widget.provider.updateEdgeLabel(widget.edge.id, val),
      onTap: () => widget.provider.setIsTextEdit(true),
      onTapOutside: (_) {
        widget.provider.setIsTextEdit(false);
        FocusScope.of(context).unfocus();
      },
    );
  }
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
  return _NodeIconSelector(
    key: ValueKey('${node.id}-${node.iconAssetPath}-${node.icon?.codePoint}'),
    node: node,
    provider: provider,
  );
}

class _NodeIconSelector extends StatefulWidget {
  final GraphNode node;
  final GraphProvider provider;

  const _NodeIconSelector({
    Key? key,
    required this.node,
    required this.provider,
  }) : super(key: key);

  @override
  State<_NodeIconSelector> createState() => _NodeIconSelectorState();
}

class _NodeIconSelectorState extends State<_NodeIconSelector> {
  final List<NodeIconSelection> _options = [];
  bool _isLoadingLocal = true;
  bool _isLoadingDrawio = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocal && _options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    final current = _findCurrentOption(_options);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Autocomplete<NodeIconSelection>(
                initialValue: TextEditingValue(text: current?.label ?? ''),
                displayStringForOption: (o) => o.label,
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();
                  final selectedLabel = (current?.label ?? '').toLowerCase();
                  if (query.isEmpty || query == selectedLabel) {
                    return _options.take(120);
                  }

                  return _options
                      .where((o) => o.searchText.contains(query))
                      .take(250);
                },
                onSelected: _applySelection,
                fieldViewBuilder:
                    (context, textEditingController, focusNode, onSubmitted) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Icon',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(10),
                            child: NodeIcon(
                              materialIcon:
                                  current?.materialIcon ?? widget.node.icon,
                              iconAssetPath:
                                  current?.assetPath ??
                                  widget.node.iconAssetPath,
                              color: widget.node.color,
                              size: 18,
                            ),
                          ),
                          suffixIcon: const Icon(Icons.expand_more),
                        ),
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  final list = options.toList(growable: false);
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 320,
                          maxWidth: 520,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final item = list[index];
                            return ListTile(
                              dense: true,
                              leading: _menuLeadingIcon(item),
                              title: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => onSelected(item),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (_isLoadingDrawio)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Future<void> _loadOptions() async {
    final defaults = <NodeIconSelection>[
      NodeIconSelection(
        materialIcon: widget.node.isContainer ? Icons.folder : Icons.widgets,
        label: 'Default',
        searchText: 'default material',
      ),
      const NodeIconSelection(
        materialIcon: Icons.flash_on,
        label: 'Function',
        searchText: 'function material',
      ),
      const NodeIconSelection(
        materialIcon: Icons.storage,
        label: 'Database',
        searchText: 'database material',
      ),
      const NodeIconSelection(
        materialIcon: Icons.cloud,
        label: 'Cloud',
        searchText: 'cloud material',
      ),
      const NodeIconSelection(
        materialIcon: Icons.person,
        label: 'User',
        searchText: 'user material',
      ),
      const NodeIconSelection(
        materialIcon: Icons.settings,
        label: 'Settings',
        searchText: 'settings material',
      ),
    ];

    final localSvgAssets = await SvgAssetIconCatalog.load();
    final localSvgOptions = localSvgAssets
        .map(
          (icon) => NodeIconSelection(
            assetPath: icon.assetPath,
            label: '${icon.name} (${icon.category})',
            searchText: icon.searchText,
          ),
        )
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _options
        ..clear()
        ..addAll([...defaults, ...localSvgOptions]);
      _isLoadingLocal = false;
      _isLoadingDrawio = true;
    });

    try {
      final drawioAssets = await SvgAssetIconCatalog.loadDrawio();
      if (!mounted) return;

      final existing = _options.map((o) => o.assetPath).toSet();
      final drawioOptions = drawioAssets
          .where((icon) => !existing.contains(icon.assetPath))
          .map(
            (icon) => NodeIconSelection(
              assetPath: icon.assetPath,
              label: '${icon.name} (${icon.category})',
              searchText: icon.searchText,
            ),
          )
          .toList(growable: false);

      setState(() {
        _options.addAll(drawioOptions);
        _isLoadingDrawio = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDrawio = false);
    }
  }

  void _applySelection(NodeIconSelection selected) {
    if (selected.assetPath != null) {
      widget.provider.updateNodeIcon(
        widget.node.id,
        iconAssetPath: selected.assetPath,
      );
    } else {
      widget.provider.updateNodeIcon(
        widget.node.id,
        icon: selected.materialIcon,
        clearIconAsset: true,
      );
    }
  }

  Widget _menuLeadingIcon(NodeIconSelection item) {
    return NodeIcon(
      materialIcon: item.materialIcon,
      iconAssetPath: item.assetPath,
      color: widget.node.color,
      size: 18,
    );
  }

  NodeIconSelection? _findCurrentOption(List<NodeIconSelection> options) {
    if (widget.node.iconAssetPath != null) {
      return options.firstWhere(
        (o) => o.assetPath == widget.node.iconAssetPath,
        orElse: () => options.first,
      );
    }

    return options.firstWhere(
      (o) =>
          o.assetPath == null &&
          o.materialIcon?.codePoint == widget.node.icon?.codePoint &&
          o.materialIcon?.fontFamily == widget.node.icon?.fontFamily &&
          o.materialIcon?.fontPackage == widget.node.icon?.fontPackage,
      orElse: () => options.first,
    );
  }
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
      const SizedBox(width: 8),
      // Use Expanded + Wrap to avoid RenderFlex overflow on small widths.
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: colors.map((color) {
              final isSelected = node.color.value == color.value;
              return GestureDetector(
                onTap: () => provider.updateNodeColor(node.id, color),
                child: Container(
                  // margin not needed because Wrap handles spacing
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
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ),
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
      const SizedBox(width: 8),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: colors.map((color) {
              final isSelected = edge.color.value == color.value;
              return GestureDetector(
                onTap: () => provider.updateEdgeColor(edge.id, color),
                child: Container(
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
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ),
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
      const SizedBox(width: 8),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _buildToggleOption(
                "Solid",
                Icons.remove,
                node.borderStyle == BorderStyleType.solid,
                () => provider.updateNodeBorderStyle(
                  node.id,
                  BorderStyleType.solid,
                ),
              ),
              _buildToggleOption(
                "Dashed",
                Icons.more_horiz,
                node.borderStyle == BorderStyleType.dashed,
                () => provider.updateNodeBorderStyle(
                  node.id,
                  BorderStyleType.dashed,
                ),
              ),
            ],
          ),
        ),
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
      const SizedBox(width: 8),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _buildToggleOption(
                "Solid",
                Icons.maximize,
                edge.borderStyle == BorderStyleType.solid,
                () => provider.updateEdgeBorderStyle(
                  edge.id,
                  BorderStyleType.solid,
                ),
              ),
              _buildToggleOption(
                "Dashed",
                Icons.more_horiz,
                edge.borderStyle == BorderStyleType.dashed,
                () => provider.updateEdgeBorderStyle(
                  edge.id,
                  BorderStyleType.dashed,
                ),
              ),
            ],
          ),
        ),
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
      const SizedBox(width: 8),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            alignment: WrapAlignment.end,
            children: [
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
          ),
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
            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
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
    buildDefaultDragHandles: false,
    // Disabilitiamo le maniglie di default
    itemCount: filteredNodes.length,
    onReorder: (oldIndex, newIndex) {
      if (oldIndex < newIndex) newIndex -= 1;

      final nodeToMove = filteredNodes[oldIndex];
      final targetNode = filteredNodes[newIndex];

      final List<GraphNode> allNodesReversed = provider.nodes.reversed.toList();
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
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Icona del nodo a destra (rimossa l'icona di trascinamento duplicata)
              NodeIcon(
                materialIcon:
                    n.icon ?? (n.isContainer ? Icons.folder : Icons.widgets),
                iconAssetPath: n.iconAssetPath,
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
