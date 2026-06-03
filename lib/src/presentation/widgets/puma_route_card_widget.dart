import 'package:flutter/material.dart';

class PumaRouteCardWidget extends StatelessWidget {
  final String routeName;
  final String routeCode;
  final String routeDescription;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;

  const PumaRouteCardWidget({
    super.key,
    required this.routeName,
    required this.routeCode,
    required this.routeDescription,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
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
            // Yellow indicator bar
            Container(
              width: 8,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF4C025),
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
            const SizedBox(width: 16),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    maxLines: 2,
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
            // Estrella de favorito (inline, no se superpone al texto)
            if (onFavoriteTap != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onFavoriteTap,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 22,
                  color: isFavorite
                      ? const Color(0xFFF4C025)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
            const SizedBox(width: 4),
            // Chevron
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
