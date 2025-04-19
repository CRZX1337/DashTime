import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final double borderRadius;
  final double elevation;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.color = AppTheme.primaryColor,
    this.borderRadius = 16.0,
    this.elevation = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    
    // Adjust font sizes based on screen width
    final titleFontSize = isSmallScreen ? 11.0 : 13.0;
    final valueFontSize = isSmallScreen ? 18.0 : 20.0;
    final unitFontSize = isSmallScreen ? 11.0 : 12.0;
    final iconSize = isSmallScreen ? 18.0 : 22.0;
    
    // Adjust padding based on screen size
    final horizontalPadding = isSmallScreen ? 6.0 : 10.0;
    final verticalPadding = isSmallScreen ? 4.0 : 6.0;
    
    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      margin: EdgeInsets.zero,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.cardDark,
              Color.lerp(AppTheme.cardDark, color, 0.1) ?? AppTheme.cardDark,
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate the max width for value text
            final maxValueWidth = constraints.maxWidth - iconSize - 10;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title and icon row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title with overflow protection
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textSecondaryDark,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Icon
                    Icon(
                      icon,
                      color: color,
                      size: iconSize,
                    ),
                  ],
                ),
                
                SizedBox(height: isSmallScreen ? 1 : 2),
                
                // Value and unit row with better overflow handling
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Value with fixed max width
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxValueWidth * 0.8,
                        ),
                        child: Text(
                          value,
                          style: TextStyle(
                            color: AppTheme.textDark,
                            fontSize: valueFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ).animate().fadeIn().slideY(
                          begin: 0.3,
                          end: 0,
                          curve: Curves.easeOutQuart,
                          duration: 300.milliseconds,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Unit
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        unit,
                        style: TextStyle(
                          color: AppTheme.textSecondaryDark,
                          fontSize: unitFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ).animate().fadeIn(delay: 100.milliseconds),
                  ],
                ),
                
                // Decorative bar at bottom
                Container(
                  height: 2,
                  width: 30,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ).animate().fadeIn().slideX(
                  begin: -0.2,
                  end: 0,
                  delay: 200.milliseconds,
                  duration: 300.milliseconds,
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}