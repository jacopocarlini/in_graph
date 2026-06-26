import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';
import '../model/graph_models.dart';

class YamlService {
  static String encodeGraph(List<GraphNode> nodes, List<GraphEdge> edges) {
    final Map<String, dynamic> graphMap = {
      'nodes': nodes.map((n) => n.toMap()).toList(),
      'edges': edges.map((e) => e.toMap()).toList(),
    };

    final yamlWriter = YamlWriter();
    return yamlWriter.write(graphMap);
  }

  static Map<String, List<dynamic>> decodeGraph(String yamlString) {
    try {
      final doc = loadYaml(yamlString);
      if (doc is! YamlMap) {
        throw Exception('Formato YAML non valido');
      }

      final nodesList = doc['nodes'] as YamlList?;
      final edgesList = doc['edges'] as YamlList?;

      final List<GraphNode> parsedNodes = [];
      final List<GraphEdge> parsedEdges = [];

      if (nodesList != null) {
        for (var nodeMap in nodesList) {
          if (nodeMap is YamlMap) {
            // Conversione ricorsiva della YamlMap in un Map<dynamic, dynamic> standard
            parsedNodes.add(GraphNode.fromMap(_deepCastMap(nodeMap)));
          }
        }
      }

      if (edgesList != null) {
        for (var edgeMap in edgesList) {
          if (edgeMap is YamlMap) {
            parsedEdges.add(GraphEdge.fromMap(_deepCastMap(edgeMap)));
          }
        }
      }

      return {
        'nodes': parsedNodes,
        'edges': parsedEdges,
      };
    } catch (e) {
      print('Errore durante il parsing dello YAML: $e');
      rethrow;
    }
  }

  static Map<dynamic, dynamic> _deepCastMap(YamlMap yamlMap) {
    final Map<dynamic, dynamic> result = {};
    for (final key in yamlMap.keys) {
      final value = yamlMap[key];
      if (value is YamlMap) {
        result[key] = _deepCastMap(value);
      } else if (value is YamlList) {
        result[key] = value.map((e) => e is YamlMap ? _deepCastMap(e) : e).toList();
      } else {
        result[key] = value;
      }
    }
    return result;
  }
}
