import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/preview_mocks.dart';
import '../../data/datasources/app_database_service.dart';
import '../../data/repositories/routes_repository_impl.dart';
import '../../domain/repositories/routes_repository.dart';
import '../bloc/routes_bloc.dart';
import '../widgets/route_card_widget.dart';
import 'route_detail_page.dart';

class RoutesPage extends StatelessWidget {
  const RoutesPage({super.key, this.routesRepository});

  final RoutesRepository? routesRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoutesBloc(
        repository: routesRepository ?? RoutesRepositoryImpl(dbService: AppDatabaseService()),
      )..add(const RoutesLoadRequested()),
      child: const _RoutesView(),
    );
  }
}

class _RoutesView extends StatefulWidget {
  const _RoutesView();

  @override
  State<_RoutesView> createState() => _RoutesViewState();
}

class _RoutesViewState extends State<_RoutesView> {
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LocalRoute> _filter(List<LocalRoute> source) {
    if (_query.isEmpty) return source;
    final q = _query.toLowerCase();
    return source.where((r) {
      final nameMatches = r.nombre.toLowerCase().contains(q);
      final descMatches = (r.descripcion ?? '').toLowerCase().contains(q) ||
          (r.nombreIda ?? '').toLowerCase().contains(q);
      final codeMatches = r.id.toString().contains(q);
      return nameMatches || descMatches || codeMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<RoutesBloc, RoutesState>(
        builder: (context, state) {
          if (state is RoutesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF4C025)),
            );
          }
          if (state is RoutesError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error cargando rutas: ${state.message}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          List<LocalRoute> pumaSource = [];
          List<LocalRoute> teleSource = [];

          if (state is RoutesLoaded) {
            pumaSource = state.pumaRoutes;
            teleSource = state.teleRoutes;
          }

          final activeList = _selectedTab == 0 ? pumaSource : teleSource;
          final filteredList = _filter(activeList);

          return SafeArea(
            child: Column(
              children: [
                _Header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _SearchBar(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                _TabSelector(
                  selectedIndex: _selectedTab,
                  onTabSelected: (i) => setState(() {
                    _selectedTab = i;
                    _query = '';
                    _searchController.clear();
                  }),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFFF4C025),
                    onRefresh: () async {
                      context.read<RoutesBloc>().add(const RoutesLoadRequested());
                      await Future.delayed(const Duration(milliseconds: 600));
                    },
                    child: _RoutesList(
                      routes: filteredList,
                      tab: _selectedTab,
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

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(25, 10, 20, 11),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Rutas',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                height: 1.25,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: const Icon(
              Icons.filter_list_rounded,
              size: 22,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.search_rounded, size: 20, color: Color(0xFF9CA3AF)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
              decoration: const InputDecoration(
                hintText: 'Buscar rutas o líneas...',
                hintStyle: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF9CA3AF),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab selector ─────────────────────────────────────────────────────────────

class _TabSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const _TabSelector({required this.selectedIndex, required this.onTabSelected});

  static const _tabs = ['Pumakatari', 'Teleférico'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final isSelected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onTabSelected(i),
            child: Container(
              margin: EdgeInsets.only(right: i < _tabs.length - 1 ? 16 : 0),
              padding: const EdgeInsets.only(bottom: 14, top: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? const Color(0xFFF4C025) : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                _tabs[i],
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF3D2B1F) : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Routes list ──────────────────────────────────────────────────────────────

class _RoutesList extends StatelessWidget {
  final List<LocalRoute> routes;
  final int tab;

  const _RoutesList({required this.routes, required this.tab});

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron rutas',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            color: Color(0xFF9CA3AF),
          ),
        ),
      );
    }

    final label = tab == 0 ? 'PumaKatari' : 'Teleférico';

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      itemCount: routes.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rutas $label',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3D2B1F),
                    height: 1.5,
                  ),
                ),
                Text(
                  '${routes.length} Rutas',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          );
        }

        final r = routes[index - 1];

        // Formatear el código de ruta
        final String routeCode = tab == 0
            ? 'PU-${r.id}'
            : 'TF-${r.id}';

        // Formatear la descripción
        final String routeDesc = r.descripcion ?? r.nombreIda ?? 'Línea de transporte';

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RouteCardWidget(
            routeName: r.nombre,
            routeCode: routeCode,
            routeDescription: routeDesc,
            colorHex: r.color,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RouteDetailPage(route: r),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Previsualización oficial ──────────────────────────────────────────────────

@Preview(name: 'Routes Page')
Widget previewRoutes() {
  return RoutesPage(
    routesRepository: MockRoutesRepository(),
  );
}
