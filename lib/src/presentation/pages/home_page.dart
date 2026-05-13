import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Home Page', style: TextStyle(fontSize: 24))),
    );
  }
}

@Preview(name: 'Home Page')
Widget previewHome() => const HomePage();
