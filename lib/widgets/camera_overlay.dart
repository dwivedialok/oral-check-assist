import 'package:flutter/material.dart';
import '../models/photo_capture.dart';

/// Overlay guide for camera capture
class CameraOverlay extends StatelessWidget {
  final PhotoType photoType;
  final bool isReady;

  const CameraOverlay({
    super.key,
    required this.photoType,
    this.isReady = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(photoType: photoType, isReady: isReady),
      child: Container(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final PhotoType photoType;
  final bool isReady;

  _OverlayPainter({required this.photoType, required this.isReady});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isReady
          ? Colors.green.withOpacity(0.8)
          : Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2);

    switch (photoType) {
      case PhotoType.frontView:
        _drawMouthOutline(canvas, size, paint);
        break;
      case PhotoType.rightCheek:
      case PhotoType.leftCheek:
        _drawCheekGuide(canvas, size, paint, photoType == PhotoType.leftCheek);
        break;
      case PhotoType.tongue:
        _drawTongueGuide(canvas, size, paint);
        break;
      case PhotoType.palate:
        _drawPalateGuide(canvas, size, paint);
        break;
    }

    // Draw corner guides
    _drawCornerGuides(canvas, size, paint);
  }

  void _drawMouthOutline(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final width = size.width * 0.6;
    final height = size.height * 0.35;

    // Draw oval mouth guide
    final rect = Rect.fromCenter(center: center, width: width, height: height);

    // Draw dashed oval
    final path = Path()..addOval(rect);
    _drawDashedPath(canvas, path, paint);

    // Draw teeth guide lines
    final teethPaint = Paint()
      ..color = paint.color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Upper teeth line
    canvas.drawLine(
      Offset(center.dx - width / 3, center.dy - height / 4),
      Offset(center.dx + width / 3, center.dy - height / 4),
      teethPaint,
    );

    // Lower teeth line
    canvas.drawLine(
      Offset(center.dx - width / 3, center.dy + height / 4),
      Offset(center.dx + width / 3, center.dy + height / 4),
      teethPaint,
    );
  }

  void _drawCheekGuide(Canvas canvas, Size size, Paint paint, bool isLeft) {
    final centerX = isLeft ? size.width * 0.45 : size.width * 0.55;
    final center = Offset(centerX, size.height / 2);
    final radius = size.width * 0.35;

    // Draw circle guide
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    _drawDashedPath(canvas, path, paint);

    // Draw arrow pointing to cheek area
    final arrowPaint = Paint()
      ..color = paint.color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final arrowStart = Offset(
      isLeft ? size.width * 0.1 : size.width * 0.9,
      size.height * 0.3,
    );
    final arrowEnd = Offset(
      isLeft ? centerX - radius + 20 : centerX + radius - 20,
      center.dy,
    );

    canvas.drawLine(arrowStart, arrowEnd, arrowPaint);
  }

  void _drawTongueGuide(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final width = size.width * 0.5;
    final height = size.height * 0.4;

    // Draw tongue shape (rounded rectangle)
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      const Radius.circular(40),
    );

    final path = Path()..addRRect(rect);
    _drawDashedPath(canvas, path, paint);

    // Add center line
    final linePaint = Paint()
      ..color = paint.color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx, center.dy - height / 3),
      Offset(center.dx, center.dy + height / 3),
      linePaint,
    );
  }

  void _drawPalateGuide(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final width = size.width * 0.55;
    final height = size.height * 0.35;

    // Draw arch shape for palate
    final path = Path();
    path.moveTo(center.dx - width / 2, center.dy + height / 2);
    path.quadraticBezierTo(
      center.dx,
      center.dy - height / 2,
      center.dx + width / 2,
      center.dy + height / 2,
    );

    _drawDashedPath(canvas, path, paint);

    // Draw horizontal guides
    final linePaint = Paint()
      ..color = paint.color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = center.dy - height / 4 + (height / 4) * i * 0.5;
      canvas.drawLine(
        Offset(center.dx - width / 3, y),
        Offset(center.dx + width / 3, y),
        linePaint,
      );
    }
  }

  void _drawCornerGuides(Canvas canvas, Size size, Paint paint) {
    final cornerLength = 30.0;
    final margin = 40.0;
    final cornerPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin + cornerLength, margin),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin, margin + cornerLength),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin - cornerLength, margin),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin, margin + cornerLength),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin + cornerLength, size.height - margin),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin, size.height - margin - cornerLength),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin - cornerLength, size.height - margin),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin, size.height - margin - cornerLength),
      cornerPaint,
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final dashedPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = paint.strokeWidth;

    final pathMetrics = path.computeMetrics();
    const dashLength = 10.0;
    const gapLength = 8.0;

    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final nextDistance = distance + dashLength;
        final extractPath = metric.extractPath(
          distance,
          nextDistance > metric.length ? metric.length : nextDistance,
        );
        canvas.drawPath(extractPath, dashedPaint);
        distance = nextDistance + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.photoType != photoType || oldDelegate.isReady != isReady;
  }
}
