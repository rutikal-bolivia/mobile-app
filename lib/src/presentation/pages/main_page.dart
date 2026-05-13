import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/search_repository_impl.dart';
import '../../domain/repositories/location_repository.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../bloc/search_bloc.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/map_buttons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../bloc/routing_bloc.dart';
import '../bloc/routing_event.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => SearchBloc(
            repository: SearchRepositoryImpl(),
          ),
        ),
        BlocProvider(
          create: (context) => LocationBloc(
            repository: LocationRepositoryImpl(),
          )..add(LocationStarted()),
        ),
      ],
      child: const _MainPageContent(),
    );
  }
}

class _MainPageContent extends StatelessWidget {
  const _MainPageContent();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Área superior: Buscador y Botón de Marcador
        Positioned(
          top: 50,
          left: 15,
          right: 15,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: SearchBarWidget(),
              ),
              const SizedBox(width: 10),
              AddMarkerButton(
                onPressed: () {
                  context.read<MapBloc>().add(const MapAddMarkerAtCenterRequested());
                },
              ),
            ],
          ),
        ),

        // Botones de control (Zoom + Ubicación)
        Positioned(
          bottom: 100,
          right: 15,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ZoomInButton(
                onPressed: () => context.read<MapBloc>().add(const MapZoomInRequested()),
              ),
              const SizedBox(height: 10),
              ZoomOutButton(
                onPressed: () => context.read<MapBloc>().add(const MapZoomOutRequested()),
              ),
              const SizedBox(height: 20),
              BlocListener<LocationBloc, LocationState>(
                listener: (context, state) {
                  if (state is LocationFailure) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.message)),
                    );
                  }
                },
                child: MyLocationButton(
                  onPressed: () {
                    final locationState = context.read<LocationBloc>().state;
                    if (locationState is LocationSuccess) {
                      final pos = locationState.position;
                      context.read<MapBloc>().add(
                            MapMoveCameraRequested(LatLng(pos.latitude, pos.longitude)),
                          );
                    } else {
                      context.read<LocationBloc>().add(LocationRequested());
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // Área inferior: Botón de Routing (Solo si hay marcador)
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: BlocBuilder<MapBloc, MapState>(
            builder: (context, state) {
              if (state is! MapReady || state.markerCoordinate == null) {
                return const SizedBox.shrink();
              }

              return Center(
                child: RoutingButton(
                  onPressed: () {
                    final locationState = context.read<LocationBloc>().state;
                    final mapState = state; 

                    if (locationState is LocationSuccess) {
                      final pos = locationState.position;
                      context.read<RoutingBloc>().add(
                            CalculateRouteRequested(
                              origin: LatLng(pos.latitude, pos.longitude),
                              destination: mapState.markerCoordinate!,
                            ),
                          );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ubicación de usuario no disponible')),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
