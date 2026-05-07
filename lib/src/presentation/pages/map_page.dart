import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/map_repository_impl.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../widgets/offline_map_view.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MapBloc(repository: MapRepositoryImpl())
        ..add(const MapPrepareRequested()),
      child: const _MapScaffold(),
    );
  }
}

class _MapScaffold extends StatelessWidget {
  const _MapScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navegación Offline')),
      body: BlocBuilder<MapBloc, MapState>(
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
      ),
    );
  }
}
