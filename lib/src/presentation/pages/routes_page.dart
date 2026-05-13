import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class RoutesPage extends StatelessWidget {
  const RoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Rutas Page', style: TextStyle(fontSize: 24))),
    );
  }
}

@Preview(name: 'Routes Page')
Widget previewRoutes() => const RoutesPage();
