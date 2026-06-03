import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/app_database_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../bloc/auth_cubit.dart';
import '../../domain/models/usuario.dart';
import 'login_page.dart';
import 'register_page.dart';

// ── User Page Widget ─────────────────────────────────────────────────────────

/// Pestaña de Perfil. Se apoya en el [AuthCubit] provisto en `RootPage`:
/// muestra los datos reales del usuario autenticado o un estado de invitado con
/// acceso a las pantallas de inicio de sesión y creación de cuenta.
class UserPage extends StatelessWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfileView();
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state.status == AuthStatus.unknown) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF4C025)),
            );
          }

          final autenticado = state.status == AuthStatus.authenticated &&
              state.user != null;

          return SafeArea(
            child: Column(
              children: [
                const _Header(),
                Expanded(
                  child: SingleChildScrollView(
                    child: autenticado
                        ? Column(
                            children: [
                              _ProfileCard(user: state.user!),
                              const _SettingsSection(),
                            ],
                          )
                        : const _GuestCard(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'Mi Perfil',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estado invitado (sin sesión) ─────────────────────────────────────────────

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  void _abrirLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AuthCubit>(),
          child: const LoginPage(),
        ),
      ),
    );
  }

  void _abrirRegistro(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AuthCubit>(),
          child: const RegisterPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded,
                size: 48, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No has iniciado sesión',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Inicia sesión o crea una cuenta para personalizar tu experiencia en Rutikal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _abrirLogin(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4C025),
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Iniciar sesión',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => _abrirRegistro(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Crear cuenta',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile card: avatar + nombre + email + botones ──────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final Usuario user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 8),
      child: Column(
        children: [
          // Avatar con borde amarillo y badge de edición
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFEF9E7),
                  border: Border.all(color: const Color(0xFFF4C025), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1AF4C025),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.iniciales,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFCA9A04),
                    ),
                  ),
                ),
              ),
              // Badge de edición
              Positioned(
                bottom: 4,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4C025),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.edit_rounded,
                        size: 13, color: Color(0xFF0F172A)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Nombre
          Text(
            user.nombreCompleto.isEmpty ? 'Usuario' : user.nombreCompleto,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: -0.6,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          // Email
          Text(
            user.correo,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          if (user.tipoUsuarioNombre != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                user.tipoUsuarioNombre!,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Settings section ──────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  Future<void> _confirmarCerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        content: const Text(
          '¿Seguro que quieres cerrar tu sesión?',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Cerrar sesión',
                style: TextStyle(
                    color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      await context.read<AuthCubit>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado de sección
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'AJUSTES Y CUENTA',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.1,
                height: 1.5,
              ),
            ),
          ),
          // Items
          Column(
            children: [
              _SettingsItem(
                icon: Icons.settings_outlined,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF475569),
                title: 'Configuración del sistema',
                subtitle: 'Notificaciones, privacidad y más',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.history_rounded,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF475569),
                title: 'Historial de viajes',
                subtitle: 'Tus rutas y destinos pasados',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.help_outline_rounded,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF475569),
                title: 'Ayuda',
                subtitle: 'Soporte técnico y preguntas frecuentes',
                onTap: () {},
              ),
              // Divisor
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                    color: Color(0xFFF1F5F9), thickness: 1, height: 1),
              ),
              // Cerrar sesión
              _SettingsItem(
                icon: Icons.logout_rounded,
                iconBg: const Color(0xFFFEF2F2),
                iconColor: const Color(0xFFEF4444),
                title: 'Cerrar sesión',
                titleColor: const Color(0xFFEF4444),
                showChevron: false,
                onTap: () => _confirmarCerrarSesion(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Settings item ─────────────────────────────────────────────────────────────

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String? subtitle;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.titleColor = const Color(0xFF0F172A),
    this.subtitle,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            // Ícono con fondo
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ),
            const SizedBox(width: 16),
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                      height: 1.5,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                        height: 1.333,
                      ),
                    ),
                ],
              ),
            ),
            // Chevron
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
          ],
        ),
      ),
    );
  }
}

// Previsualización oficial para VS Code
@Preview(name: 'User Page')
Widget previewUser() => BlocProvider(
      create: (_) => AuthCubit(
        repository: AuthRepository(dbService: AppDatabaseService()),
      )..loadSession(),
      child: const UserPage(),
    );
