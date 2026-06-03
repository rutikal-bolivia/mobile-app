import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/datasources/app_database_service.dart';
import '../../data/repositories/content_repository.dart';
import '../../domain/models/alerta.dart';
import '../../domain/models/noticia.dart';
import '../widgets/app_header_widget.dart';
import '../widgets/news_card_large_widget.dart';
import '../widgets/news_card_small_widget.dart';

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
  });

  final List<Noticia> noticias;
  final List<Alerta> alertas;
  final bool isFromCache;

  @override
  List<Object?> get props => [noticias, alertas, isFromCache];
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

  Future<void> _fetch(Emitter<HomeState> emit) async {
    final noticiaResult = await _contentRepository.getNoticias();
    final alertaResult = await _contentRepository.getAlertas();

    emit(HomeLoaded(
      noticias: noticiaResult.items,
      alertas: alertaResult.items,
      isFromCache: noticiaResult.isFromCache || alertaResult.isFromCache,
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

          return SafeArea(
            child: Column(
              children: [
                AppHeaderWidget(
                  onMenuTap: () {},
                  onNotificationTap: () {},
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
          imageUrl: primera.imagen ?? '',
          title: primera.titulo,
          description: primera.descripcion ?? '',
          timeAgo: _timeAgo(primera.fechaPublicacion),
          onReadMore: () {},
        ),
        ...resto.map((n) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: NewsCardSmallWidget(
                imageUrl: n.imagen ?? '',
                title: n.titulo,
                description: n.descripcion ?? '',
                date: _timeAgo(n.fechaPublicacion),
                onTap: () {},
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
