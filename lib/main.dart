import 'package:flutter/material.dart';
import 'package:in_graph/screen/EditorScreen.dart';
import 'package:provider/provider.dart';
import 'provider/graph_provider.dart';
import 'service/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SupabaseService.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (context) => GraphProvider(),
      child: const MainGraphApp(),
    ),
  );
}

class MainGraphApp extends StatefulWidget {
  const MainGraphApp({super.key});

  @override
  State<MainGraphApp> createState() => _MainGraphAppState();
}

class _MainGraphAppState extends State<MainGraphApp> {
  @override
  void initState() {
    super.initState();
    // Gestione caricamento grafo da URL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      final graphId = uri.queryParameters['v'];
      if (graphId != null) {
        Provider.of<GraphProvider>(context, listen: false).loadGraph(graphId);
      }
    });
  }

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
