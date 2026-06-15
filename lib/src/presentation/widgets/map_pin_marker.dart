import 'package:flutter/material.dart';

class MapPinMarker extends StatelessWidget {
  const MapPinMarker({
    super.key,
    required this.levantado,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
  });

  static const Size tamano = Size(82, 108);
  static const Offset puntoAnclaje = Offset(41, 88);

  final bool levantado;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final GestureDragCancelCallback onPanCancel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Marcador de destino',
      hint: 'Arrastra para mover el destino',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        onPanCancel: onPanCancel,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: levantado ? 1 : 0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, progreso, child) {
            return CustomPaint(
              size: tamano,
              painter: _TachuelaPainter(progresoLevantado: progreso),
            );
          },
        ),
      ),
    );
  }
}

class _TachuelaPainter extends CustomPainter {
  const _TachuelaPainter({required this.progresoLevantado});

  final double progresoLevantado;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progresoLevantado);
    final centroX = MapPinMarker.puntoAnclaje.dx;
    final sueloY = MapPinMarker.puntoAnclaje.dy;
    final elevacion = 22.0 * t;

    _dibujarSombra(canvas, centroX, sueloY, t);

    canvas.save();
    canvas.translate(0, -elevacion);
    final escala = 1.0 + (0.035 * t);
    canvas.translate(centroX, sueloY - 48);
    canvas.scale(escala, escala);
    canvas.translate(-centroX, -(sueloY - 48));

    _dibujarAguja(canvas, centroX, sueloY);
    _dibujarCabeza(canvas, centroX, sueloY);

    canvas.restore();
  }

  void _dibujarSombra(Canvas canvas, double centroX, double sueloY, double t) {
    final sombra = Paint()
      ..color = Colors.black.withValues(alpha: 0.28 - (0.12 * t))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + (6 * t));

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centroX + 2, sueloY + 7),
        width: 28 + (24 * t),
        height: 8 + (8 * t),
      ),
      sombra,
    );
  }

  void _dibujarAguja(Canvas canvas, double centroX, double sueloY) {
    final punta = Offset(centroX, sueloY);
    final baseY = sueloY - 39;
    final aguja = Path()
      ..moveTo(centroX - 5.5, baseY)
      ..quadraticBezierTo(centroX - 2.5, sueloY - 15, punta.dx, punta.dy)
      ..quadraticBezierTo(centroX + 2.5, sueloY - 15, centroX + 5.5, baseY)
      ..close();

    canvas.drawShadow(aguja, Colors.black.withValues(alpha: 0.35), 3, false);
    canvas.drawPath(
      aguja,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFEEF2F7),
            Color(0xFF9AA6B2),
            Color(0xFFF8FAFC),
            Color(0xFF5F6B7A),
          ],
          stops: [0.0, 0.36, 0.58, 1.0],
        ).createShader(Rect.fromLTWH(centroX - 6, baseY, 12, 40)),
    );

    canvas.drawLine(
      Offset(centroX - 1.5, baseY + 4),
      Offset(centroX - 0.3, sueloY - 5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _dibujarCabeza(Canvas canvas, double centroX, double sueloY) {
    final centroCabeza = Offset(centroX, sueloY - 57);
    final rectCabeza = Rect.fromCenter(
      center: centroCabeza,
      width: 54,
      height: 40,
    );
    final rectInferior = Rect.fromCenter(
      center: Offset(centroX, sueloY - 43),
      width: 47,
      height: 18,
    );

    canvas.drawOval(
      rectInferior,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCA151B), Color(0xFF62030A)],
        ).createShader(rectInferior),
    );

    final cabeza = Path()..addOval(rectCabeza);
    canvas.drawShadow(cabeza, Colors.black.withValues(alpha: 0.38), 7, false);
    canvas.drawOval(
      rectCabeza,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.34, -0.48),
          radius: 0.92,
          colors: [
            Color(0xFFFFA39B),
            Color(0xFFFF332F),
            Color(0xFFC70E17),
            Color(0xFF7B0209),
          ],
          stops: [0.0, 0.36, 0.72, 1.0],
        ).createShader(rectCabeza),
    );

    canvas.drawOval(
      rectCabeza.deflate(1.3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xB3FFFFFF), Color(0x22FFFFFF), Color(0x66000000)],
        ).createShader(rectCabeza),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centroX - 12, sueloY - 66),
        width: 15,
        height: 7,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.48),
    );

    canvas.drawArc(
      rectCabeza.deflate(6),
      0.16,
      2.45,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TachuelaPainter oldDelegate) {
    return oldDelegate.progresoLevantado != progresoLevantado;
  }
}
