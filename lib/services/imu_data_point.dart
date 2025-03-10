import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nano33_ble_imu/screens/home_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class IMUDataPoint {
  final DateTime time;
  final double value;
  
  IMUDataPoint(this.time, this.value);
}

class OrientationPainter extends CustomPainter {
  final double accelX, accelY, accelZ;
  final double gyroX, gyroY, gyroZ;
  
  OrientationPainter({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = min(centerX, centerY) * 0.8;
    
    // Draw background
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // Draw coordinate system
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // X axis - red
    canvas.drawLine(
      Offset(centerX - radius, centerY),
      Offset(centerX + radius, centerY),
      Paint()..color = Colors.red..strokeWidth = 2,
    );
    
    // Y axis - green
    canvas.drawLine(
      Offset(centerX, centerY - radius),
      Offset(centerX, centerY + radius),
      Paint()..color = Colors.green..strokeWidth = 2,
    );
    
    // Calculate tilt based on accelerometer readings
    double normFactor = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
    if (normFactor > 0) {
      double xNorm = accelX / normFactor;
      double yNorm = accelY / normFactor;
      
      // Calculate tilt angle
      double tiltX = asin(xNorm) * 180 / pi;
      double tiltY = asin(yNorm) * 180 / pi;
      
      // Draw device orientation
      final deviceWidth = radius * 0.6;
      final deviceHeight = radius * 0.3;
      
      // Create a transformation that applies the tilt
      final rotationMatrix = Matrix4.identity()
        ..rotateX(tiltY * pi / 180)
        ..rotateY(-tiltX * pi / 180);
      
      // Corners of the device rectangle (centered at origin)
      List<Offset> corners = [
        Offset(-deviceWidth/2, -deviceHeight/2),
        Offset(deviceWidth/2, -deviceHeight/2),
        Offset(deviceWidth/2, deviceHeight/2),
        Offset(-deviceWidth/2, deviceHeight/2),
      ];
      
      // Apply transformation to each corner and move to canvas center
      final transformedCorners = corners.map((corner) {
        final vector = Vector3(corner.dx, corner.dy, 0);
        final transformed = rotationMatrix.transform3(vector);
        return Offset(
          centerX + transformed.x,
          centerY + transformed.y,
        );
      }).toList();
      
      // Draw the transformed device
      final devicePaint = Paint()
        ..color = Colors.blue.withOpacity(0.7)
        ..style = PaintingStyle.fill;
      
      final deviceOutlinePaint = Paint()
        ..color = Colors.blue.shade900
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      
      final devicePath = Path()
        ..moveTo(transformedCorners[0].dx, transformedCorners[0].dy)
        ..lineTo(transformedCorners[1].dx, transformedCorners[1].dy)
        ..lineTo(transformedCorners[2].dx, transformedCorners[2].dy)
        ..lineTo(transformedCorners[3].dx, transformedCorners[3].dy)
        ..close();
      
      canvas.drawPath(devicePath, devicePaint);
      canvas.drawPath(devicePath, deviceOutlinePaint);
      
      // Draw text showing tilt angles
      final textStyle = TextStyle(
        color: Colors.black,
        fontSize: 12,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Tilt X: ${tiltX.toStringAsFixed(1)}°\nTilt Y: ${tiltY.toStringAsFixed(1)}°',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, 10));
    }
  }
  
  @override
  bool shouldRepaint(covariant OrientationPainter oldDelegate) {
    return oldDelegate.accelX != accelX ||
           oldDelegate.accelY != accelY ||
           oldDelegate.accelZ != accelZ ||
           oldDelegate.gyroX != gyroX ||
           oldDelegate.gyroY != gyroY ||
           oldDelegate.gyroZ != gyroZ;
  }
}
