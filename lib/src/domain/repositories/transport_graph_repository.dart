import '../models/graph_build_config.dart';
import '../models/transport_graph.dart';

abstract class TransportGraphRepository {
  Future<GrafoTransporte> rebuildAfterSync(ContextoServicio contexto);
}
