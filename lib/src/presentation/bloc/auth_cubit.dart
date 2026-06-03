import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/usuario.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.unknown, this.user});

  final AuthStatus status;
  final Usuario? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({AuthStatus? status, Usuario? user}) => AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
      );

  @override
  List<Object?> get props => [status, user];
}

/// Gestiona el estado de la sesión a nivel de app. Se provee en `RootPage`
/// (junto a `NavigationCubit`, `RoutingBloc` y `SyncCubit`) para que cualquier
/// pestaña pueda consultarlo. Las pantallas de login/registro manejan su propio
/// estado de envío y delegan la operación a este cubit.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required AuthRepository repository})
      : _repository = repository,
        super(const AuthState());

  final AuthRepository _repository;

  /// Carga la sesión guardada al arrancar. Muestra el usuario en caché de
  /// inmediato y luego intenta refrescarlo desde el backend.
  Future<void> loadSession() async {
    final cached = await _repository.currentUser();
    if (cached == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }
    emit(AuthState(status: AuthStatus.authenticated, user: cached));

    try {
      final fresh = await _repository.getProfile();
      emit(AuthState(status: AuthStatus.authenticated, user: fresh));
    } on AuthException catch (e) {
      // Token expirado → el repositorio ya limpió la sesión local.
      debugPrint('[AUTH] Refresco de sesión falló: $e');
      final stillLogged = await _repository.isLoggedIn;
      if (!stillLogged) {
        emit(const AuthState(status: AuthStatus.unauthenticated));
      }
      // Si sigue logueado (p. ej. error de red), conservamos el usuario cacheado.
    }
  }

  Future<Usuario> login(String correo, String password) async {
    final user = await _repository.login(correo, password);
    emit(AuthState(status: AuthStatus.authenticated, user: user));
    return user;
  }

  Future<Usuario> register({
    required String nombre,
    required String apellido,
    required String correo,
    required String password,
    required String passwordConfirmation,
  }) async {
    final user = await _repository.register(
      nombre: nombre,
      apellido: apellido,
      correo: correo,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
    emit(AuthState(status: AuthStatus.authenticated, user: user));
    return user;
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
