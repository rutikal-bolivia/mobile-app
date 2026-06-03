# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Rutikal** is a Flutter offline transport-routing app for La Paz, Bolivia. It integrates multiple transit systems (Pumakatari buses, Teleférico) and computes optimal multimodal routes entirely on-device — no network is required for maps or routing. Code and comments are written in **Spanish**; keep new contributions consistent with that.

> The Dart package is named `prueba` (see `pubspec.yaml`). Internal absolute imports use `package:prueba/...`, but most files use relative imports. The app's display name is "Rutikal".

## Commands

```bash
flutter pub get                      # install deps
flutter run                          # run on attached device/emulator (debug)
flutter run -d <device-id>           # target a specific device; `flutter devices` to list
flutter analyze                      # lint (uses flutter_lints via analysis_options.yaml)
flutter test                         # run all tests
flutter test test/widget_test.dart   # run a single test file
flutter test --name "<substring>"    # run tests matching a name
flutter build apk / flutter build ios
```

There is only one test (`test/widget_test.dart`, the default template) — it is not kept in sync with the real app and may need updating before it passes.

## Architecture

Clean-architecture layering under `lib/src/`:

- **`data/`** — datasources + repository implementations.
- **`domain/`** — repository interfaces (`map_repository.dart`, `search_repository.dart`, `location_repository.dart`). No business logic lives here beyond contracts.
- **`presentation/`** — `pages/`, `widgets/`, and `bloc/`.

State management is **BLoC / Cubit** (`flutter_bloc`). Each feature has an event/state/bloc trio in `lib/src/presentation/bloc/`: `MapBloc`, `RoutingBloc`, `SearchBloc`, `LocationBloc`, plus `NavigationCubit` (bottom-nav index). `RootPage` provides `NavigationCubit` + `RoutingBloc` app-wide; `MapLayout` provides `MapBloc` scoped to the map screen. The five tabs live in an `IndexedStack` so the map (`MainPage` inside `MapLayout`) stays alive across tab switches.

### Native routing (FFI → C++)

The heavy graph/pathfinding logic is **C++** in `src_native/native_logic.cpp`, called over `dart:ffi`:

- `lib/src/data/datasources/native_bridge.dart` is the abstract interface, resolved at compile time via conditional import to `native_bridge_ffi.dart` (real, when `dart.library.ffi` is available) or `native_bridge_stub.dart` (fallback). Construct with `NativeBridge()`.
- C ABI exports (`extern "C"`): `cargar_grafo(path)`, `calculate_route(lat,lon,lat,lon)`, `find_nearest_node`, `test_routing`. The C++ keeps a single global graph `g_paz`.
- Routing is **A\*** over a node/edge graph loaded from a binary `assets/grafo_la_paz.dat` (`loadFromBinary`). Query points are **snapped** to the nearest road segment (orthogonal projection, `snapToNearestSegment`) before pathfinding, and the result is returned as a WKT `LINESTRING(...)` string that `RoutingBloc._parsearRuta` parses into `[lat, lon]` pairs.
- **Build wiring:** Android builds the lib via `android/app/build.gradle.kts` → `externalNativeBuild { cmake { path "../../src_native/CMakeLists.txt" } }` and loads `libnative_logic.so`. iOS compiles `native_logic.cpp` directly into the Runner target (referenced in `Runner.xcodeproj`) and resolves symbols via `DynamicLibrary.process()`. **When changing the C++ export signatures, update the `typedef`s in `native_bridge_ffi.dart` on both platforms.**

### Offline map rendering

Uses `maplibre_gl` with a vector `.mbtiles` file (`assets/LaPaz.mbtiles`). The style JSON is generated at runtime in `MapRepositoryImpl.prepareOfflineStyle()` — there is **no static style file**; layer definitions (water, buildings, streets, aerialways, labels) live in that Dart string.

Platform split (this is the key non-obvious bit):
- **Android** points the style source directly at `mbtiles://<path>` and serves glyphs from `asset://`.
- **iOS** cannot resolve `mbtiles://` / `asset://` inside a style JSON, so `LocalTileServer` (`shelf`) spins up an HTTP server on `127.0.0.1` that serves tiles and glyph PBFs over `http://`. Note MBTiles stores rows in TMS and MapLibre requests XYZ, so the Y coordinate is flipped (`flippedY`).

`OfflineMapView` is the live map widget; it draws the draggable marker, search highlight, and route polyline by listening to `MapBloc` + `RoutingBloc` and calling the `MapLibreMapController` imperatively.

### Asset bootstrapping

Bundled binary assets are copied from the asset bundle into app storage on first launch before native/SQLite code can open them (they need real filesystem paths): `GraphStorageService.copyGraphToLocal()` for the routing graph and `SearchDatabaseService` for `search_lapaz.sqlite` (read-only). Both copy-once-if-absent.

### Search & data model

`SearchDatabaseService` opens a read-only SQLite DB (`assets/search_lapaz.sqlite`) for place/stop lookup. The relational schema for the routing data is documented in `esquema_local_rutikal.sql` (`rutas`, `paradas`, `paradas_rutas`). `GEMINI.md` contains the detailed product spec for the multimodal routing algorithm (transfers between bus routes, bus↔teleférico proximity connections, pre-computed `Conexiones` table) — read it before working on routing logic.

### Widget previews / mocks

`lib/core/preview_mocks.dart` provides mock repositories (`MockMapRepository`, `MockLocationRepository`) and `MockMapView` so `@Preview`-annotated functions (e.g. in `root_page.dart`, `map_layout.dart`, `offline_map_view.dart`) render in the IDE without device hardware. Inject mocks via the optional `mapRepository` / `mapBuilder` params on `MapLayout`.
