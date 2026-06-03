import 'package:flutter/material.dart';

class RouteCardWidget extends StatelessWidget {
  final String routeName;
  final String routeCode;
  final String routeDescription;
  final String? colorHex;
  final VoidCallback? onTap;

  const RouteCardWidget({
    super.key,
    required this.routeName,
    required this.routeCode,
    required this.routeDescription,
    this.colorHex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Parsear el string hexadecimal de la DB a un Color de Flutter
    Color indicatorColor = const Color(0xFFF4C025); // Color por defecto (amarillo Puma)
    if (colorHex != null && colorHex!.isNotEmpty) {
      try {
        final String cleanHex = colorHex!.replaceAll('#', '');
        if (cleanHex.length == 6) {
          indicatorColor = Color(int.parse('0xFF$cleanHex'));
        } else if (cleanHex.length == 8) {
          indicatorColor = Color(int.parse('0x$cleanHex'));
        }
      } catch (_) {
        // En caso de fallar, se mantiene el color por defecto
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            // Barra lateral con el color del medio de transporte / línea
            Container(
              width: 8,
              height: 48,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
            const SizedBox(width: 16),
            // Contenido textual
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routeName,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3D2B1F),
                      height: 1.5,
                    ),
                  ),
                  Text(
                    '$routeCode • $routeDescription',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                      height: 1.333,
                    ),
                  ),
                ],
              ),
            ),
            // Chevron derecho
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }
}
