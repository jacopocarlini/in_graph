import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'package:flutter/material.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://gprbutmjpxgupofuqxez.supabase.co';
  static const String supabaseKey = 'sb_publishable_UZyhgUGZgwmvCLDsKGhF-g_-TbNlhmg';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

class UserPresence {
  final String id;
  final String name;
  final Color color;
  final Offset position;

  UserPresence({
    required this.id,
    required this.name,
    required this.color,
    this.position = Offset.zero,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.toARGB32(),
    'x': position.dx,
    'y': position.dy,
  };

  factory UserPresence.fromJson(Map<String, dynamic> json) => UserPresence(
    id: json['id'],
    name: json['name'],
    color: Color(json['color']),
    position: Offset(json['x']?.toDouble() ?? 0.0, json['y']?.toDouble() ?? 0.0),
  );
}

class CollaborationManager {
  static final String myId = const Uuid().v4();
  static final String myName = _generateRandomName();
  static final Color myColor = _generateRandomColor();

  static String _generateRandomName() {
    final names = ['Archimede', 'Leonardo', 'Tesla', 'Galileo', 'Newton', 'Einstein', 'Curie', 'Hypatia'];
    return names[Random().nextInt(names.length)] + ' ' + (Random().nextInt(900) + 100).toString();
  }

  static Color _generateRandomColor() {
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.pink, Colors.teal, Colors.indigo];
    return colors[Random().nextInt(colors.length)];
  }
}
