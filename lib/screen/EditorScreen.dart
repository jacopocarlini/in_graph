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
            child: Stack(
              children: [
                const Positioned.fill(child: ClipRect(child: GraphCanvas())),
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: GraphTreeSidebar(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
