import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class AddMarkerButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const AddMarkerButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'marker_btn',
      mini: true,
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue,
      child: const Icon(Icons.location_on),
    );
  }
}

class MyLocationButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const MyLocationButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'location_btn',
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue,
      child: const Icon(Icons.my_location),
    );
  }
}

class RoutingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  const RoutingButton({super.key, required this.onPressed, this.label = 'Calcular Ruta'});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      label: Text(label),
      icon: const Icon(Icons.directions),
      backgroundColor: Colors.green,
    );
  }
}

class ZoomInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const ZoomInButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'zoom_in_btn',
      mini: true,
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF637381),
      child: const Icon(Icons.add),
    );
  }
}

class ZoomOutButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const ZoomOutButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'zoom_out_btn',
      mini: true,
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF637381),
      child: const Icon(Icons.remove),
    );
  }
}

// Previsualizaciones oficiales para VS Code (Flutter 3.38+)
@Preview(name: 'Add Marker Button')
Widget previewAddMarker() => const Scaffold(body: Center(child: AddMarkerButton(onPressed: null)));

@Preview(name: 'My Location Button')
Widget previewMyLocation() => const Scaffold(body: Center(child: MyLocationButton(onPressed: null)));

@Preview(name: 'Routing Button')
Widget previewRouting() => const Scaffold(body: Center(child: RoutingButton(onPressed: null)));

@Preview(name: 'Zoom In Button')
Widget previewZoomIn() => const Scaffold(body: Center(child: ZoomInButton(onPressed: null)));

@Preview(name: 'Zoom Out Button')
Widget previewZoomOut() => const Scaffold(body: Center(child: ZoomOutButton(onPressed: null)));
