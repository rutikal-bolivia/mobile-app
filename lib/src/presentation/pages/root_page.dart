import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/app_database_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/conectividad_cubit.dart';
import '../bloc/navigation_cubit.dart';
import '../bloc/routing_bloc.dart';
import '../bloc/routing_event.dart';
import '../bloc/routing_state.dart';
import '../bloc/sync_cubit.dart';
import '../widgets/conectividad_badge.dart';
import 'favorites_page.dart';
import 'home_page.dart';
import 'main_page.dart';
import 'routes_page.dart';
import 'user_page.dart';
import 'map_layout.dart';

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ConnectividadCubit()),
        BlocProvider(create: (context) => NavigationCubit()),
        BlocProvider(
          create: (context) => RoutingBloc()..add(InitializeRouting()),
        ),
        BlocProvider(
          lazy: false,
          create: (context) =>
              SyncCubit(dbService: AppDatabaseService())..synchronize(),
        ),
        BlocProvider(
          create: (context) => AuthCubit(
            repository: AuthRepository(dbService: AppDatabaseService()),
          )..loadSession(),
        ),
      ],
      child: const _RootPageContent(),
    );
  }
}

class _RootPageContent extends StatelessWidget {
  const _RootPageContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationCubit, int>(
      builder: (context, currentIndex) {
        return Stack(
          children: [
            Scaffold(
              body: IndexedStack(
                index: currentIndex,
                children: const [
                  HomePage(),
                  MapLayout(child: MainPage()),
                  RoutesPage(),
                  FavoritesPage(),
                  UserPage(),
                ],
              ),
              bottomNavigationBar: BlocBuilder<RoutingBloc, RoutingState>(
                builder: (context, routingState) {
                  if (currentIndex == 1 &&
                      _ocultarNavegacionPorRuta(routingState)) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: BottomNavigationBar(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      currentIndex: currentIndex,
                      onTap: (index) =>
                          context.read<NavigationCubit>().changeTab(index),
                      type: BottomNavigationBarType.fixed,
                      selectedItemColor: const Color(0xFFF3C03F),
                      unselectedItemColor: const Color(0xFF637381),
                      selectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      iconSize: 28,
                      items: const [
                        BottomNavigationBarItem(
                          icon: Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Icon(Icons.home_outlined),
                          ),
                          label: 'Inicio',
                        ),
                        BottomNavigationBarItem(
                          icon: Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Icon(Icons.map_outlined),
                          ),
                          label: 'Mapa',
                        ),
                        BottomNavigationBarItem(
                          icon: Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Icon(Icons.route_outlined),
                          ),
                          label: 'Rutas',
                        ),
                        BottomNavigationBarItem(
                          icon: Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Icon(Icons.favorite_border),
                          ),
                          label: 'Favoritos',
                        ),
                        BottomNavigationBarItem(
                          icon: Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Icon(Icons.person_outline),
                          ),
                          label: 'Perfil',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Badge flotante de conectividad
            const Positioned(
              top: 0,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(top: 88),
                  child: ConectividadBadge(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

bool _ocultarNavegacionPorRuta(RoutingState state) {
  if (state is RoutingSearching || state is RoutingOptionsFound) return true;
  return state is RoutingSuccess && state.resultadoMultimodal != null;
}

// Previsualización oficial para VS Code
@Preview(name: 'Bottom Navigation Bar')
Widget previewNavBar() {
  return const RootPage();
}
