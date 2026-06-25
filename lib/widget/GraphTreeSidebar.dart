import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/graph_models.dart';
import '../provider/graph_provider.dart';

class GraphTreeSidebar extends StatelessWidget {
  const GraphTreeSidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ascoltiamo i cambiamenti del provider (nodi aggiunti, mossi, selezionati)
    final provider = context.watch<GraphProvider>();

    // Prendiamo solo i nodi "Radice", ovvero quelli che non hanno nessun padre (parentId == null)
    final rootNodes = provider.nodes.where((node) => node.parentId == null).toList();

    return Container(
      width: 260, // Larghezza della sidebar laterale
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intestazione della Sidebar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.account_tree_outlined, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Struttura del Grafo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista ad albero dei nodi radice
          Expanded(
            child: rootNodes.isEmpty
                ? const Center(
              child: Text(
                'Nessun elemento nel grafo',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
                : ListView.builder(
              itemCount: rootNodes.length,
              itemBuilder: (context, index) {
                // Avviamo la renderizzazione ricorsiva partendo dal livello 0 (Root)
                return _buildTreeItem(rootNodes[index], 0, provider);
              },
            ),
          ),
        ],
      ),
    );
  }

  // METODO RICORSIVO: Disegna il nodo corrente e richiama se stesso per i suoi figli
  Widget _buildTreeItem(GraphNode node, int depth, GraphProvider provider) {
    final isSelected = provider.selection.contains(node.id);

    // Cerchiamo tutti i nodi che hanno come parentId l'id del nodo corrente
    final children = provider.nodes.where((n) => n.parentId == node.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La riga del singolo elemento
        InkWell(
          onTap: () {
            // Cliccando sull'elemento nell'albero, lo selezioniamo nel Canvas
            provider.setSelection(node.id);
          },
          child: Container(
            // Colore di sfondo se selezionato
            color: isSelected ? Colors.blue.withOpacity(0.08) : Colors.transparent,
            padding: EdgeInsets.only(
              // INDENTAZIONE DINAMICA: Più è profondo il nodo, più spazio lasciamo a sinistra
              left: 12.0 + (depth * 18.0),
              top: 6.0,
              bottom: 6.0,
              right: 8.0,
            ),
            child: Row(
              children: [
                // Icona di espansione/collasso SOLO per i container che hanno figli
                if (node.isContainer)
                  GestureDetector(
                    onTap: () => provider.toggleCollapse(node.id),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Icon(
                        node.isCollapsed
                            ? Icons.keyboard_arrow_right_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 22), // Spazio vuoto compensativo per i nodi normali senza freccia

                // Icona del tipo di nodo (Cartella/Widget)
                Icon(
                  node.isContainer
                      ? (node.isCollapsed ? Icons.folder_rounded : Icons.folder_open_rounded)
                      : Icons.widgets_outlined,
                  size: 18,
                  color: isSelected ? Colors.blue : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),

                // Nome del nodo
                Expanded(
                  child: Text(
                    node.name.trim().isEmpty
                        ? (node.isContainer ? 'Container' : 'Nodo')
                        : node.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue.shade800 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // SEZIONE RICORSIVA: Se l'elemento è un container, NON è collassato e ha dei figli,
        // mappiamo i suoi figli eseguendo nuovamente questa funzione con depth + 1
        if (node.isContainer && !node.isCollapsed && children.isNotEmpty)
          ...children.map((child) => _buildTreeItem(child, depth + 1, provider)).toList(),
      ],
    );
  }
}