class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
    this.active = true,
    this.rolNombre,
    this.tipoUsuarioNombre,
    this.lastLoginAt,
    this.createdAt,
  });

  final int id;
  final String nombre;
  final String apellido;
  final String correo;
  final bool active;
  final String? rolNombre;
  final String? tipoUsuarioNombre;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  String get nombreCompleto => '$nombre $apellido'.trim();

  /// Iniciales para el avatar cuando no hay imagen (p. ej. "JP").
  String get iniciales {
    final n = nombre.isNotEmpty ? nombre[0] : '';
    final a = apellido.isNotEmpty ? apellido[0] : '';
    final ini = '$n$a'.trim();
    return ini.isEmpty ? '?' : ini.toUpperCase();
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    String? nombreDe(dynamic relacion) {
      if (relacion is Map<String, dynamic>) return relacion['nombre'] as String?;
      return null;
    }

    return Usuario(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      active: json['active'] == true || json['active'] == 1,
      rolNombre: nombreDe(json['rol']),
      tipoUsuarioNombre: nombreDe(json['tipo_usuario']),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  /// Serialización para guardar el usuario en el almacén local (JSON en
  /// `sync_meta`). Reproduce la forma anidada para que `fromJson(toJson())`
  /// sea reversible.
  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'correo': correo,
        'active': active,
        'rol': rolNombre != null ? {'nombre': rolNombre} : null,
        'tipo_usuario':
            tipoUsuarioNombre != null ? {'nombre': tipoUsuarioNombre} : null,
        'last_login_at': lastLoginAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };
}
