import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../config/responsive_util.dart';

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
    // Use responsive utilities to determine sizing based on screen type
    final deviceType = ResponsiveUtil.getDeviceType(context);
    final isLandscape = ResponsiveUtil.isLandscape(context);
    
    // Adjust font sizes based on device type and orientation
    final titleFontSize = ResponsiveUtil.value<double>(
      context: context,
      small: 11.0,
      medium: 12.0,
      large: 13.0,
      tablet: 15.0,
      desktop: 16.0,
    );
    
    final valueFontSize = ResponsiveUtil.value<double>(
      context: context,
      small: 18.0,
      medium: 20.0,
      large: 22.0,
      tablet: 24.0,
      desktop: 28.0,
    );
    
    final unitFontSize = ResponsiveUtil.value<double>(
      context: context,
      small: 11.0,
      medium: 12.0,
      large: 13.0,
      tablet: 15.0,
      desktop: 16.0,
    );
    
    final iconSize = ResponsiveUtil.value<double>(
      context: context,
      small: 18.0,
      medium: 20.0,
      large: 22.0,
      tablet: 24.0,
      desktop: 28.0,
    );
    
    // Adjust padding based on screen size and orientation
    final horizontalPadding = ResponsiveUtil.value<double>(
      context: context,
      small: 6.0,
      medium: 8.0,
      large: 10.0,
      tablet: 12.0,
      desktop: 14.0,
    );
    
    final verticalPadding = ResponsiveUtil.value<double>(
      context: context,
      small: 4.0,
      medium: 6.0,
      large: 8.0,
      tablet: 10.0,
      desktop: 12.0,
    );
    
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
                
                SizedBox(height: deviceType == DeviceScreenType.phoneSmall ? 1 : 2),
                
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
                  height: deviceType == DeviceScreenType.phoneSmall ? 1 : 2,
                  width: ResponsiveUtil.value<double>(
                    context: context,
                    small: 25,
                    medium: 30,
                    large: 35,
                    tablet: 40,
                    desktop: 50,
                  ),
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