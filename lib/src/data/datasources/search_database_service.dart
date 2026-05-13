import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class SearchDatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "search_lapaz.sqlite");

    // Verificar si ya existe la DB en el almacenamiento local
    final exists = await databaseExists(path);

    if (!exists) {
      // Si no existe, la copiamos de los assets
      try {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load(join("assets", "search_lapaz.sqlite"));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        throw Exception("Error copiando la base de datos de búsqueda: $e");
      }
    }

    return await openDatabase(path, readOnly: true);
  }
}
