class Noticia {
  const Noticia({
    required this.id,
    required this.titulo,
    this.descripcion,
    this.imagen,
    required this.publicado,
    this.fechaPublicacion,
    this.updatedAt,
  });

  final int id;
  final String titulo;
  final String? descripcion;
  final String? imagen;
  final bool publicado;
  final DateTime? fechaPublicacion;
  final DateTime? updatedAt;

  factory Noticia.fromJson(Map<String, dynamic> json) => Noticia(
        id: json['id'] as int,
        titulo: json['titulo'] as String,
        descripcion: json['descripcion'] as String?,
        imagen: json['imagen'] as String?,
        publicado: json['publicado'] == true || json['publicado'] == 1,
        fechaPublicacion: json['fecha_publicacion'] != null
            ? DateTime.tryParse(json['fecha_publicacion'].toString())
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
      );

  Map<String, dynamic> toSqliteRow() => {
        'id': id,
        'titulo': titulo,
        'descripcion': descripcion,
        'imagen': imagen,
        'publicado': publicado ? 1 : 0,
        'fecha_publicacion': fechaPublicacion?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'cached_at': DateTime.now().toIso8601String(),
      };

  factory Noticia.fromSqliteRow(Map<String, dynamic> row) => Noticia(
        id: row['id'] as int,
        titulo: row['titulo'] as String,
        descripcion: row['descripcion'] as String?,
        imagen: row['imagen'] as String?,
        publicado: row['publicado'] == 1,
        fechaPublicacion: row['fecha_publicacion'] != null
            ? DateTime.tryParse(row['fecha_publicacion'] as String)
            : null,
        updatedAt: row['updated_at'] != null
            ? DateTime.tryParse(row['updated_at'] as String)
            : null,
      );
}
