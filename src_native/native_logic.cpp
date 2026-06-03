#include <vector>
#include <queue>
#include <cmath>
#include <string>
#include <algorithm>
#include <fstream>
#include <stdint.h>
#include <cstdio>

#if defined(__GNUC__)
    #define FFI_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#else
    #define FFI_EXPORT
#endif

// Logging solo en debug: en builds Release (NDEBUG) se compila a nada.
#ifdef NDEBUG
    #define LOG(...) ((void)0)
#else
    #define LOG(...) printf(__VA_ARGS__)
#endif

static constexpr float kPi = 3.14159265358979f;
static constexpr float kEarthRadiusM = 6371000.0f;

struct Point { float lat; float lon; };
struct Edge { int32_t to; float weight; };

// Funciones de utilidad para vectores y proyección
Point subtract(Point a, Point b) { return {a.lat - b.lat, a.lon - b.lon}; }
Point add(Point a, Point b) { return {a.lat + b.lat, a.lon + b.lon}; }
Point multiply(Point a, float t) { return {a.lat * t, a.lon * t}; }

// Distancia al cuadrado
float distSq(float lat1, float lon1, float lat2, float lon2) {
    float dLat = lat1 - lat2;
    float dLon = lon1 - lon2;
    return dLat * dLat + dLon * dLon;
}

// Proyecta el punto p sobre el segmento [a, b]
float pointToSegmentDistSq(Point p, Point a, Point b, Point &outProj) {
    Point ab = subtract(b, a);
    Point ap = subtract(p, a);
    float l2 = ab.lat * ab.lat + ab.lon * ab.lon;
    if (l2 == 0.0) { outProj = a; return distSq(p.lat, p.lon, a.lat, a.lon); }
    float t = (ap.lat * ab.lat + ap.lon * ab.lon) / l2;
    if (t < 0.0) { outProj = a; return distSq(p.lat, p.lon, a.lat, a.lon); }
    if (t > 1.0) { outProj = b; return distSq(p.lat, p.lon, b.lat, b.lon); }
    outProj = add(a, multiply(ab, t));
    return distSq(p.lat, p.lon, outProj.lat, outProj.lon);
}

// Estructura para la cola de prioridad de A*
struct NodeAStar {
    int32_t id;
    float priority; // f(n) = g(n) + h(n)
    bool operator>(const NodeAStar& other) const { return priority > other.priority; }
};

// Índice espacial uniforme (grid) para acelerar la búsqueda del nodo más
// cercano. Pasa de O(n) lineal a ~O(1) amortizado por consulta, que es el
// cuello de botella real del cálculo de rutas (se consulta 2 veces por ruta).
struct SpatialGrid {
    float minLat = 0.0f, minLon = 0.0f;
    float cellSize = 0.0015f; // ~150 m por celda; suficiente para una ciudad
    int cols = 0, rows = 0;
    std::vector<std::vector<int32_t>> cells;

    int clampi(int v, int hi) const { return v < 0 ? 0 : (v >= hi ? hi - 1 : v); }
    int colOf(float lon) const { return clampi((int)((lon - minLon) / cellSize), cols); }
    int rowOf(float lat) const { return clampi((int)((lat - minLat) / cellSize), rows); }

    void build(const std::vector<Point>& nodes) {
        cells.clear();
        cols = rows = 0;
        if (nodes.empty()) return;

        float maxLat = nodes[0].lat, maxLon = nodes[0].lon;
        minLat = nodes[0].lat; minLon = nodes[0].lon;
        for (const auto& n : nodes) {
            minLat = std::min(minLat, n.lat); maxLat = std::max(maxLat, n.lat);
            minLon = std::min(minLon, n.lon); maxLon = std::max(maxLon, n.lon);
        }
        cols = std::max(1, (int)((maxLon - minLon) / cellSize) + 1);
        rows = std::max(1, (int)((maxLat - minLat) / cellSize) + 1);
        cells.assign((size_t)cols * rows, {});
        for (int32_t i = 0; i < (int32_t)nodes.size(); ++i) {
            int cx = colOf(nodes[i].lon);
            int cy = rowOf(nodes[i].lat);
            cells[(size_t)cy * cols + cx].push_back(i);
        }
    }

    // Índice del nodo más cercano a (lat, lon), o -1 si el grid está vacío.
    // Busca por anillos crecientes y corta cuando el anillo ya no puede
    // contener nada más cercano que el mejor candidato encontrado.
    // Si se pasa `componentOf` y `targetComp >= 0`, solo considera nodos de esa
    // componente conexa (sirve para ignorar las "islas" desconectadas del grafo).
    int32_t nearest(const std::vector<Point>& nodes, float lat, float lon,
                    const std::vector<int32_t>* componentOf = nullptr,
                    int32_t targetComp = -1) const {
        if (cols == 0 || rows == 0) return -1;
        int qcx = colOf(lon);
        int qcy = rowOf(lat);

        int32_t best = -1;
        float bestD = INFINITY;
        int maxRing = cols + rows; // cota: cubre todo el grid

        for (int r = 0; r <= maxRing; ++r) {
            // El anillo r está a una distancia mínima de (r-1) celdas del punto;
            // si esa cota ya supera al mejor, ningún nodo igual o más lejano mejora.
            if (best != -1) {
                float ringMin = (float)(r - 1) * cellSize;
                if (ringMin > 0.0f && ringMin * ringMin > bestD) break;
            }
            bool anyCellInRange = false;
            for (int dy = -r; dy <= r; ++dy) {
                for (int dx = -r; dx <= r; ++dx) {
                    // Solo el borde del cuadrado de radio r (el anillo).
                    if (std::max(std::abs(dx), std::abs(dy)) != r) continue;
                    int cx = qcx + dx, cy = qcy + dy;
                    if (cx < 0 || cy < 0 || cx >= cols || cy >= rows) continue;
                    anyCellInRange = true;
                    for (int32_t idx : cells[(size_t)cy * cols + cx]) {
                        if (componentOf && targetComp >= 0 &&
                            (*componentOf)[idx] != targetComp) continue;
                        float d = distSq(lat, lon, nodes[idx].lat, nodes[idx].lon);
                        if (d < bestD) { bestD = d; best = idx; }
                    }
                }
            }
            // Anillo totalmente fuera del grid y ya hay candidato: no hay más.
            if (!anyCellInRange && best != -1) break;
        }
        return best;
    }
};

class Graph {
public:
    std::vector<Point> nodes;
    std::vector<std::vector<Edge>> adj;
    SpatialGrid grid;

    // Componente conexa de cada nodo + id de la componente más grande.
    // El grafo del .dat tiene "islas" desconectadas (artefactos de la limpieza
    // del OSM); snapeando a la componente principal evitamos rutas imposibles.
    std::vector<int32_t> componentOf;
    int32_t mainComponent = -1;

    struct SnappedPoint {
        Point p;
        int32_t nodeId;
    };

    // Etiqueta cada nodo con su componente conexa (union-find) y guarda la mayor.
    void computeComponents() {
        int32_t n = (int32_t)nodes.size();
        componentOf.assign(n, -1);
        if (n == 0) { mainComponent = -1; return; }

        std::vector<int32_t> parent(n);
        for (int32_t i = 0; i < n; ++i) parent[i] = i;
        auto find = [&](int32_t x) {
            while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
            return x;
        };
        for (int32_t u = 0; u < n; ++u) {
            for (const auto& e : adj[u]) {
                int32_t ru = find(u), rv = find(e.to);
                if (ru != rv) parent[ru] = rv;
            }
        }

        std::vector<int32_t> count(n, 0);
        int32_t best = -1, bestCount = -1;
        for (int32_t i = 0; i < n; ++i) {
            int32_t root = find(i);
            componentOf[i] = root;
            if (++count[root] > bestCount) { bestCount = count[root]; best = root; }
        }
        mainComponent = best;
    }

    // Encuentra el punto más cercano en los segmentos que tocan al nodo más cercano.
    // Con `restrictComponent >= 0` se limita a esa componente conexa.
    SnappedPoint snapToNearestSegment(float lat, float lon, int32_t restrictComponent = -1) {
        if (nodes.empty()) return {{0,0}, -1};

        // 1. Encontrar el nodo más cercano usando el índice espacial (O(1) amort.)
        int32_t nearestNode = grid.nearest(
            nodes, lat, lon,
            restrictComponent >= 0 ? &componentOf : nullptr, restrictComponent);
        if (nearestNode < 0) return {{0,0}, -1};
        float minDistSq = distSq(lat, lon, nodes[nearestNode].lat, nodes[nearestNode].lon);

        Point m = {lat, lon};
        Point bestProj = nodes[nearestNode];
        
        // 2. Revisar todos los segmentos conectados a ese nodo para encontrar una proyección mejor
        for (auto& edge : adj[nearestNode]) {
            Point proj;
            float d = pointToSegmentDistSq(m, nodes[nearestNode], nodes[edge.to], proj);
            if (d < minDistSq) {
                minDistSq = d;
                bestProj = proj;
            }
        }

        return {bestProj, nearestNode};
    }

    // Heurística admisible para A*: distancia haversine (línea recta sobre la
    // esfera, en metros). Como los pesos de las aristas del .dat son la
    // distancia haversine real, esta heurística nunca sobreestima el costo
    // del camino -> A* es óptimo y consistente.
    float heuristic(int32_t a, int32_t b) {
        float lat1 = nodes[a].lat * kPi / 180.0f;
        float lat2 = nodes[b].lat * kPi / 180.0f;
        float dLat = lat2 - lat1;
        float dLon = (nodes[b].lon - nodes[a].lon) * kPi / 180.0f;
        float s1 = std::sin(dLat * 0.5f);
        float s2 = std::sin(dLon * 0.5f);
        float h = s1 * s1 + std::cos(lat1) * std::cos(lat2) * s2 * s2;
        return 2.0f * kEarthRadiusM * std::asin(std::sqrt(h));
    }

    // IMPORTANTE: Faltaba esta función para leer tu archivo .dat con las coordenadas
    bool loadFromBinary(const char* path) {
        std::ifstream file(path, std::ios::binary);
        if (!file.is_open()) return false;

        int32_t nodeCount, edgeCount;
        file.read((char*)&nodeCount, sizeof(int32_t));
        file.read((char*)&edgeCount, sizeof(int32_t));
        if (!file.good() || nodeCount <= 0 || edgeCount < 0) return false;

        nodes.resize(nodeCount);
        for (int i = 0; i < nodeCount; ++i) {
            float lat, lon;
            file.read((char*)&lat, sizeof(float));
            file.read((char*)&lon, sizeof(float));
            nodes[i] = {lat, lon};
        }
        if (!file.good()) { nodes.clear(); return false; }

        adj.resize(nodeCount);
        for (int i = 0; i < edgeCount; ++i) {
            int32_t u, v;
            float dist;
            file.read((char*)&u, sizeof(int32_t));
            file.read((char*)&v, sizeof(int32_t));
            file.read((char*)&dist, sizeof(float));
            if (!file.good()) { nodes.clear(); adj.clear(); return false; }

            // Saltar aristas con índices fuera de rango (archivo corrupto)
            // en vez de indexar out-of-bounds y crashear.
            if (u < 0 || v < 0 || u >= nodeCount || v >= nodeCount) continue;

            adj[u].push_back({v, dist});
            adj[v].push_back({u, dist});
        }
        file.close();

        // Construir el índice espacial y etiquetar componentes conexas una vez.
        grid.build(nodes);
        computeComponents();
        return true;
    }

    std::string findPath(SnappedPoint start, SnappedPoint end) {
        int32_t startId = start.nodeId;
        int32_t endId = end.nodeId;

        if (startId < 0 || endId < 0 || startId >= nodes.size() || endId >= nodes.size()) 
            return "Nodos no encontrados";

        std::priority_queue<NodeAStar, std::vector<NodeAStar>, std::greater<NodeAStar>> pq;
        std::vector<float> dist(nodes.size(), INFINITY);
        std::vector<int32_t> parent(nodes.size(), -1);

        dist[startId] = 0;
        pq.push({startId, heuristic(startId, endId)});

        while (!pq.empty()) {
            int32_t u = pq.top().id;
            pq.pop();

            if (u == endId) break;

            for (auto& edge : adj[u]) {
                float newDist = dist[u] + edge.weight;
                if (newDist < dist[edge.to]) {
                    dist[edge.to] = newDist;
                    parent[edge.to] = u;
                    pq.push({edge.to, newDist + heuristic(edge.to, endId)});
                }
            }
        }

        if (dist[endId] == INFINITY) return "Ruta no encontrada";

        // Reconstruir trayectoria
        std::vector<Point> pathPoints;
        
        // Punto final exacto (proyección)
        pathPoints.push_back(end.p);

        int32_t curr = endId;
        while (curr != -1) {
            // Solo añadimos el nodo si no es casi idéntico al punto de proyección ya añadido
            Point pNode = nodes[curr];
            if (distSq(pNode.lat, pNode.lon, pathPoints.back().lat, pathPoints.back().lon) > 0.00000001f) {
                pathPoints.push_back(pNode);
            }
            curr = parent[curr];
        }

        // Punto inicial exacto (proyección)
        if (distSq(start.p.lat, start.p.lon, pathPoints.back().lat, pathPoints.back().lon) > 0.00000001f) {
            pathPoints.push_back(start.p);
        }

        // Generar LINESTRING (en orden: inicio a fin)
        std::string lineString = "LINESTRING(";
        for (int i = pathPoints.size() - 1; i >= 0; --i) {
            lineString += std::to_string(pathPoints[i].lon) + " " + std::to_string(pathPoints[i].lat);
            if (i > 0) lineString += ", ";
        }
        lineString += ")";
        
        return lineString;
    }
};

Graph g_paz;

extern "C" {

    FFI_EXPORT int32_t cargar_grafo(const char* path) {
        if (g_paz.loadFromBinary(path)) {
            return (int32_t)g_paz.nodes.size(); 
        }
        return -1; 
    }

    FFI_EXPORT int32_t find_nearest_node(float lat, float lon){
        if(g_paz.nodes.empty()) return -1;
        return g_paz.snapToNearestSegment(lat, lon).nodeId;
    }

    FFI_EXPORT const char* calculate_route(float startLat, float startLon, float endLat, float endLon) {
        LOG("[C++] Calculando ruta con snap: (%f, %f) -> (%f, %f)\n", startLat, startLon, endLat, endLon);

        if (g_paz.nodes.empty()) {
            LOG("[C++] ERROR: Grafo no cargado.\n");
            return "Grafo no cargado";
        }

        // Snapeamos ambos extremos a la componente principal: así siempre hay
        // un camino posible (las "islas" desconectadas se ignoran).
        auto startSnap = g_paz.snapToNearestSegment(startLat, startLon, g_paz.mainComponent);
        auto endSnap = g_paz.snapToNearestSegment(endLat, endLon, g_paz.mainComponent);

        LOG("[C++] Snapping completado.\n");

        std::string result = g_paz.findPath(startSnap, endSnap);
        LOG("[C++] A* con snap completado.\n");

        static std::string static_result;
        static_result = result;
        return static_result.c_str();
    }

    FFI_EXPORT const char* test_routing() {
        auto startSnap = g_paz.snapToNearestSegment(-16.4958f, -68.1335f, g_paz.mainComponent); // San Francisco
        auto endSnap = g_paz.snapToNearestSegment(-16.5011f, -68.1312f, g_paz.mainComponent);   // El Prado
        
        std::string result = g_paz.findPath(startSnap, endSnap); 
        
        static std::string static_result;
        static_result = result;
        return static_result.c_str();
    }
}