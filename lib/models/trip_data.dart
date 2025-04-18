import 'package:geolocator/geolocator.dart';

class TripData {
  final DateTime dateTime;
  final double maxSpeed;
  final double avgSpeed; 
  final double distance;
  final int durationSeconds;
  final List<Position> locationHistory;

  TripData({
    required this.dateTime,
    required this.maxSpeed,
    required this.avgSpeed,
    required this.distance,
    required this.durationSeconds,
    required this.locationHistory,
  });

  // Convert to map for storage
  Map<String, dynamic> toJson() {
    return {
      'dateTime': dateTime.toIso8601String(),
      'maxSpeed': maxSpeed,
      'avgSpeed': avgSpeed,
      'distance': distance,
      'durationSeconds': durationSeconds,
      'locationHistory': locationHistory.map((position) => {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': position.timestamp.toIso8601String(),
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'speedAccuracy': position.speedAccuracy,
      }).toList(),
    };
  }

  // Create from map for retrieval
  factory TripData.fromJson(Map<String, dynamic> json) {
    return TripData(
      dateTime: DateTime.parse(json['dateTime']),
      maxSpeed: json['maxSpeed'],
      avgSpeed: json['avgSpeed'],
      distance: json['distance'],
      durationSeconds: json['durationSeconds'],
      locationHistory: (json['locationHistory'] as List).map((item) => 
        Position(
          latitude: item['latitude'],
          longitude: item['longitude'],
          timestamp: DateTime.parse(item['timestamp']),
          accuracy: item['accuracy'],
          altitude: item['altitude'],
          heading: item['heading'],
          speed: item['speed'],
          speedAccuracy: item['speedAccuracy'],
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        )
      ).toList(),
    );
  }

  // Get formatted time
  String getFormattedTime() {
    int minutes = durationSeconds ~/ 60;
    int seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Get formatted distance
  String getFormattedDistance() {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    } else {
      double km = distance / 1000;
      return '${km.toStringAsFixed(2)} km';
    }
  }
} 