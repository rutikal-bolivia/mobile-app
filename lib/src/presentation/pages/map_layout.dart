import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/map_repository_impl.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../widgets/offline_map_view.dart';

class MapLayout extends StatelessWidget {
  const MapLayout({
    super.key,
    required this.child,
    this.appBar,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MapBloc(repository: MapRepositoryImpl())
        ..add(const MapPrepareRequested()),
      child: Scaffold(
        appBar: appBar,
        body: Stack(
          children: [
            // El mapa siempre al fondo
            const _MapBackground(),
            // El contenido de la página encima
            child,
          ],
        ),
      ),
    );
  }
}

class _MapBackground extends StatelessWidget {
  const _MapBackground();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapBloc, MapState>(
      buildWhen: (previous, current) => 
          current is MapFailure || current is MapReady || current is MapPreparing,
      builder: (context, state) {
        if (state is MapFailure) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                state.message,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (state is MapReady) {
          return OfflineMapView(styleString: state.styleString);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
