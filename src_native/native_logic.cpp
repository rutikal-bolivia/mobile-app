#include <vector>
#include <queue>
#include <cmath>
#include <string>
#include <algorithm>
#include <fstream>
#include <stdint.h>

#if defined(__GNUC__)
    #define FFI_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#else
    #define FFI_EXPORT
#endif

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

class Graph {
public:
    std::vector<Point> nodes;
    std::vector<std::vector<Edge>> adj;

    struct SnappedPoint {
        Point p;
        int32_t nodeId;
    };

    // Encuentra el punto más cercano en los segmentos que tocan al nodo más cercano
    SnappedPoint snapToNearestSegment(float lat, float lon) {
        if (nodes.empty()) return {{0,0}, -1};
        
        // 1. Encontrar el nodo más cercano (baseline)
        int32_t nearestNode = 0;
        float minDistSq = distSq(lat, lon, nodes[0].lat, nodes[0].lon);
        for (int32_t i = 1; i < (int32_t)nodes.size(); ++i) {
            float d = distSq(lat, lon, nodes[i].lat, nodes[i].lon);
            if (d < minDistSq) {
                minDistSq = d;
                nearestNode = i;
            }
        }

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

    // Heurística: Distancia euclidiana simple (ideal para distancias cortas como una ciudad)
    float heuristic(int32_t a, int32_t b) {
        float dLat = nodes[a].lat - nodes[b].lat;
        float dLon = nodes[a].lon - nodes[b].lon;
        return std::sqrt(dLat * dLat + dLon * dLon) * 111000.0f; // Aprox metros
    }

    // IMPORTANTE: Faltaba esta función para leer tu archivo .dat con las coordenadas
    bool loadFromBinary(const char* path) {
        std::ifstream file(path, std::ios::binary);
        if (!file.is_open()) return false;

        int32_t nodeCount, edgeCount;
        file.read((char*)&nodeCount, sizeof(int32_t));
        file.read((char*)&edgeCount, sizeof(int32_t));

        nodes.resize(nodeCount);
        for (int i = 0; i < nodeCount; ++i) {
            float lat, lon;
            file.read((char*)&lat, sizeof(float));
            file.read((char*)&lon, sizeof(float));
            nodes[i] = {lat, lon};
        }

        adj.resize(nodeCount);
        for (int i = 0; i < edgeCount; ++i) {
            int32_t u, v;
            float dist;
            file.read((char*)&u, sizeof(int32_t));
            file.read((char*)&v, sizeof(int32_t));
            file.read((char*)&dist, sizeof(float));

            adj[u].push_back({v, dist});
            adj[v].push_back({u, dist});
        }
        file.close();
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
        printf("[C++] Calculando ruta con snap: (%f, %f) -> (%f, %f)\n", startLat, startLon, endLat, endLon);
        
        if (g_paz.nodes.empty()) {
            printf("[C++] ERROR: Grafo no cargado.\n");
            return "Grafo no cargado";
        }

        auto startSnap = g_paz.snapToNearestSegment(startLat, startLon);
        auto endSnap = g_paz.snapToNearestSegment(endLat, endLon);
        
        printf("[C++] Snapping completado.\n");

        std::string result = g_paz.findPath(startSnap, endSnap); 
        printf("[C++] A* con snap completado.\n");

        static std::string static_result;
        static_result = result;
        return static_result.c_str();
    }

    FFI_EXPORT const char* test_routing() {
        auto startSnap = g_paz.snapToNearestSegment(-16.4958f, -68.1335f); // San Francisco
        auto endSnap = g_paz.snapToNearestSegment(-16.5011f, -68.1312f);   // El Prado
        
        std::string result = g_paz.findPath(startSnap, endSnap); 
        
        static std::string static_result;
        static_result = result;
        return static_result.c_str();
    }
}