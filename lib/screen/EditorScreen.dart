import 'package:flutter/material.dart';
import '../widget/GraphCanvas.dart';
import '../widget/EditorToolbar.dart';

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
          const Expanded(child: ClipRect(child: GraphCanvas())),
        ],
      ),
    );
  }
}
