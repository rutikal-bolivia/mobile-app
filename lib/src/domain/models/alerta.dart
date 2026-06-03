import 'dart:convert';

class Alerta {
  const Alerta({
    required this.id,
    required this.titulo,
    this.descripcion,
    required this.tipo,
    required this.severidad,
    this.fechaInicio,
    this.fechaFin,
    this.paradasIds = const [],
    this.rutasIds = const [],
    this.updatedAt,
  });

  final int id;
  final String titulo;
  final String? descripcion;
  final String tipo;       // cierre | retraso | mantenimiento | informativa
  final String severidad;  // baja | media | alta
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final List<int> paradasIds;
  final List<int> rutasIds;
  final DateTime? updatedAt;

  factory Alerta.fromJson(Map<String, dynamic> json) {
    List<int> extractIds(dynamic list) {
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => e['id'] as int? ?? 0)
          .where((id) => id != 0)
          .toList();
    }

    return Alerta(
      id: json['id'] as int,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String?,
      tipo: json['tipo'] as String? ?? 'informativa',
      severidad: json['severidad'] as String? ?? 'baja',
      fechaInicio: json['fecha_inicio'] != null
          ? DateTime.tryParse(json['fecha_inicio'].toString())
          : null,
      fechaFin: json['fecha_fin'] != null
          ? DateTime.tryParse(json['fecha_fin'].toString())
          : null,
      paradasIds: extractIds(json['paradas']),
      rutasIds: extractIds(json['rutas']),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toSqliteRow() => {
        'id': id,
        'titulo': titulo,
        'descripcion': descripcion,
        'tipo': tipo,
        'severidad': severidad,
        'fecha_inicio': fechaInicio?.toIso8601String(),
        'fecha_fin': fechaFin?.toIso8601String(),
        'paradas_json': jsonEncode(paradasIds),
        'rutas_json': jsonEncode(rutasIds),
        'updated_at': updatedAt?.toIso8601String(),
        'cached_at': DateTime.now().toIso8601String(),
      };

  factory Alerta.fromSqliteRow(Map<String, dynamic> row) => Alerta(
        id: row['id'] as int,
        titulo: row['titulo'] as String,
        descripcion: row['descripcion'] as String?,
        tipo: row['tipo'] as String? ?? 'informativa',
        severidad: row['severidad'] as String? ?? 'baja',
        fechaInicio: row['fecha_inicio'] != null
            ? DateTime.tryParse(row['fecha_inicio'] as String)
            : null,
        fechaFin: row['fecha_fin'] != null
            ? DateTime.tryParse(row['fecha_fin'] as String)
            : null,
        paradasIds: row['paradas_json'] != null
            ? List<int>.from(jsonDecode(row['paradas_json'] as String) as List)
            : [],
        rutasIds: row['rutas_json'] != null
            ? List<int>.from(jsonDecode(row['rutas_json'] as String) as List)
            : [],
        updatedAt: row['updated_at'] != null
            ? DateTime.tryParse(row['updated_at'] as String)
            : null,
      );

  bool get vigente {
    final now = DateTime.now();
    if (fechaInicio != null && fechaInicio!.isAfter(now)) return false;
    if (fechaFin != null && fechaFin!.isBefore(now)) return false;
    return true;
  }
}
