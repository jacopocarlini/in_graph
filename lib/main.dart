import 'package:flutter/material.dart';
import 'package:in_graph/screen/EditorScreen.dart';
import 'package:provider/provider.dart';
import 'provider/graph_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider(
      create: (context) => GraphProvider(),
      child: const MainGraphApp(),
    ),
  );
}

class MainGraphApp extends StatelessWidget {
  const MainGraphApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'In Graph Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        useMaterial3: true,
      ),
      home: const EditorScreen(),
    );
  }
}
