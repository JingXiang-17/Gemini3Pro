import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConfidenceGauge extends StatefulWidget {
  final double score; // 0.0 to 1.0

  const ConfidenceGauge({super.key, required this.score});

  @override
  State<ConfidenceGauge> createState() => _ConfidenceGaugeState();
}

class _ConfidenceGaugeState extends State<ConfidenceGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(ConfidenceGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation =
          Tween<double>(begin: _animation.value, end: widget.score).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 200,
        height: 200,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              painter: _GaugePainter(_animation.value),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TRUST SCORE',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${(_animation.value * 100).toInt()}%',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFD4AF37),
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;

  _GaugePainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const startAngle = 135 * pi / 180;
    const sweepAngle = 270 * pi / 180;

    // Draw Background Arc
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 15;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Draw Progress Arc
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8E793E), Color(0xFFD4AF37), Color(0xFFFFD700)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 15;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      startAngle,
      sweepAngle * score,
      false,
      progressPaint,
    );

    // Draw Ticks
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;

    for (int i = 0; i <= 20; i++) {
      final angle = startAngle + (sweepAngle * (i / 20));
      final outerPoint = Offset(center.dx + (radius - 25) * cos(angle),
          center.dy + (radius - 25) * sin(angle));
      final innerPoint = Offset(center.dx + (radius - 35) * cos(angle),
          center.dy + (radius - 35) * sin(angle));
      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
