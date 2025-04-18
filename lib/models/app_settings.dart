class AppSettings {
  final String speedUnit;
  final String distanceUnit;
  final bool keepScreenOn;
  final int maxSpeedometer; // Maximum speed to show on speedometer

  const AppSettings({
    required this.speedUnit,
    required this.distanceUnit,
    required this.keepScreenOn,
    required this.maxSpeedometer,
  });

  // Default settings
  static const AppSettings defaultSettings = AppSettings(
    speedUnit: 'km/h',
    distanceUnit: 'km',
    keepScreenOn: true,
    maxSpeedometer: 180,
  );

  // Create a copy of this AppSettings with some fields replaced
  AppSettings copyWith({
    String? speedUnit,
    String? distanceUnit,
    bool? keepScreenOn,
    int? maxSpeedometer,
  }) {
    return AppSettings(
      speedUnit: speedUnit ?? this.speedUnit,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      maxSpeedometer: maxSpeedometer ?? this.maxSpeedometer,
    );
  }

  // Convert AppSettings to Map for storage
  Map<String, dynamic> toJson() {
    return {
      'speedUnit': speedUnit,
      'distanceUnit': distanceUnit,
      'keepScreenOn': keepScreenOn,
      'maxSpeedometer': maxSpeedometer,
    };
  }

  // Create AppSettings from Map
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      speedUnit: json['speedUnit'] as String,
      distanceUnit: json['distanceUnit'] as String,
      keepScreenOn: json['keepScreenOn'] as bool,
      maxSpeedometer: json['maxSpeedometer'] as int,
    );
  }
} 