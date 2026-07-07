import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/graph_models.dart';
import '../provider/graph_provider.dart';

class LayersPanel extends StatelessWidget {
  const LayersPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GraphProvider>();

    // Invertiamo la lista solo visivamente:
    // l'ultimo nodo del canvas (primo piano) sarà il primo della lista UI.
    final reversedNodes = provider.nodes.reversed.toList();

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header del pannello
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.layers, size: 20, color: Colors.black87),
                SizedBox(width: 8),
                Text(
                  'Layers',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),

          // Legenda aggiornata (Foreground in alto, Background in basso)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Foreground ▲ / ▼ Background",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),

          // Lista riordinabile
          Expanded(
            child: reversedNodes.isEmpty
                ? Center(
                    child: Text(
                      "No nodes",
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  )
                : ReorderableListView.builder(
                    // Usiamo la lista invertita per contare e popolare gli item
                    itemCount: reversedNodes.length,
                    onReorder: (oldIndex, newIndex) {
                      provider.reorderNodes(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      // Prendiamo il nodo dalla lista invertita
                      final node = reversedNodes[index];
                      final isSelected = provider.selection.contains(node.id);

                      return _buildLayerItem(
                        context: context,
                        node: node,
                        isSelected: isSelected,
                        provider: provider,
                        key: ValueKey(node.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerItem({
    required BuildContext context,
    required GraphNode node,
    required bool isSelected,
    required GraphProvider provider,
    required Key key,
  }) {
    return Material(
      key: key,
      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
      child: InkWell(
        onTap: () {
          // Seleziona il nodo cliccato
          provider.setSelection(node.id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                node.isContainer ? Icons.folder : Icons.widgets,
                size: 18,
                color: isSelected ? Colors.blue : Colors.grey.shade600,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? Colors.blue.shade900 : Colors.black87,
                  ),
                ),
              ),
              // Icona di trascinamento
              Icon(Icons.drag_handle, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
