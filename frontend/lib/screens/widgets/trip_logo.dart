import 'package:flutter/material.dart';

class TripLogo extends StatelessWidget {
  final double size;

  const TripLogo({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.8),
      painter: TripLogoPainter(),
    );
  }
}

class TripLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw the winding path
    final pathPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.85);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.65,
      size.width * 0.30,
      size.height * 0.55,
    );
    path.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.45,
      size.width * 0.45,
      size.height * 0.50,
    );
    path.quadraticBezierTo(
      size.width * 0.55,
      size.height * 0.55,
      size.width * 0.60,
      size.height * 0.40,
    );
    path.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.25,
      size.width * 0.75,
      size.height * 0.20,
    );
    canvas.drawPath(path, pathPaint);

    // Draw mountains in the background
    final mountainPaint = Paint()
      ..color = const Color(0xFF4675B8)
      ..style = PaintingStyle.fill;

    final mountainPath1 = Path();
    mountainPath1.moveTo(size.width * 0.55, size.height * 0.30);
    mountainPath1.lineTo(size.width * 0.68, size.height * 0.10);
    mountainPath1.lineTo(size.width * 0.80, size.height * 0.30);
    mountainPath1.close();
    canvas.drawPath(mountainPath1, mountainPaint);

    final mountainPath2 = Path();
    mountainPath2.moveTo(size.width * 0.65, size.height * 0.30);
    mountainPath2.lineTo(size.width * 0.76, size.height * 0.15);
    mountainPath2.lineTo(size.width * 0.87, size.height * 0.30);
    mountainPath2.close();
    canvas.drawPath(mountainPath2, mountainPaint);

    // Draw snow caps on mountains
    final snowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final snowPath1 = Path();
    snowPath1.moveTo(size.width * 0.65, size.height * 0.16);
    snowPath1.lineTo(size.width * 0.68, size.height * 0.10);
    snowPath1.lineTo(size.width * 0.71, size.height * 0.16);
    snowPath1.close();
    canvas.drawPath(snowPath1, snowPaint);

    final snowPath2 = Path();
    snowPath2.moveTo(size.width * 0.73, size.height * 0.21);
    snowPath2.lineTo(size.width * 0.76, size.height * 0.15);
    snowPath2.lineTo(size.width * 0.79, size.height * 0.21);
    snowPath2.close();
    canvas.drawPath(snowPath2, snowPaint);

    // Draw tree on the left
    final treeTrunkPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.17,
        size.height * 0.70,
        size.width * 0.015,
        size.height * 0.10,
      ),
      treeTrunkPaint,
    );

    // Tree foliage
    final treeFoliagePaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.1775, size.height * 0.70),
      size.width * 0.025,
      treeFoliagePaint,
    );

    // Draw sailboat
    final boatPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    // Boat hull
    final boatPath = Path();
    boatPath.moveTo(size.width * 0.42, size.height * 0.52);
    boatPath.lineTo(size.width * 0.48, size.height * 0.52);
    boatPath.lineTo(size.width * 0.47, size.height * 0.54);
    boatPath.lineTo(size.width * 0.43, size.height * 0.54);
    boatPath.close();
    canvas.drawPath(boatPath, boatPaint);

    // Boat mast
    canvas.drawLine(
      Offset(size.width * 0.45, size.height * 0.52),
      Offset(size.width * 0.45, size.height * 0.42),
      Paint()
        ..color = Colors.black87
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Boat sail
    final sailPath = Path();
    sailPath.moveTo(size.width * 0.45, size.height * 0.43);
    sailPath.lineTo(size.width * 0.45, size.height * 0.52);
    sailPath.lineTo(size.width * 0.41, size.height * 0.49);
    sailPath.close();
    canvas.drawPath(sailPath, boatPaint);

    // Draw blue dot on the path
    final blueDotPaint = Paint()
      ..color = const Color(0xFF4675B8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.30, size.height * 0.65),
      size.width * 0.015,
      blueDotPaint,
    );

    // Draw birds
    final birdPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Bird 1
    final bird1 = Path();
    bird1.moveTo(size.width * 0.82, size.height * 0.08);
    bird1.lineTo(size.width * 0.84, size.height * 0.06);
    bird1.lineTo(size.width * 0.86, size.height * 0.08);
    canvas.drawPath(bird1, birdPaint);

    // Bird 2
    final bird2 = Path();
    bird2.moveTo(size.width * 0.88, size.height * 0.06);
    bird2.lineTo(size.width * 0.90, size.height * 0.04);
    bird2.lineTo(size.width * 0.92, size.height * 0.06);
    canvas.drawPath(bird2, birdPaint);

    // Bird 3
    final bird3 = Path();
    bird3.moveTo(size.width * 0.85, size.height * 0.12);
    bird3.lineTo(size.width * 0.87, size.height * 0.10);
    bird3.lineTo(size.width * 0.89, size.height * 0.12);
    canvas.drawPath(bird3, birdPaint);

    // Draw subtle city/buildings silhouette on the right (optional detail)
    final buildingPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.82,
        size.height * 0.25,
        size.width * 0.025,
        size.height * 0.05,
      ),
      buildingPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.85,
        size.height * 0.27,
        size.width * 0.020,
        size.height * 0.03,
      ),
      buildingPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.88,
        size.height * 0.26,
        size.width * 0.022,
        size.height * 0.04,
      ),
      buildingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
