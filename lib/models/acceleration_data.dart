import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class AccelerationData {
  final DateTime dateTime;
  final double startSpeed;
  final double targetSpeed;
  final double achievedSpeed;
  final int elapsedMilliseconds;
  final bool targetReached;
  final String speedUnit;

  AccelerationData({
    required this.dateTime,
    required this.startSpeed,
    required this.targetSpeed,
    required this.achievedSpeed,
    required this.elapsedMilliseconds,
    required this.targetReached,
    required this.speedUnit,
  });

  // Convert to map for storage
  Map<String, dynamic> toJson() {
    return {
      'dateTime': dateTime.toIso8601String(),
      'startSpeed': startSpeed,
      'targetSpeed': targetSpeed,
      'achievedSpeed': achievedSpeed,
      'elapsedMilliseconds': elapsedMilliseconds,
      'targetReached': targetReached,
      'speedUnit': speedUnit,
    };
  }

  // Create from map for retrieval
  factory AccelerationData.fromJson(Map<String, dynamic> json) {
    return AccelerationData(
      dateTime: DateTime.parse(json['dateTime']),
      startSpeed: json['startSpeed'],
      targetSpeed: json['targetSpeed'],
      achievedSpeed: json['achievedSpeed'],
      elapsedMilliseconds: json['elapsedMilliseconds'],
      targetReached: json['targetReached'],
      speedUnit: json['speedUnit'],
    );
  }

  // Get formatted time in seconds
  String getFormattedTime() {
    int minutes = (elapsedMilliseconds ~/ 60000) % 60;
    int seconds = (elapsedMilliseconds ~/ 1000) % 60;
    int milliseconds = (elapsedMilliseconds % 1000) ~/ 10;
    
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
  }
  
  // Get formatted date
  String getFormattedDate() {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }
  
  // Get formatted time of day
  String getFormattedTimeOfDay() {
    return DateFormat('hh:mm a').format(dateTime);
  }
  
  // Get description of the acceleration test
  String getTestDescription() {
    if (targetReached) {
      return '0-$targetSpeed $speedUnit in ${getFormattedTime()}';
    } else {
      return 'Reached ${achievedSpeed.toStringAsFixed(1)} $speedUnit of $targetSpeed $speedUnit';
    }
  }
} 