import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class GraphStorageService {
  // Esta función copia el .dat de assets a la memoria del cel
  Future<String> copyGraphToLocal() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, "grafo_la_paz.dat");
    final file = File(path);

    // Solo lo copiamos si no existe ya, para no gastar batería
    if (!await file.exists()) {
      final data = await rootBundle.load("assets/grafo_la_paz.dat");
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes);
    }
    
    return path; // Retornamos la ruta absoluta que C++ entiende
  }
}