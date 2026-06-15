import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/graph_models.dart';
import '../provider/graph_provider.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GraphProvider>();
    final activeTool = provider.activeTool;

    return Container(
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ToolButton(
            icon: Icons.near_me_outlined,
            label: 'Pointer',
            shortcut: '1',
            isActive: activeTool == ToolType.pointer,
            onTap: () => provider.setTool(ToolType.pointer),
          ),
          _ToolButton(
            icon: Icons.pan_tool_outlined,
            label: 'Pan',
            shortcut: '2',
            isActive: activeTool == ToolType.pan,
            onTap: () => provider.setTool(ToolType.pan),
          ),

          const VerticalDivider(width: 32, indent: 16, endIndent: 16),

          _ToolButton(
            icon: Icons.crop_square,
            label: 'Node',
            shortcut: '3',
            isActive: activeTool == ToolType.node,
            onTap: () => provider.setTool(ToolType.node),
          ),
          _ToolButton(
            icon: Icons.grid_view,
            label: 'Container',
            shortcut: '4',
            isActive: activeTool == ToolType.container,
            onTap: () => provider.setTool(ToolType.container),
          ),
          _ToolButton(
            icon: Icons.arrow_right_alt_rounded,
            label: 'Edge',
            shortcut: '5',
            isActive: activeTool == ToolType.edge,
            onTap: () => provider.setTool(ToolType.edge),
          ),
        ],
      ),
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
