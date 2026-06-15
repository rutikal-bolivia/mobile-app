import 'dart:ui';

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
  const RoutingButton({
    super.key,
    required this.onPressed,
    this.label = 'Calcular ruta',
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 32,
        minHeight: 54,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.42),
              blurRadius: 8,
              offset: const Offset(-3, -3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(27),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(27),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: habilitado
                          ? const [
                              Color(0xF2F8FAFC),
                              Color(0xD7D9E0E8),
                              Color(0xEEF4F6F8),
                            ]
                          : const [
                              Color(0xCCE5E7EB),
                              Color(0xB8D1D5DB),
                              Color(0xCCDDE1E7),
                            ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.95),
                              const Color(0xFFD6DCE4),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Icon(
                          Icons.near_me_rounded,
                          size: 17,
                          color: habilitado
                              ? const Color(0xFF384252)
                              : const Color(0xFF8A94A3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: habilitado
                                ? const Color(0xFF222A35)
                                : const Color(0xFF8A94A3),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
Widget previewAddMarker() =>
    const Scaffold(body: Center(child: AddMarkerButton(onPressed: null)));

@Preview(name: 'My Location Button')
Widget previewMyLocation() =>
    const Scaffold(body: Center(child: MyLocationButton(onPressed: null)));

@Preview(name: 'Routing Button')
Widget previewRouting() =>
    const Scaffold(body: Center(child: RoutingButton(onPressed: null)));

@Preview(name: 'Zoom In Button')
Widget previewZoomIn() =>
    const Scaffold(body: Center(child: ZoomInButton(onPressed: null)));

@Preview(name: 'Zoom Out Button')
Widget previewZoomOut() =>
    const Scaffold(body: Center(child: ZoomOutButton(onPressed: null)));
