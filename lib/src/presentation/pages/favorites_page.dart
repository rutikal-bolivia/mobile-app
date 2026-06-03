import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/app_database_service.dart';
import '../../data/repositories/favorites_repository_impl.dart';
import '../../domain/repositories/routes_repository.dart';
import '../bloc/favorites_bloc.dart';
import '../bloc/favorites_event.dart';
import '../bloc/favorites_state.dart';
import '../widgets/tab_selector_widget.dart';
import '../widgets/focus_button_widget.dart';
import '../widgets/puma_route_card_widget.dart';
import 'route_detail_page.dart';

// ── Datos de ejemplo ────────────────────────────────────────────────────────

class _SuggestionItem {
  final String title;
  final String subtitle;
  final int id;
  const _SuggestionItem(this.id, this.title, this.subtitle);
}

const _suggestedRoutes = [
  _SuggestionItem(1, 'Inca Llojeta - Centro',      'Basado en tus viajes recientes'),
  _SuggestionItem(2, 'Villa Salomé - Sopocachi',   'Ruta popular cerca de ti'),
  _SuggestionItem(3, 'Achumani - Camacho',         'Basado en tus viajes recientes'),
];

const _suggestedStops = [
  _SuggestionItem(1, 'Parada Camacho',             'Parada más cercana a ti'),
  _SuggestionItem(2, 'Parada El Prado',            'Muy frecuentada en tu zona'),
  _SuggestionItem(3, 'Parada Plaza Triangular',    'Basado en tus viajes recientes'),
];

// ── Page ────────────────────────────────────────────────────────────────────

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FavoritesBloc(
        repository: FavoritesRepositoryImpl(dbService: AppDatabaseService()),
      )..add(const FavoritesLoadRequested()),
      child: const _FavoritesView(),
    );
  }
}

class _FavoritesView extends StatefulWidget {
  const _FavoritesView();

  @override
  State<_FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<_FavoritesView> {
  int _selectedTab = 0; // 0 = Rutas Favoritas, 1 = Paradas Favoritas

  List<_SuggestionItem> get _suggestions =>
      _selectedTab == 0 ? _suggestedRoutes : _suggestedStops;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<FavoritesBloc, FavoritesState>(
        builder: (context, state) {
          if (state is FavoritesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF4C025)),
            );
          }
          if (state is FavoritesError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          List<LocalRoute> favRoutes = [];
          List<RouteStop> favStops = [];

          if (state is FavoritesLoaded) {
            favRoutes = state.favoriteRoutes;
            favStops = state.favoriteStops;
          }

          final hasItems = _selectedTab == 0 ? favRoutes.isNotEmpty : favStops.isNotEmpty;

          return SafeArea(
            child: Column(
              children: [
                // ── Header ────────────────────────────────────────────────
                _Header(
                  selectedTab: _selectedTab,
                  onTabSelected: (i) => setState(() => _selectedTab = i),
                ),
                // ── Body ──────────────────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFFF4C025),
                    onRefresh: () async {
                      context
                          .read<FavoritesBloc>()
                          .add(const FavoritesLoadRequested());
                      await Future.delayed(const Duration(milliseconds: 600));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: hasItems
                          ? _buildFavoritesList(favRoutes, favStops)
                          : _buildEmptyState(),
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

  Widget _buildFavoritesList(List<LocalRoute> routes, List<RouteStop> stops) {
    if (_selectedTab == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tus rutas guardadas',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3D2B1F),
                ),
              ),
              Text(
                '${routes.length} Guardadas',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final r = routes[index];
              final routeCode = r.transporteId == 2 ? 'TF-${r.id}' : 'PU-${r.id}';
              final routeDesc = r.descripcion ?? r.nombreIda ?? 'Ruta de transporte';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    PumaRouteCardWidget(
                      routeName: r.nombre,
                      routeCode: routeCode,
                      routeDescription: routeDesc,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RouteDetailPage(route: r),
                          ),
                        );
                        if (context.mounted) {
                          context.read<FavoritesBloc>().add(const FavoritesLoadRequested());
                        }
                      },
                    ),
                    Positioned(
                      right: 40,
                      child: GestureDetector(
                        onTap: () {
                          context.read<FavoritesBloc>().add(
                            FavoriteRemoved(tipo: 'ruta', referenciaId: r.id),
                          );
                        },
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF4C025),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tus paradas guardadas',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3D2B1F),
                ),
              ),
              Text(
                '${stops.length} Guardadas',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final s = stops[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4C025).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.place_rounded,
                            color: Color(0xFFF4C025),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.nombre,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3D2B1F),
                              ),
                            ),
                            if (s.direccion != null && s.direccion!.isNotEmpty)
                              Text(
                                s.direccion!,
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          context.read<FavoritesBloc>().add(
                            FavoriteRemoved(tipo: 'parada', referenciaId: s.id),
                          );
                        },
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF4C025),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
    }
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        // ── Empty state illustration ───────────────────
        _EmptyStateIllustration(tab: _selectedTab),
        const SizedBox(height: 32),
        // ── Empty state text ──────────────────────────
        _EmptyStateText(tab: _selectedTab),
        const SizedBox(height: 32),
        // ── CTA button ────────────────────────────────
        FocusButtonWidget(
          label: _selectedTab == 0
              ? 'Buscar rutas'
              : 'Buscar paradas',
          icon: Icons.search_rounded,
          size: FocusButtonSize.large,
          onTap: () {},
        ),
        const SizedBox(height: 48),
        // ── Suggestions section ───────────────────────
        _SuggestionsSection(
          suggestions: _suggestions,
          tab: _selectedTab,
        ),
      ],
    );
  }
}

// ── Header con título y tabs ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabSelected;

  const _Header({required this.selectedTab, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFF4C025).withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Título
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Favoritos',
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
          ),
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TabSelectorWidget(
                    tabs: const ['Rutas Favoritas', 'Paradas Favoritas'],
                    selectedIndex: selectedTab,
                    onTabSelected: onTabSelected,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state illustration ─────────────────────────────────────────────────

class _EmptyStateIllustration extends StatelessWidget {
  final int tab;
  const _EmptyStateIllustration({required this.tab});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fondo amarillo difuminado
          Container(
            decoration: const BoxDecoration(
              color: Color(0x1AF4C025),
              shape: BoxShape.circle,
            ),
          ),
          // Círculo central amarillo claro
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFF4C025).withOpacity(0.25),
              shape: BoxShape.circle,
            ),
          ),
          // Ícono principal
          Icon(
            tab == 0
                ? Icons.star_border_rounded
                : Icons.place_outlined,
            size: 80,
            color: const Color(0xFFF4C025),
          ),
          // Badge pequeño en esquina superior derecha
          Positioned(
            top: 60,
            right: 55,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.route_outlined,
                  size: 18,
                  color: Color(0xFFF4C025),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state text ─────────────────────────────────────────────────────────

class _EmptyStateText extends StatelessWidget {
  final int tab;
  const _EmptyStateText({required this.tab});

  @override
  Widget build(BuildContext context) {
    final title = tab == 0
        ? 'No tienes rutas favoritas'
        : 'No tienes paradas favoritas';
    final subtitle = tab == 0
        ? 'Guarda tus rutas más frecuentes para\nacceder a ellas rápidamente desde aquí.'
        : 'Guarda tus paradas habituales para\nacceder a ellas rápidamente desde aquí.';

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 11),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
            height: 1.625,
          ),
        ),
      ],
    );
  }
}

// ── Suggestions section ───────────────────────────────────────────────────────

class _SuggestionsSection extends StatelessWidget {
  final List<_SuggestionItem> suggestions;
  final int tab;

  const _SuggestionsSection({required this.suggestions, required this.tab});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sugerencias para ti',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.45,
            height: 1.555,
          ),
        ),
        const SizedBox(height: 16),
        ...suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SuggestionCard(id: s.id, title: s.title, subtitle: s.subtitle, tab: tab),
          ),
        ),
      ],
    );
  }
}

// ── Suggestion card ───────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final int id;
  final String title;
  final String subtitle;
  final int tab;

  const _SuggestionCard({required this.id, required this.title, required this.subtitle, required this.tab});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícono
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF4C025).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                tab == 0 ? Icons.directions_bus_rounded : Icons.place_rounded,
                size: 22,
                color: const Color(0xFFF4C025),
              ),
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
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.428,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                    height: 1.333,
                  ),
                ),
              ],
            ),
          ),
          // Botón guardar favorito
          GestureDetector(
            onTap: () {
              final tipo = tab == 0 ? 'ruta' : 'parada';
              context.read<FavoritesBloc>().add(
                FavoriteAdded(tipo: tipo, referenciaId: id),
              );
            },
            child: const Icon(
              Icons.star_border_rounded,
              size: 22,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

// Previsualización oficial para VS Code
@Preview(name: 'Favorites Page')
Widget previewFavorites() => const FavoritesPage();
