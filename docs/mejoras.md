# Mejoras — Optimización de mapas y C++/FFI

Seguimiento de las mejoras de rendimiento y arquitectura del proyecto Rutikal.
Estado: ✅ hecho · 🚧 en progreso · ⬜ pendiente · 🔍 a verificar

---

## En curso (primera tanda)

### ✅ 1. Sacar el routing del hilo de UI (FFI)
**Problema:** `RoutingBloc` llamaba a `bridge.calcularRuta(...)` y `bridge.cargarGrafo(...)` de forma **síncrona** sobre el isolate principal (`routing_bloc.dart`). Mientras corría el snapping + A\*, la UI quedaba congelada pese a emitir `RoutingLoading`.
**Solución:** ejecutar las llamadas FFI con `Isolate.run(...)`. El grafo nativo (`g_paz`) es estado **de proceso**, compartido entre isolates del mismo proceso, así que cargarlo en un isolate y calcular en otro funciona sin recargar la memoria nativa.
**Archivos:** `lib/src/presentation/bloc/routing_bloc.dart`.
**Fix (post-prueba):** el closure de `Isolate.run` estaba dentro del handler del bloc y capturaba el contexto léxico → arrastraba el `Emitter`/bloc (no enviable) → `object is unsendable`. Se movió a funciones **top-level** (`_cargarGrafoAislado`, `_calcularRutaAislada`) que solo capturan primitivos.
**Pendiente de verificar:** medir en device que no congela; confirmar que dos `Isolate.run` no se solapan sobre `g_paz` (hoy el flujo los serializa: no se pide ruta antes de cargar).

### ✅ 2. Índice espacial para el snapping (C++)
**Problema:** `snapToNearestSegment` recorría **todos** los nodos (O(n)) para hallar el más cercano, y se llama 2×/ruta. Con decenas de miles de nodos era el cuello de botella real (más que el A\*).
**Solución:** `SpatialGrid` uniforme (celdas ~150 m) construido en `loadFromBinary`; búsqueda por anillos crecientes con corte correcto cuando el anillo ya no puede mejorar la mejor distancia. Pasa de O(n) a ~O(1) amortizado.
**Archivos:** `src_native/native_logic.cpp`.
**Pendiente de verificar:** compilar en Android (NDK) e iOS; medir mejora; ajustar `cellSize` si la densidad lo amerita.

### ✅ 3. No duplicar el `.mbtiles` de 191 MB (Mapas)
**Problema:** `MbtilesAssetSource.ensureAvailable()` copiaba íntegro `LaPaz.mbtiles` (191 MB) del bundle al sandbox en el primer arranque → ~382 MB en disco, pico de RAM y arranque lento.
**Solución:**
- **iOS:** los assets son ficheros reales del bundle. Canal nativo `rutikal/assets` (`resolveAssetPath`) que devuelve la ruta del `.mbtiles` dentro del bundle; el `LocalTileServer` (read-only) lo lee directo, sin copiar. **Cero duplicación en iOS.**
- **Android:** los assets viven comprimidos dentro del APK y no son ficheros accesibles, así que la copia al sandbox sigue siendo obligatoria (se mantiene como fallback).
- Fallback robusto: si el canal no responde o la ruta no existe, cae a la copia de siempre.
**Archivos:** `lib/src/data/datasources/mbtiles_asset_source.dart`, `ios/Runner/AppDelegate.swift`.
**Verificado:** build de iOS probado en device por el usuario — compila y funciona. (Android sigue copiando al sandbox, que es lo esperado.)

---

## Hecho (segunda tanda — bases)

### 🔍→✅ A. Heurística A\* admisible (corrección)
**Hallazgo (inspección del `.dat`):** 186.928 nodos, 211.750 aristas, little-endian. El `edge.weight` es la **distancia haversine en metros** (coincide con la geodésica a ~5 decimales). La heurística anterior (`sqrt(dLat²+dLon²)·111000`) sobreestimaba ~1–4% → **no admisible** → posibles rutas subóptimas.
**Solución:** heurística = **haversine en metros**. Admisible y consistente (misma unidad que los pesos) → A\* óptimo.
**Archivos:** `src_native/native_logic.cpp`.

### ✅ B. Validar `loadFromBinary` (robustez)
Bounds-check de `u`/`v ∈ [0, nodeCount)` (aristas inválidas se saltan) y `file.good()` tras cada lectura. Evita out-of-bounds/crash con un `.dat` corrupto. `src_native/native_logic.cpp`.

### ✅ C. CMake + logging de C++
`CMAKE_CXX_STANDARD 17`, `-O3 -fvisibility=hidden` en Release. `printf` → macro `LOG(...)` que se compila a nada bajo `NDEBUG`. `src_native/CMakeLists.txt`, `native_logic.cpp`. *Compila en debug y release (`-fsyntax-only` OK).*

### ✅ D. LocalTileServer: caché y headers
Logging por tile solo en `kDebugMode`; `Cache-Control: public, max-age=31536000, immutable`; `Content-Encoding: gzip` ahora se detecta por magic bytes (`0x1f 0x8b`) en vez de asumirse. `lib/src/data/datasources/local_tile_server.dart`.

### ✅ E. Estilo JSON como objeto
`MapRepositoryImpl._buildStyle` construye un `Map` y usa `jsonEncode` en vez de interpolar strings; elimina riesgos de escape. También se limpió un import duplicado de `constants.dart`. `lib/src/data/repositories/map_repository_impl.dart`.

---

## Hecho (quinta tanda — desfase polilínea vs calles a zoom alto)

### ✅ J. Mitigación del desfase de la ruta sobre las calles (Opción A)
**Diagnóstico (metadata del `.mbtiles`):** esquema **Shortbread** de **OSM/Geofabrik** (misma fuente que el `.osm.pbf` → no es problema de datos distintos) con **maxzoom 14**. A zoom de visualización >14 MapLibre hace **overzoom** de tiles z14, cuya geometría está simplificada; la polilínea usa los vértices completos del `.dat` → divergen, visible solo al acercar. Secundario: el `.dat` usa `float` (~1 m de error).
**Solución (mitigación en app, sin tocar datos):** tope de zoom a `MapConfig.maxZoom = 16` (`minMaxZoomPreference`), `searchZoom` 17→16, y `line-width` de la capa `streets` interpolado por zoom (más ancho al acercar) para que la ruta caiga dentro del trazo.
**Archivos:** `core/constants.dart`, `offline_map_view.dart`, `map_repository_impl.dart`.
**Cura de raíz (pendiente, opcional):** regenerar el `.mbtiles` a maxzoom 16-18 desde el mismo OSM (planetiler/tilemaker) — Opción B. Alternativas evaluadas: pasar el `.dat` a `double` (C, precisión), generar el `.dat` desde el `.mbtiles` (D, alineación perfecta pero ruteo a resolución z14 y topología frágil), pipeline único tiles+grafo (E, lo robusto).

---

## Hecho (cuarta tanda — bug: rutas que no unían los puntos)

### ✅ H. Snapping consciente de conectividad (grafo fragmentado)
**Síntoma:** a veces la ruta no unía origen y destino; mover el punto unos metros lo arreglaba.
**Diagnóstico (inspección del `.dat`):** el grid de snapping es **correcto** (0 discrepancias vs fuerza bruta en 4000 puntos). El problema es el grafo: **204 componentes conexas**. La principal tiene 182.640 nodos (97,7%), pero **4.288 nodos (2,3%) están en 203 "islas"** desconectadas (artefactos de la limpieza del OSM). Si el punto caía más cerca de una isla, A\* no podía alcanzar la ciudad → "Ruta no encontrada".
**Solución:** `computeComponents()` (union-find) etiqueta la componente de cada nodo al cargar y guarda la mayor (`mainComponent`). `snapToNearestSegment` acepta `restrictComponent`; `calculate_route` snapea **origen y destino a la componente principal**, garantizando que siempre exista camino. Las islas se ignoran.
**Archivos:** `src_native/native_logic.cpp`. *Compila debug y release.*
**Pendiente (opcional, raíz del dato):** regenerar el `.dat` uniendo/descartando islas en el preprocesado del `.osm.pbf`.

### ✅ I. Limpiar la ruta al fallar (presentación)
En `RoutingError`, `offline_map_view.dart` solo mostraba un SnackBar y **dejaba la línea anterior dibujada** → parecía un resultado válido ("ruta parecida a la anterior"). Ahora se limpia la capa con `_drawRoute(const [])`. `lib/src/presentation/widgets/offline_map_view.dart`.

---

## Hecho (tercera tanda — mapas)

### ✅ F. Ruta como GeoJSON layer (no annotation)
**Problema:** la ruta se dibujaba con `addLine` (annotation) haciendo remove+add en cada cálculo; con cientos de puntos es lo más pesado del render.
**Solución:** source `route-source` + line layer `route-layer` añadidos en `onStyleLoadedCallback`; cada ruta se actualiza con `setGeoJsonSource` (barato). Si llega una ruta antes de cargar el estilo, se guarda en `_pendingRoute` y se aplica al cargar.
**Nota:** el **marcador rojo se mantiene como annotation** a propósito: es arrastrable (`onFeatureDrag`) y el drag no funciona sobre capas GeoJSON en maplibre_gl. Búsqueda (símbolo) también sigue como annotation.
**Archivos:** `lib/src/presentation/widgets/offline_map_view.dart`.

### ✅ G. Ciclo de vida del server local en iOS
**Problema:** iOS puede cerrar el servidor loopback en background; al volver, las URLs `http://127.0.0.1:<port>` quedaban muertas y el mapa no cargaba tiles.
**Solución:** `OfflineMapView` observa el lifecycle (`WidgetsBindingObserver`); en `resumed` dispara `MapAppResumed`. El `MapBloc` hace un **health-check** (`isLocalServerHealthy`) y solo si el server murió lo reconstruye (`prepareOfflineStyle`, que ahora para el anterior primero) y emite un nuevo `styleString`. La `key` del `OfflineMapView` (= styleString) fuerza la recarga limpia del mapa solo en ese caso; en operación normal no hay parpadeo.
**Archivos:** `map_event.dart`, `map_bloc.dart`, `map_repository.dart`, `map_repository_impl.dart`, `preview_mocks.dart`, `map_layout.dart`, `offline_map_view.dart`.
**A verificar en device:** que tras background→foreground el mapa siga sirviendo tiles; que la cámara/marcador se restauren aceptablemente (la cámara vuelve al encuadre inicial al recargar — ver nota abajo).

---

## Pendientes — Mapas

- ⬜ **Preservar cámara tras recarga por resume.** Al reconstruir el server, el mapa recarga con `initialCameraPosition` por defecto; pasar `currentCameraCenter` (y guardar zoom en el estado) para restaurar el encuadre exacto.
- ⬜ **LRU de tiles en memoria** (opcional) para zoom bajo, si el I/O de SQLite resultara notable.

## Pendientes — C++ / FFI

- ⬜ **Devolver coordenadas binarias en vez de `LINESTRING` string.** Retornar `Pointer<Float>` + cantidad de puntos (o buffer provisto por Dart) y leer con `asTypedList`; elimina serializar/parsear strings (`_parsearRuta`).
- ⬜ **Concurrencia / estado global.** `g_paz` y los `static std::string` de retorno no son thread-safe; serializar acceso (idealmente un único isolate de routing dedicado). *Relacionado con la mejora #1.*
- ⬜ **Bindings con `ffigen`** en vez de `typedef`s manuales (`native_bridge_ffi.dart`); `find_nearest_node` está exportada pero sin usar en Dart.

## Pendientes — General

- ⬜ **Descarga diferida del `.mbtiles`.** Evaluar bajarlo en el primer arranque en vez de empaquetar 191 MB en el APK/IPA.
- ⬜ **Renombrar el paquete** `prueba` → algo acorde a Rutikal (afecta `package:prueba/...`).
- ⬜ **Actualizar `test/widget_test.dart`** (es el template por defecto, no refleja la app real).
