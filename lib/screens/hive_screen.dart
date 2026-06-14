import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive Database Görsel Ekranı
/// Hive içindeki tüm box'ları ve kayıtları gösterir.
/// Sadece OKUMA amaçlıdır, değişiklik yapmaz.
class HiveScreen extends StatefulWidget {
  const HiveScreen({super.key});

  @override
  State<HiveScreen> createState() => _HiveScreenState();
}

class _HiveScreenState extends State<HiveScreen> {
  List<_BoxInfo> _boxes = [];

  @override
  void initState() {
    super.initState();
    _loadHiveData();
  }

  void _loadHiveData() {
    _boxes = [];

    // Açık olan tüm Hive box'larını tara
    for (final boxName in [
      'player_box',
      'warehouses_box',
      'factories_box',
      'purchases_box',
    ]) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          _boxes.add(_BoxInfo(
            name: boxName,
            entries: box.values.toList(),
          ));
        }
      } catch (_) {}
    }

    setState(() {});
  }

  Color _getBoxColor(String name) {
    switch (name) {
      case 'player_box':
        return Colors.blue;
      case 'warehouses_box':
        return Colors.teal;
      case 'factories_box':
        return Colors.orange;
      case 'purchases_box':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getBoxIcon(String name) {
    switch (name) {
      case 'player_box':
        return Icons.person;
      case 'warehouses_box':
        return Icons.warehouse;
      case 'factories_box':
        return Icons.factory;
      case 'purchases_box':
        return Icons.shopping_cart;
      default:
        return Icons.storage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.storage, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text(
              'Hive Database',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 80, 80, 143),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            tooltip: 'Refresh',
            onPressed: _loadHiveData,
          ),
        ],
      ),
      body: _boxes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storage_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No Hive data found',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start the game engine first, then check again.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _boxes.length,
              itemBuilder: (context, index) {
                final box = _boxes[index];
                final color = _getBoxColor(box.name);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
                  ),
                  color: const Color.fromARGB(255, 100, 118, 102),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getBoxIcon(box.name), color: color, size: 24),
                    ),
                    title: Row(
                      children: [
                        Text(
                          box.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${box.entries.length} records',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: box.entries.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                '(empty)',
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ]
                        : box.entries.asMap().entries.map((entry) {
                            final entryIndex = entry.key;
                            final entryValue = entry.value;
                            return _EntryCard(
                              index: entryIndex,
                              rawValue: entryValue,
                              boxColor: color,
                            );
                          }).toList(),
                  ),
                );
              },
            ),
    );
  }
}

class _BoxInfo {
  final String name;
  final List<dynamic> entries;

  _BoxInfo({required this.name, required this.entries});
}

class _EntryCard extends StatelessWidget {
  final int index;
  final dynamic rawValue;
  final Color boxColor;

  const _EntryCard({
    required this.index,
    required this.rawValue,
    required this.boxColor,
  });

  @override
  Widget build(BuildContext context) {
    String formatted;
    String preview;
    bool isJson = false;

    try {
      if (rawValue is String) {
        final parsed = jsonDecode(rawValue);
        isJson = true;
        if (parsed is Map) {
          final map = parsed as Map<String, dynamic>;
          final sb = StringBuffer();
          for (final entry in map.entries) {
            final val = entry.value is Map || entry.value is List
                ? _stringify(entry.value)
                : entry.value.toString();
            sb.writeln('  ${entry.key}: $val');
          }
          formatted = sb.toString();
          final lines = formatted.split('\n').where((l) => l.trim().isNotEmpty).take(3).join('\n');
          preview = lines;
        } else {
          formatted = parsed.toString();
          preview = formatted;
        }
      } else {
        formatted = rawValue.toString();
        preview = formatted;
      }
    } catch (_) {
      formatted = rawValue.toString();
      preview = formatted.length > 80 ? '${formatted.substring(0, 80)}...' : formatted;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 85, 62, 85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: boxColor.withValues(alpha: 0.15)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: boxColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                color: boxColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          preview,
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          maxLines: isJson ? 3 : 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 21, 21, 200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              formatted,
              style: TextStyle(
                color: isJson ? Colors.green[200] : Colors.orange[200],
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stringify(dynamic value) {
    if (value is Map) {
      final entries = value.entries.map((e) => '${e.key}:${e.value}').join(', ');
      return '{$entries}';
    } else if (value is List) {
      return value.map((e) => e.toString()).join(', ');
    }
    return value.toString();
  }
}