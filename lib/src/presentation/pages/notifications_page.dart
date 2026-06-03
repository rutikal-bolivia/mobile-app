import 'package:flutter/material.dart';
import '../../domain/models/alerta.dart';
import '../../domain/models/noticia.dart';
import 'noticia_detail_page.dart';

/// Bandeja de notificaciones que abre la campanita del encabezado. Combina las
/// alertas vigentes y las noticias publicadas en una única lista ordenada por
/// fecha (lo más reciente primero). Los elementos posteriores a [vistoEn] se
/// resaltan como "no leídos".
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.noticias,
    required this.alertas,
    this.vistoEn,
  });

  final List<Noticia> noticias;
  final List<Alerta> alertas;
  final DateTime? vistoEn;

  @override
  Widget build(BuildContext context) {
    final items = <_NotifItem>[
      ...alertas.map((a) => _NotifItem.alerta(a)),
      ...noticias.map((n) => _NotifItem.noticia(n)),
    ]..sort((a, b) {
        final fa = a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        final fb = b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0);
        return fb.compareTo(fa);
      });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: items.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = items[i];
                final esNuevo = vistoEn == null ||
                    (item.fecha != null && item.fecha!.isAfter(vistoEn!));
                return _NotifTile(item: item, esNuevo: esNuevo);
              },
            ),
    );
  }
}

enum _NotifTipo { alerta, noticia }

class _NotifItem {
  _NotifItem.alerta(Alerta a)
      : tipo = _NotifTipo.alerta,
        alerta = a,
        noticia = null,
        fecha = a.fechaInicio ?? a.updatedAt;

  _NotifItem.noticia(Noticia n)
      : tipo = _NotifTipo.noticia,
        alerta = null,
        noticia = n,
        fecha = n.fechaPublicacion ?? n.updatedAt;

  final _NotifTipo tipo;
  final Alerta? alerta;
  final Noticia? noticia;
  final DateTime? fecha;
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.item, required this.esNuevo});

  final _NotifItem item;
  final bool esNuevo;

  static const _severidadColor = {
    'alta': Color(0xFFDC2626),
    'media': Color(0xFFD97706),
    'baja': Color(0xFF2563EB),
  };

  static const _tipoIcono = {
    'cierre': Icons.block_rounded,
    'retraso': Icons.schedule_rounded,
    'mantenimiento': Icons.build_rounded,
    'informativa': Icons.info_outline_rounded,
  };

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final esAlerta = item.tipo == _NotifTipo.alerta;
    final color = esAlerta
        ? (_severidadColor[item.alerta!.severidad] ?? const Color(0xFF2563EB))
        : const Color(0xFFF4C025);
    final icono = esAlerta
        ? (_tipoIcono[item.alerta!.tipo] ?? Icons.info_outline_rounded)
        : Icons.article_outlined;
    final titulo =
        esAlerta ? item.alerta!.titulo : item.noticia!.titulo;
    final descripcion =
        esAlerta ? item.alerta!.descripcion : item.noticia!.descripcion;

    return Material(
      color: esNuevo ? const Color(0xFFFFFBEB) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: esAlerta
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NoticiaDetailPage(noticia: item.noticia!),
                  ),
                ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (esNuevo)
                          Container(
                            margin: const EdgeInsets.only(left: 6, top: 4),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF4C025),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (descripcion != null && descripcion.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${esAlerta ? 'Alerta' : 'Noticia'} · ${_timeAgo(item.fecha)}',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (!esAlerta)
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 8),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 20, color: Color(0xFFCBD5E1)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text(
            'No tienes notificaciones',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
