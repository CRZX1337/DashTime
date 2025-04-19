import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';

class Speedometer extends StatelessWidget {
  final double speed;
  final double maxSpeed;
  final double size;
  final String unit;

  const Speedometer({
    super.key,
    required this.speed,
    this.maxSpeed = 180.0,
    this.size = 300.0,
    this.unit = 'km/h',
  });

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate dynamic size based on screen width with constraints
    final dynamicSize = min(size, screenSize.width * 0.8);
    final safeSize = min(dynamicSize, screenSize.height * 0.45);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Apply additional constraints if needed
        final constrainedSize = min(safeSize, constraints.maxWidth * 0.95);
        
        return SizedBox(
          width: constrainedSize,
          height: constrainedSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: constrainedSize,
                height: constrainedSize,
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
              
              // Speedometer arc - fills based on current/max speed
              CustomPaint(
                size: Size(constrainedSize * 0.92, constrainedSize * 0.92),
                painter: SpeedometerPainter(
                  speed: speed,
                  maxSpeed: maxSpeed,
                ),
              ),
              
              // Small indicator dot at outer edge that moves with speed
              _buildSpeedIndicator(constrainedSize),
              
              // Speed value display - clean with no box/background
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Speed value
                  Text(
                    speed.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: constrainedSize * 0.22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ).animate().fadeIn().slideY(
                    begin: 0.3,
                    end: 0,
                    curve: Curves.easeOutQuart,
                    duration: 150.milliseconds,
                  ),
                  // Speed unit
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: constrainedSize * 0.08,
                      color: AppTheme.textSecondaryDark,
                    ),
                  ).animate().fadeIn().scale(
                    delay: 50.milliseconds,
                    duration: 100.milliseconds,
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
  
  // Generate no ticks for a cleaner look
  List<Widget> _buildSpeedTicks() {
    // Return an empty list - no ticks displayed
    return [];
  }
  
  // Build the small indicator dot that moves around the outer edge
  Widget _buildSpeedIndicator(double constrainedSize) {
    // Calculate angle based on speed with the gap adjustment
    final double angle = _calculateAngle();
    
    // Calculate position on the outer edge
    final double radius = constrainedSize * 0.46; // Position near the edge
    final double x = cos(angle) * radius;
    final double y = sin(angle) * radius;
    
    // Determine color based on speed ratio
    double speedRatio = speed / maxSpeed;
    Color indicatorColor;
    
    if (speedRatio < 0.3) {
      indicatorColor = Colors.green;
    } else if (speedRatio < 0.6) {
      indicatorColor = Colors.yellowAccent;
    } else if (speedRatio < 0.8) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = Colors.red;
    }
    
    // Calculate dot size based on constrained size
    final dotSize = constrainedSize * 0.035;
    final halfDotSize = dotSize / 2;
    
    return Positioned(
      left: constrainedSize / 2 + x - halfDotSize,
      top: constrainedSize / 2 + y - halfDotSize,
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: indicatorColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: indicatorColor.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    ).animate().custom(
      duration: 150.milliseconds,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final animatedAngle = _calculateAngle();
        final double animatedX = cos(animatedAngle) * radius;
        final double animatedY = sin(animatedAngle) * radius;
        
        return Positioned(
          left: constrainedSize / 2 + animatedX - halfDotSize,
          top: constrainedSize / 2 + animatedY - halfDotSize,
          child: child!,
        );
      },
    );
  }

  // Calculate angle for speed indicator based on speed relative to maxSpeed
  double _calculateAngle() {
    // Add a small gap at the top to match the arc
    final double gapAngle = 0.1;
    
    // Calculate angle based on speed with the gap adjustment
    double normalizedSpeed = min(speed, maxSpeed);
    return -pi / 2 + gapAngle / 2 + (normalizedSpeed / maxSpeed) * (2 * pi - gapAngle);
  }
}

// Custom painter for speedometer arc
class SpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;

  SpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2,
    );

    // Small gap at the top (in radians)
    final double gapAngle = 0.1;

    // Draw background arc - almost full circle with small gap at top
    arcPaint.color = Colors.grey.shade800;
    canvas.drawArc(
      rect,
      -pi / 2 + gapAngle / 2, // Start slightly after top
      2 * pi - gapAngle, // Almost full circle with small gap
      false,
      arcPaint,
    );

    // Calculate gradient positions
    final double normalizedSpeed = min(speed, maxSpeed);
    final double speedRatio = normalizedSpeed / maxSpeed;
    // Arc length with adjustment for the gap
    final double arcLength = (2 * pi - gapAngle) * speedRatio;

    // Draw speed gradient arc - this fills proportionally to speed/maxSpeed
    final Gradient gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: 3 * pi / 2, // Full circle range
      colors: const [
        Colors.green,
        Colors.yellowAccent,
        Colors.orange,
        Colors.red,
        Colors.red,
      ],
      stops: const [0.2, 0.4, 0.6, 0.8, 1.0],
      transform: GradientRotation(-pi / 2),
    );

    arcPaint.shader = gradient.createShader(rect);
    
    // Draw the speed arc - length is based on current speed vs max speed
    canvas.drawArc(
      rect,
      -pi / 2 + gapAngle / 2, // Start slightly after top
      arcLength, // Arc based on speed with gap adjustment
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed;
  }
} 