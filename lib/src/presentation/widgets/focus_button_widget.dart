import 'package:flutter/material.dart';

enum FocusButtonSize { large, small }

class FocusButtonWidget extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final FocusButtonSize size;
  final IconData? icon;

  const FocusButtonWidget({
    super.key,
    required this.label,
    this.onTap,
    this.size = FocusButtonSize.large,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isLarge = size == FocusButtonSize.large;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isLarge ? 56 : 36,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isLarge ? 0 : 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF4C025),
          borderRadius: BorderRadius.circular(isLarge ? 16 : 12),
          boxShadow: isLarge
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 20),
                    blurRadius: 25,
                    spreadRadius: -5,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 8),
                    blurRadius: 10,
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: isLarge ? 20 : 14, color: const Color(0xFF0F172A)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: isLarge ? 16 : 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
