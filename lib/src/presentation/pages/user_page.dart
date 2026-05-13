import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Usuario Page', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

@Preview(name: 'User Page')
Widget previewUser() => const UserPage();
