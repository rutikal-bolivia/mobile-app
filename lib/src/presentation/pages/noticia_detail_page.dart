import 'package:flutter/material.dart';
import '../../../core/app_config.dart';
import '../../domain/models/noticia.dart';

/// Vista de detalle de una noticia: imagen de cabecera, título, fecha de
/// publicación y el cuerpo completo de la descripción.
class NoticiaDetailPage extends StatelessWidget {
  const NoticiaDetailPage({super.key, required this.noticia});

  final Noticia noticia;

  String _fechaLegible(DateTime? date) {
    if (date == null) return '';
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${date.day} de ${meses[date.month - 1]} de ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final imagen = AppConfig.mediaUrl(noticia.imagen);
    final fecha = _fechaLegible(noticia.fechaPublicacion);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: imagen.isNotEmpty ? 240 : 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 1,
            iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
            title: const Text(
              'Noticia',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            flexibleSpace: imagen.isEmpty
                ? null
                : FlexibleSpaceBar(
                    background: Image.network(
                      imagen,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.image_not_supported_outlined,
                            size: 48, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    noticia.titulo,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.25,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (fecha.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          fecha,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    (noticia.descripcion ?? '').isEmpty
                        ? 'Sin contenido disponible.'
                        : noticia.descripcion!,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF334155),
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
