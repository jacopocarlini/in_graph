import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../util/azure_icon_catalog.dart';

class NodeIconSelection {
  final IconData? materialIcon;
  final String? assetPath;
  final String label;
  final String searchText;

  const NodeIconSelection({
    required this.label,
    required this.searchText,
    this.materialIcon,
    this.assetPath,
  });
}

class NodeIconPickerDialog extends StatefulWidget {
  final bool isContainer;
  final IconData? selectedMaterialIcon;
  final String? selectedAssetPath;

  const NodeIconPickerDialog({
    Key? key,
    required this.isContainer,
    required this.selectedMaterialIcon,
    required this.selectedAssetPath,
  }) : super(key: key);

  @override
  State<NodeIconPickerDialog> createState() => _NodeIconPickerDialogState();
}

class _NodeIconPickerDialogState extends State<NodeIconPickerDialog> {
  late final Future<List<NodeIconSelection>> _iconsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _iconsFuture = _loadOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Icon'),
      content: SizedBox(
        width: 820,
        height: 560,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filter',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<NodeIconSelection>>(
                future: _iconsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Errore nel caricamento delle icone: ${snapshot.error}',
                      ),
                    );
                  }

                  final icons = snapshot.data ?? const <NodeIconSelection>[];
                  final queryLower = _query.toLowerCase();
                  final filtered = queryLower.isEmpty
                      ? icons
                      : icons
                            .where(
                              (icon) => icon.searchText.contains(queryLower),
                            )
                            .toList(growable: false);

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Nessuna icona trovata con questo filtro.'),
                    );
                  }

                  return GridView.builder(
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.25,
                        ),
                    itemBuilder: (context, index) {
                      final icon = filtered[index];
                      final selected = _isSelected(icon);

                      return InkWell(
                        onTap: () => Navigator.of(context).pop(icon),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                            ),
                            color: selected
                                ? Colors.blue.withValues(alpha: 0.06)
                                : Colors.white,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (icon.assetPath != null)
                                SvgPicture.asset(
                                  icon.assetPath!,
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.contain,
                                )
                              else
                                Icon(
                                  icon.materialIcon,
                                  size: 34,
                                  color: Colors.blue,
                                ),
                              const SizedBox(height: 8),
                              Text(
                                icon.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
      ],
    );
  }

  Future<List<NodeIconSelection>> _loadOptions() async {
    final defaults = <NodeIconSelection>[
      NodeIconSelection(
        materialIcon: widget.isContainer ? Icons.folder : Icons.widgets,
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

    final svgAssets = await SvgAssetIconCatalog.loadAll();
    final svgOptions = svgAssets
        .map(
          (icon) => NodeIconSelection(
            assetPath: icon.assetPath,
            label: '${icon.name} (${icon.category})',
            searchText: icon.searchText,
          ),
        )
        .toList(growable: false);

    return <NodeIconSelection>[...defaults, ...svgOptions];
  }

  bool _isSelected(NodeIconSelection icon) {
    if (icon.assetPath != null) {
      return icon.assetPath == widget.selectedAssetPath;
    }

    if (widget.selectedAssetPath != null) {
      return false;
    }

    return _sameMaterialIcon(icon.materialIcon, widget.selectedMaterialIcon);
  }

  bool _sameMaterialIcon(IconData? a, IconData? b) {
    if (a == null || b == null) return false;
    return a.codePoint == b.codePoint &&
        a.fontFamily == b.fontFamily &&
        a.fontPackage == b.fontPackage;
  }
}
