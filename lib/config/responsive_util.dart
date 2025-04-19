import 'package:flutter/material.dart';

/// Utility class for responsive design
class ResponsiveUtil {
  /// Screen size breakpoints for responsive design
  static const double phoneExtraSmall = 280; // For extremely small screens like older feature phones
  static const double phoneSmall = 320;
  static const double phoneMedium = 360;
  static const double phoneLarge = 414;
  static const double tablet = 768;
  static const double desktop = 1024;

  /// Get device screen type based on width
  static DeviceScreenType getDeviceType(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width >= desktop) {
      return DeviceScreenType.desktop;
    } else if (width >= tablet) {
      return DeviceScreenType.tablet;
    } else if (width >= phoneLarge) {
      return DeviceScreenType.phoneLarge;
    } else if (width >= phoneMedium) {
      return DeviceScreenType.phoneMedium;
    } else if (width >= phoneSmall) {
      return DeviceScreenType.phoneSmall;
    } else {
      return DeviceScreenType.phoneExtraSmall;
    }
  }

  /// Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Returns a value based on screen size
  /// 
  /// Example:
  /// ```dart
  /// double fontSize = ResponsiveUtil.value(
  ///   context: context,
  ///   extraSmall: 10,
  ///   small: 12,
  ///   medium: 14,
  ///   large: 16,
  ///   tablet: 18,
  ///   desktop: 20,
  /// );
  /// ```
  static T value<T>({
    required BuildContext context,
    T? extraSmall,
    required T small,
    T? medium,
    T? large,
    T? tablet,
    T? desktop,
  }) {
    DeviceScreenType deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceScreenType.desktop:
        return desktop ?? tablet ?? large ?? medium ?? small;
      case DeviceScreenType.tablet:
        return tablet ?? large ?? medium ?? small;
      case DeviceScreenType.phoneLarge:
        return large ?? medium ?? small;
      case DeviceScreenType.phoneMedium:
        return medium ?? small;
      case DeviceScreenType.phoneSmall:
        return small;
      case DeviceScreenType.phoneExtraSmall:
        return extraSmall ?? small;
    }
  }

  /// Dynamically calculates size based on screen width percentage
  static double widthPercent(BuildContext context, double percent) {
    return MediaQuery.of(context).size.width * percent;
  }

  /// Dynamically calculates size based on screen height percentage
  static double heightPercent(BuildContext context, double percent) {
    return MediaQuery.of(context).size.height * percent;
  }

  /// Safely calculates font size that scales with screen size but within limits
  static double scaledFontSize(
    BuildContext context, {
    required double base,
    double minFontSize = 10,
    double maxFontSize = 32,
  }) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scaleFactor = screenWidth / phoneLarge; // Scale relative to standard large phone
    double scaledSize = base * scaleFactor;
    
    return scaledSize.clamp(minFontSize, maxFontSize);
  }

  /// Creates a responsive padding based on screen size
  static EdgeInsets responsivePadding(BuildContext context) {
    return value<EdgeInsets>(
      context: context,
      extraSmall: const EdgeInsets.all(4),
      small: const EdgeInsets.all(8),
      medium: const EdgeInsets.all(12),
      large: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(20),
      desktop: const EdgeInsets.all(24),
    );
  }

  /// Returns a responsive size constraint that adapts to screen width
  static double responsiveWidth(
    BuildContext context, {
    required double percentOfScreen,
    double min = 0,
    double? max,
  }) {
    double width = MediaQuery.of(context).size.width * percentOfScreen;
    if (max != null) {
      return width.clamp(min, max);
    }
    return width < min ? min : width;
  }
}

/// Enum representing device screen types
enum DeviceScreenType {
  phoneExtraSmall,
  phoneSmall,
  phoneMedium,
  phoneLarge,
  tablet,
  desktop,
} 