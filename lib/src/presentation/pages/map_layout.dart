import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/preview_mocks.dart';
import '../../data/repositories/map_repository_impl.dart';
import '../../domain/repositories/map_repository.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../widgets/offline_map_view.dart';

class MapLayout extends StatelessWidget {
  const MapLayout({
    super.key,
    required this.child,
    this.appBar,
    this.mapRepository,
    this.mapBuilder,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final MapRepository? mapRepository;
  final Widget Function(BuildContext context, String styleString)? mapBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MapBloc(repository: mapRepository ?? MapRepositoryImpl())
        ..add(const MapPrepareRequested()),
      child: Scaffold(
        appBar: appBar,
        body: Stack(
          children: [
            // El mapa siempre al fondo
            _MapBackground(mapBuilder: mapBuilder),
            // El contenido de la página encima
            child,
          ],
        ),
      ),
    );
  }
}

class _MapBackground extends StatelessWidget {
  const _MapBackground({this.mapBuilder});

  final Widget Function(BuildContext context, String styleString)? mapBuilder;

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
          if (mapBuilder != null) {
            return mapBuilder!(context, state.styleString);
          }
          // La key depende del styleString: solo cambia cuando se reconstruye
          // el servidor local (nuevo puerto tras un resume), forzando que el
          // mapa recargue limpio. En operación normal la key no cambia.
          return OfflineMapView(
            key: ValueKey(state.styleString),
            styleString: state.styleString,
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

@Preview(name: 'Map Layout with Mock Map')
Widget previewMapLayout() {
  return MapLayout(
    mapRepository: MockMapRepository(),
    mapBuilder: (context, styleString) => MockMapView(styleString: styleString),
    child: const Center(
      child: Card(
        color: Colors.black54,
        margin: EdgeInsets.all(20),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Contenido superpuesto en el mapa',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    ),
  );
}
