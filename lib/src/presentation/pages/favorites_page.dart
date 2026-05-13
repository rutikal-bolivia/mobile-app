import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Favoritos Page', style: TextStyle(fontSize: 24))),
    );
  }
}

@Preview(name: 'Favorites Page')
Widget previewFavorites() => const FavoritesPage();
