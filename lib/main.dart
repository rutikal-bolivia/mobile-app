import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {

  const MyApp({super.key});


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      //home: const MyHomePage(title: 'Flutter Demo Home Page'),
      home: const MapPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState()=> _MapPageState();
}

class _MapPageState extends State<MapPage> {
  String? mbtilesPath;
  String? errorMessage;
  MapLibreMapController? mapController;

  @override
  void initState(){
    super.initState();
    _prepararMapaLocal();
  }

  Future<void> _prepararMapaLocal() async {
    try{
        final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/LaPaz.mbtiles';
    final file = File(path);

    // Si el archivo aún no está en el disco, lo copiamos desde assets
    if (!await file.exists()) {
      try {
        final data = await rootBundle.load('assets/LaPaz.mbtiles');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await file.writeAsBytes(bytes);
        print("Mapa copiado exitosamente a: $path");
      } catch (e) {
        print("Error copiando el mapa: $e");
        return;
      }
    }
    setState(() {
      mbtilesPath = path;
    });
    } catch (e){
      setState(() {
        errorMessage = "Error cargando el archivo: $e";
      });
    }
  }


String _generarEstiloVectorial(String path) {
    return '''
    {
      "version": 8,
      "name": "Estilo Mapa Offline Limpio",
      "glyphs": "asset://flutter_assets/assets/fonts/{fontstack}/{range}.pbf",
      "sources": {
        "mi_mapa": {
          "type": "vector",
          "url": "mbtiles://$path"
        }
      },
      "layers": [
        {
          "id": "fondo",
          "type": "background",
          "paint": { "background-color": "#f2efe9" }
        },
        {
          "id": "agua",
          "type": "fill",
          "source": "mi_mapa",
          "source-layer": "water_polygons",
          "paint": { "fill-color": "#a0c8f0" }
        },
        {
          "id": "edificios",
          "type": "fill",
          "source": "mi_mapa",
          "source-layer": "buildings",
          "paint": {
            "fill-color": "#d9d0c9",
            "fill-opacity": 0.6
          }
        },
        {
          "id": "calles_detalladas",
          "type": "line",
          "source": "mi_mapa",
          "source-layer": "streets",
          "paint": {
            "line-color": "#ffffff",
            "line-width": 2.5
          }
        },
        {
          "id": "telefericos",
          "type": "line",
          "source": "mi_mapa",
          "source-layer": "aerialways",
          "paint": {
            "line-color": "#ff0000",
            "line-width": 2,
            "line-dasharray": [2, 2]
          }
        },
        {
          "id": "nombres_zonas",
          "type": "symbol",
          "source": "mi_mapa",
          "source-layer": "place_labels",
          "layout": {
            "text-field": "{name}",
            "text-font": ["OpenSansBold"],
            "text-size": 15,
            "text-transform": "uppercase"
          },
          "paint": {
            "text-color": "#6a6a6a",
            "text-halo-color": "#f2efe9",
            "text-halo-width": 2
          }
        },
        {
          "id": "nombres_calles",
          "type": "symbol",
          "source": "mi_mapa",
          "source-layer": "street_labels",
          "layout": {
            "text-field": "{name}",
            "text-font": ["OpenSansRegular"],
            "text-size": 13,
            "symbol-placement": "line"
          },
          "paint": {
            "text-color": "#2b2b2b",
            "text-halo-color": "#f2efe9", 
            "text-halo-width": 2
          }
        }
      ]
    }
    ''';
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() {
      mapController = controller; // ¡Guardamos el control remoto!
    });
    print("¡El mapa está listo y el controlador guardado!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Navegación Offline")),
      body: _construirCuerpo(),
    );
  }

  Widget _construirCuerpo() {
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (mbtilesPath == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(-16.5000, -68.1500), 
        zoom: 14.5,
      ),
      styleString: _generarEstiloVectorial(mbtilesPath!),
      onMapCreated: (controller) {
        mapController = controller;
      },
    );
  }

}