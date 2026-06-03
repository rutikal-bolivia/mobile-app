import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/app_config.dart';
import '../datasources/app_database_service.dart';
import '../../domain/models/usuario.dart';

/// Error de autenticación con un mensaje listo para mostrar al usuario.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Repositorio de autenticación. Habla con los endpoints `/auth/*` del backend
/// y persiste la sesión (token + usuario) en la tabla `sync_meta`, siguiendo la
/// misma lógica de almacenamiento local que el resto de la app.
class AuthRepository {
  AuthRepository({
    required this.dbService,
    Dio? dio,
    String? baseUrl,
  })  : _dio = dio ?? Dio(),
        baseUrl = baseUrl ?? AppConfig.backendUrl;

  final AppDatabaseService dbService;
  final Dio _dio;
  final String baseUrl;

  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';

  // ── Sesión local ────────────────────────────────────────────────────────────

  Future<String?> token() async {
    final db = await dbService.database;
    final rows = await db.query('sync_meta',
        where: 'clave = ?', whereArgs: [_kToken], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['valor'] as String?;
  }

  Future<Usuario?> currentUser() async {
    final db = await dbService.database;
    final rows = await db.query('sync_meta',
        where: 'clave = ?', whereArgs: [_kUser], limit: 1);
    if (rows.isEmpty) return null;
    final raw = rows.first['valor'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return Usuario.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> get isLoggedIn async => (await token()) != null;

  Future<void> _guardarSesion(String token, Usuario user) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      await txn.insert('sync_meta', {'clave': _kToken, 'valor': token},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert(
          'sync_meta', {'clave': _kUser, 'valor': jsonEncode(user.toJson())},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> _guardarUsuario(Usuario user) async {
    final db = await dbService.database;
    await db.insert(
        'sync_meta', {'clave': _kUser, 'valor': jsonEncode(user.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _limpiarSesion() async {
    final db = await dbService.database;
    await db.delete('sync_meta',
        where: 'clave IN (?, ?)', whereArgs: [_kToken, _kUser]);
  }

  // ── Operaciones remotas ───────────────────────────────────────────────────

  /// Inicia sesión y persiste el token + usuario. Lanza [AuthException] con un
  /// mensaje legible si las credenciales son inválidas o la cuenta está
  /// deshabilitada.
  Future<Usuario> login(String correo, String password) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/login',
        data: {'correo': correo, 'password': password},
      );
      return await _procesarRespuestaAuth(response.data);
    } on DioException catch (e) {
      throw _mapearError(e, fallback: 'No se pudo iniciar sesión.');
    }
  }

  /// Registra una cuenta nueva (rol `cliente`) y persiste la sesión.
  Future<Usuario> register({
    required String nombre,
    required String apellido,
    required String correo,
    required String password,
    required String passwordConfirmation,
    int? tipoUsuarioId,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/register',
        data: {
          'nombre': nombre,
          'apellido': apellido,
          'correo': correo,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'tipo_usuario_id': ?tipoUsuarioId,
        },
      );
      return await _procesarRespuestaAuth(response.data);
    } on DioException catch (e) {
      throw _mapearError(e, fallback: 'No se pudo crear la cuenta.');
    }
  }

  /// Refresca el perfil desde el backend usando el token guardado.
  /// Lanza [AuthException] si no hay sesión o el token ya no es válido (401).
  Future<Usuario> getProfile() async {
    final t = await token();
    if (t == null) throw const AuthException('No hay sesión activa.');
    try {
      final response = await _dio.get(
        '$baseUrl/auth/profile',
        options: Options(headers: {'Authorization': 'Bearer $t'}),
      );
      final data = response.data as Map<String, dynamic>;
      final user = Usuario.fromJson(data['user'] as Map<String, dynamic>);
      await _guardarUsuario(user);
      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _limpiarSesion();
        throw const AuthException('Tu sesión expiró. Inicia sesión de nuevo.');
      }
      throw _mapearError(e, fallback: 'No se pudo obtener el perfil.');
    }
  }

  /// Cierra sesión: revoca el token en el backend (best-effort) y limpia el
  /// almacén local siempre.
  Future<void> logout() async {
    final t = await token();
    if (t != null) {
      try {
        await _dio.post(
          '$baseUrl/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $t'}),
        );
      } catch (e) {
        debugPrint('[AUTH] Logout remoto falló (se limpia local igual): $e');
      }
    }
    await _limpiarSesion();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<Usuario> _procesarRespuestaAuth(dynamic data) async {
    final map = data as Map<String, dynamic>;
    final token = map['access_token'] as String;
    final user = Usuario.fromJson(map['user'] as Map<String, dynamic>);
    await _guardarSesion(token, user);
    return user;
  }

  AuthException _mapearError(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      // Errores de validación de Laravel: { errors: { campo: [msg] } }
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final primero = errors.values.first;
        if (primero is List && primero.isNotEmpty) {
          return AuthException(primero.first.toString());
        }
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return AuthException(message);
      }
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const AuthException(
          'No hay conexión con el servidor. Inténtalo más tarde.');
    }
    return AuthException(fallback);
  }
}
