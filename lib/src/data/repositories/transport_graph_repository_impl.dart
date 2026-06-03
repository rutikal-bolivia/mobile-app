import '../../domain/models/graph_build_config.dart';
import '../../domain/models/transport_graph.dart';
import '../../domain/repositories/transport_graph_repository.dart';
import '../datasources/transport_graph_data_source.dart';
import 'graph_builder.dart';

class TransportGraphRepositoryImpl implements TransportGraphRepository {
  final TransportGraphDataSource dataSource;
  final GraphBuilder builder;

  const TransportGraphRepositoryImpl({
    required this.dataSource,
    this.builder = const GraphBuilder(),
  });

  @override
  Future<GrafoTransporte> rebuildAfterSync(ContextoServicio contexto) async {
    final snapshot = await dataSource.cargarSnapshot();
    return builder.construir(snapshot, contexto);
  }
}
