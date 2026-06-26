import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/graph_models.dart';
import '../provider/graph_provider.dart';

import '../util/file_export_service.dart';
import '../util/yaml_service.dart';
import '../util/png_export_service.dart';
import '../util/svg_export_service.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GraphProvider>();
    final activeTool = provider.activeTool;

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToolButton(
                  icon: Icons.near_me_outlined,
                  label: 'Pointer',
                  shortcut: '1',
                  isActive: activeTool == ToolType.pointer,
                  onTap: () => provider.handleToolChange(ToolType.pointer),
                ),
                _ToolButton(
                  icon: Icons.pan_tool_outlined,
                  label: 'Pan',
                  shortcut: '2',
                  isActive: activeTool == ToolType.pan,
                  onTap: () => provider.handleToolChange(ToolType.pan),
                ),
                const VerticalDivider(width: 32, indent: 16, endIndent: 16),
                _ToolButton(
                  icon: Icons.crop_square,
                  label: 'Node',
                  shortcut: '3',
                  isActive: activeTool == ToolType.node,
                  onTap: () => provider.handleToolChange(ToolType.node),
                ),
                _ToolButton(
                  icon: Icons.grid_view,
                  label: 'Container',
                  shortcut: '4',
                  isActive: activeTool == ToolType.container,
                  onTap: () => provider.handleToolChange(ToolType.container),
                ),
                _ToolButton(
                  icon: Icons.arrow_right_alt_rounded,
                  label: 'Edge',
                  shortcut: '5',
                  isActive: activeTool == ToolType.edge,
                  onTap: () => provider.handleToolChange(ToolType.edge),
                ),
                const VerticalDivider(width: 32, indent: 16, endIndent: 16),
                _ToolButton(
                  icon: Icons.travel_explore,
                  label: 'Explorer',
                  shortcut: '6',
                  isActive: activeTool == ToolType.explorer,
                  onTap: () => provider.handleToolChange(ToolType.explorer),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _ExportImportMenu(provider: provider),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportImportMenu extends StatelessWidget {
  final GraphProvider provider;

  const _ExportImportMenu({required this.provider});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.import_export),
      tooltip: 'Export/Import',
      onSelected: (value) async {
        if (value == 'export_yaml') {
          final yaml = YamlService.encodeGraph(provider.nodes, provider.edges);
          await FileExportService.saveStringFile(
            content: yaml,
            fileName: 'graph.yaml',
            extension: 'yaml',
          );
        } else if (value == 'import_yaml') {
          final yaml = await FileExportService.pickAndReadFile(
            allowedExtensions: ['yaml', 'yml'],
          );
          if (yaml != null) {
            final data = YamlService.decodeGraph(yaml);
            provider.loadFromGraphData(
              data['nodes'] as List<GraphNode>,
              data['edges'] as List<GraphEdge>,
            );
          }
        } else if (value == 'export_png') {
          final bytes = await PngExportService.captureAsPng(
            provider,
            pixelRatio: 2.0,
          );
          if (bytes != null) {
            await FileExportService.saveBytesFile(
              bytes: bytes,
              fileName: 'graph.png',
              extension: 'png',
            );
          }
        } else if (value == 'export_svg') {
          final svg = SvgExportService.exportAsSvg(provider);
          await FileExportService.saveStringFile(
            content: svg,
            fileName: 'graph.svg',
            extension: 'svg',
          );
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'export_yaml',
          child: ListTile(
            leading: Icon(Icons.save_alt),
            title: Text('Esporta YAML'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'import_yaml',
          child: ListTile(
            leading: Icon(Icons.upload_file),
            title: Text('Importa YAML'),
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'export_png',
          child: ListTile(
            leading: Icon(Icons.image_outlined),
            title: Text('Esporta PNG'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'export_svg',
          child: ListTile(
            leading: Icon(Icons.code),
            title: Text('Esporta SVG'),
            dense: true,
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String shortcut;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.shortcut,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? Colors.blue.shade200 : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive
                    ? Colors.blue.shade700
                    : Colors.blueGrey.shade600,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? Colors.blue.shade700
                      : Colors.blueGrey.shade600,
                ),
              ),
              Text(
                shortcut,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? Colors.blue.shade700
                      : Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
