import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/app_config.dart';
import '../../data/datasources/app_database_service.dart';
import '../../data/repositories/content_repository.dart';
import '../../domain/models/alerta.dart';
import '../../domain/models/noticia.dart';
import '../widgets/app_header_widget.dart';
import '../widgets/news_card_large_widget.dart';
import '../widgets/news_card_small_widget.dart';
import 'noticia_detail_page.dart';
import 'notifications_page.dart';

// ── Eventos ──────────────────────────────────────────────────────────────────

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class HomeLoadRequested extends HomeEvent {
  const HomeLoadRequested();
}

class HomeRefreshRequested extends HomeEvent {
  const HomeRefreshRequested();
}

/// El usuario abrió la bandeja de notificaciones: persistimos la marca de
/// tiempo y reseteamos el contador de no leídas.
class HomeNotificationsSeen extends HomeEvent {
  const HomeNotificationsSeen();
}

// ── Estados ───────────────────────────────────────────────────────────────────

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  const HomeLoaded({
    required this.noticias,
    required this.alertas,
    this.isFromCache = false,
    this.vistoEn,
    this.unreadCount = 0,
  });

  final List<Noticia> noticias;
  final List<Alerta> alertas;
  final bool isFromCache;

  /// Marca de tiempo de la última revisión de notificaciones.
  final DateTime? vistoEn;

  /// Cantidad de noticias/alertas posteriores a [vistoEn].
  final int unreadCount;

  HomeLoaded copyWith({
    List<Noticia>? noticias,
    List<Alerta>? alertas,
    bool? isFromCache,
    DateTime? vistoEn,
    int? unreadCount,
  }) =>
      HomeLoaded(
        noticias: noticias ?? this.noticias,
        alertas: alertas ?? this.alertas,
        isFromCache: isFromCache ?? this.isFromCache,
        vistoEn: vistoEn ?? this.vistoEn,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  @override
  List<Object?> get props =>
      [noticias, alertas, isFromCache, vistoEn, unreadCount];
}

class HomeError extends HomeState {
  const HomeError({required this.message});
  final String message;
  @override
  List<Object?> get props => [message];
}

// ── Bloc ─────────────────────────────────────────────────────────────────────

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required ContentRepository contentRepository})
      : _contentRepository = contentRepository,
        super(const HomeInitial()) {
    on<HomeLoadRequested>(_onLoad);
    on<HomeRefreshRequested>(_onRefresh);
    on<HomeNotificationsSeen>(_onNotificationsSeen);
  }

  final ContentRepository _contentRepository;

  Future<void> _onLoad(HomeLoadRequested event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());
    await _fetch(emit);
  }

  Future<void> _onRefresh(
      HomeRefreshRequested event, Emitter<HomeState> emit) async {
    // Mantiene datos visibles durante el refresco
    await _fetch(emit);
  }

  Future<void> _onNotificationsSeen(
      HomeNotificationsSeen event, Emitter<HomeState> emit) async {
    final ahora = DateTime.now();
    await _contentRepository.marcarNotificacionesVistas(ahora);
    final state = this.state;
    if (state is HomeLoaded) {
      emit(state.copyWith(vistoEn: ahora, unreadCount: 0));
    }
  }

  /// Cuenta cuántas noticias/alertas tienen una fecha posterior a [vistoEn].
  int _contarNoLeidas(
    List<Noticia> noticias,
    List<Alerta> alertas,
    DateTime? vistoEn,
  ) {
    final fechasNoticias =
        noticias.map((n) => n.fechaPublicacion ?? n.updatedAt);
    final fechasAlertas = alertas.map((a) => a.fechaInicio ?? a.updatedAt);
    final fechas = [...fechasNoticias, ...fechasAlertas].whereType<DateTime>();
    // Primera apertura (sin marca previa): todo el contenido cuenta como nuevo,
    // consistente con cómo NotificationsPage resalta los elementos.
    if (vistoEn == null) return fechas.length;
    return fechas.where((f) => f.isAfter(vistoEn)).length;
  }

  Future<void> _fetch(Emitter<HomeState> emit) async {
    final noticiaResult = await _contentRepository.getNoticias();
    final alertaResult = await _contentRepository.getAlertas();
    final vistoEn = await _contentRepository.getNotificacionesVistoEn();

    emit(HomeLoaded(
      noticias: noticiaResult.items,
      alertas: alertaResult.items,
      isFromCache: noticiaResult.isFromCache || alertaResult.isFromCache,
      vistoEn: vistoEn,
      unreadCount: _contarNoLeidas(
        noticiaResult.items,
        alertaResult.items,
        vistoEn,
      ),
    ));
  }
}

// ── Página ────────────────────────────────────────────────────────────────────

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc(
        contentRepository: ContentRepository(dbService: AppDatabaseService()),
      )..add(const HomeLoadRequested()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF4C025)),
            );
          }

          final noticias = state is HomeLoaded ? state.noticias : <Noticia>[];
          final alertas = state is HomeLoaded ? state.alertas : <Alerta>[];
          final isFromCache = state is HomeLoaded && state.isFromCache;
          final unreadCount = state is HomeLoaded ? state.unreadCount : 0;
          final vistoEn = state is HomeLoaded ? state.vistoEn : null;

          return SafeArea(
            child: Column(
              children: [
                AppHeaderWidget(
                  onMenuTap: () {},
                  unreadCount: unreadCount,
                  onNotificationTap: () {
                    final bloc = context.read<HomeBloc>();
                    bloc.add(const HomeNotificationsSeen());
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationsPage(
                          noticias: noticias,
                          alertas: alertas,
                          vistoEn: vistoEn,
                        ),
                      ),
                    );
                  },
                ),
                if (isFromCache)
                  _OfflineBanner(),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFFF4C025),
                    onRefresh: () async {
                      context
                          .read<HomeBloc>()
                          .add(const HomeRefreshRequested());
                      await Future.delayed(const Duration(milliseconds: 600));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 17),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (alertas.isNotEmpty) ...[
                            _AlertasSection(alertas: alertas),
                            const SizedBox(height: 17),
                          ],
                          _NoticiasSection(noticias: noticias),
                          const SizedBox(height: 17),
                        ],
                      ),
                    ),
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

// ── Sección alertas ───────────────────────────────────────────────────────────

class _AlertasSection extends StatelessWidget {
  const _AlertasSection({required this.alertas});
  final List<Alerta> alertas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Avisos y alertas',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        ...alertas.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AlertaCard(alerta: a),
            )),
      ],
    );
  }
}

class _AlertaCard extends StatelessWidget {
  const _AlertaCard({required this.alerta});
  final Alerta alerta;

  static const _severidadColor = {
    'alta': Color(0xFFDC2626),
    'media': Color(0xFFD97706),
    'baja': Color(0xFF2563EB),
  };

  static const _tipoIcono = {
    'cierre': Icons.block_rounded,
    'retraso': Icons.schedule_rounded,
    'mantenimiento': Icons.build_rounded,
    'informativa': Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color =
        _severidadColor[alerta.severidad] ?? const Color(0xFF2563EB);
    final icono =
        _tipoIcono[alerta.tipo] ?? Icons.info_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerta.titulo,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (alerta.descripcion != null &&
                    alerta.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    alerta.descripcion!,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sección noticias ──────────────────────────────────────────────────────────

class _NoticiasSection extends StatelessWidget {
  const _NoticiasSection({required this.noticias});
  final List<Noticia> noticias;

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _abrirNoticia(BuildContext context, Noticia noticia) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoticiaDetailPage(noticia: noticia),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (noticias.isEmpty) {
      return const _EmptySection(mensaje: 'No hay noticias disponibles.');
    }

    final primera = noticias.first;
    final resto = noticias.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Noticias',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF000000),
            letterSpacing: -0.5,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        NewsCardLargeWidget(
          imageUrl: AppConfig.mediaUrl(primera.imagen),
          title: primera.titulo,
          description: primera.descripcion ?? '',
          timeAgo: _timeAgo(primera.fechaPublicacion),
          onReadMore: () => _abrirNoticia(context, primera),
        ),
        ...resto.map((n) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: NewsCardSmallWidget(
                imageUrl: AppConfig.mediaUrl(n.imagen),
                title: n.titulo,
                description: n.descripcion ?? '',
                date: _timeAgo(n.fechaPublicacion),
                onTap: () => _abrirNoticia(context, n),
              ),
            )),
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 15, color: Color(0xFF92400E)),
          SizedBox(width: 6),
          Text(
            'Mostrando contenido guardado — sin conexión',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          mensaje,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}

// Previsualización oficial para VS Code
@Preview(name: 'Home Page')
Widget previewHome() => const HomePage();
