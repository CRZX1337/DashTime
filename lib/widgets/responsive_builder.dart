import 'package:flutter/material.dart';
import '../config/responsive_util.dart';

/// A widget that builds different UIs based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, DeviceScreenType) builder;
  
  const ResponsiveBuilder({
    super.key, 
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, ResponsiveUtil.getDeviceType(context));
      },
    );
  }
}

/// Widget that switches between different layouts based on screen orientation
class OrientationLayoutBuilder extends StatelessWidget {
  final Widget? portrait;
  final Widget? landscape;
  
  const OrientationLayoutBuilder({
    super.key,
    this.portrait,
    this.landscape,
  }) : assert(portrait != null || landscape != null);

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return landscape ?? portrait!;
        }
        return portrait ?? landscape!;
      },
    );
  }
}

/// A widget that provides different layouts based on screen size
class ScreenTypeLayout extends StatelessWidget {
  final Widget? phoneExtraSmall;
  final Widget? phoneSmall;
  final Widget? phoneMedium;
  final Widget? phoneLarge;
  final Widget? tablet;
  final Widget? desktop;
  
  const ScreenTypeLayout({
    super.key,
    this.phoneExtraSmall,
    this.phoneSmall,
    this.phoneMedium,
    this.phoneLarge,
    this.tablet,
    this.desktop,
  }) : assert(phoneExtraSmall != null || phoneSmall != null || phoneMedium != null || phoneLarge != null || tablet != null || desktop != null);

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        switch (deviceType) {
          case DeviceScreenType.desktop:
            return desktop ?? tablet ?? phoneLarge ?? phoneMedium ?? phoneSmall ?? phoneExtraSmall!;
          case DeviceScreenType.tablet:
            return tablet ?? phoneLarge ?? phoneMedium ?? phoneSmall ?? phoneExtraSmall!;
          case DeviceScreenType.phoneLarge:
            return phoneLarge ?? phoneMedium ?? phoneSmall ?? phoneExtraSmall!;
          case DeviceScreenType.phoneMedium:
            return phoneMedium ?? phoneSmall ?? phoneExtraSmall!;
          case DeviceScreenType.phoneSmall:
            return phoneSmall ?? phoneExtraSmall!;
          case DeviceScreenType.phoneExtraSmall:
            return phoneExtraSmall ?? phoneSmall ?? phoneMedium ?? phoneLarge ?? tablet ?? desktop!;
        }
      },
    );
  }
}

/// A widget that adapts its size based on screen dimensions
class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double? maxWidth;
  final double? maxHeight;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Alignment? alignment;
  final Color? color;
  final bool adaptWidth;
  final bool adaptHeight;
  final double widthPercent;
  final double heightPercent;
  
  const AdaptiveContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.decoration,
    this.padding,
    this.margin,
    this.alignment,
    this.color,
    this.adaptWidth = false,
    this.adaptHeight = false,
    this.widthPercent = 1.0,
    this.heightPercent = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    double? finalWidth = width;
    double? finalHeight = height;
    
    if (adaptWidth) {
      finalWidth = ResponsiveUtil.widthPercent(context, widthPercent);
    }
    
    if (adaptHeight) {
      finalHeight = ResponsiveUtil.heightPercent(context, heightPercent);
    }
    
    return Container(
      width: finalWidth,
      height: finalHeight,
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
        maxHeight: maxHeight ?? double.infinity,
      ),
      decoration: decoration,
      padding: padding,
      margin: margin,
      alignment: alignment,
      color: color,
      child: child,
    );
  }
} 