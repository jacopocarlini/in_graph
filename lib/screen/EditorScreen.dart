import 'package:flutter/material.dart';
import '../widget/GraphCanvas.dart';
import '../widget/EditorToolbar.dart';
import '../widget/GraphTreeSidebar.dart';
import '../widget/LayersPanel.dart';

class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // --- TOOLBAR SUPERIORE ---
          const SizedBox(height: 80, child: EditorToolbar()),

          // --- DIVISORE ORIZZONTALE ---
          const Divider(height: 1, thickness: 1, color: Colors.black12),

          // --- AREA CANVAS ---
          Expanded(
            child: Row(
              children: [
                const GraphTreeSidebar(), // Ha una sua larghezza fissa (es. 260)
                // --- FIX: Avvolgi il Canvas in un Expanded ---
                const Expanded(child: ClipRect(child: GraphCanvas())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
