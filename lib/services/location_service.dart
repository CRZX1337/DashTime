import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_settings.dart';

// Import platform specific settings
import 'package:geolocator_android/geolocator_android.dart' if (kIsWeb) 'dart:core';

class LocationService {
  // Singleton instance
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Track settings
  AppSettings? _settings;

  // Set the app settings
  void setSettings(AppSettings settings) {
    _settings = settings;
  }

  // Stream controller for location updates
  final StreamController<Position> _locationController = StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationController.stream;

  // Stream controller for speed updates
  final StreamController<double> _speedController = StreamController<double>.broadcast();
  Stream<double> get speedStream => _speedController.stream;

  // Track history data
  final List<Position> _locationHistory = [];
  List<Position> get locationHistory => _locationHistory;

  // Current tracking state
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  // Current position
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // Recent speed readings for advanced filtering (last 5 readings)
  final Queue<double> _recentSpeedReadings = Queue<double>();
  final int _maxRecentReadings = 5;

  // GPS accuracy tracking
  double _currentAccuracy = 0.0; // In meters
  double get currentAccuracy => _currentAccuracy;

  // Speed stats
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _averageSpeed = 0.0;
  double _rawSpeed = 0.0; // Store raw speed for comparison

  double get currentSpeed => _currentSpeed;
  double get maxSpeed => _maxSpeed;
  double get averageSpeed => _averageSpeed;
  double get rawSpeed => _rawSpeed;

  // For calculating distance
  double _totalDistance = 0.0;
  double get totalDistance => _totalDistance;

  // Last update timestamp for delta calculations
  DateTime? _lastUpdateTime;

  // Start tracking location
  Future<bool> startTracking() async {
    // Always use GPS - removed conditional check
    print("Starting location tracking service...");

    // Check and request permissions
    bool permissionGranted = await _checkLocationPermission();
    if (!permissionGranted) {
      print("Location permissions denied");
      return false;
    }
    
    print("Location permissions granted, initializing tracking...");

    // Clear previous data if any
    _locationHistory.clear();
    _recentSpeedReadings.clear();
    _totalDistance = 0.0;
    _maxSpeed = 0.0;
    _averageSpeed = 0.0;
    _currentSpeed = 0.0;
    _rawSpeed = 0.0;
    _lastUpdateTime = null;

    // Start location tracking
    _isTracking = true;
    
    // Get a high-precision initial position immediately
    try {
      print("Requesting initial position...");
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
      print("Initial position received: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}");
      
      // Set initial accuracy
      if (_currentPosition != null) {
        _currentAccuracy = _currentPosition!.accuracy;
      }
    } catch (e) {
      // If initial position fails, continue anyway
      print('Initial position error: $e');
    }
    
    // Try to start location tracking with primary approach
    try {
      print("Starting position stream...");
      // Configure location settings based on platform
      LocationSettings locationSettings;
      
      // Always use fastest possible update interval - 100ms (10 updates per second)
      // This is the practical limit for most devices
      const int fastestIntervalMs = 100;
      
      if (defaultTargetPlatform == TargetPlatform.android) {
        print("Configuring Android location settings");
        // Android specific settings with fastest possible update interval
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0, // Update continuously 
          intervalDuration: const Duration(milliseconds: fastestIntervalMs),
          // Adjusted for compatibility with Android 13+
          forceLocationManager: true, // Use Android's LocationManager directly for reliability
        );
      } else {
        // Default settings for other platforms
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0, // Update continuously
        );
      }
      
      // Listen to position changes with highest possible accuracy
      print("Subscribing to position stream...");
      var positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      );
      
      positionStream.listen(
        _onPositionUpdate, 
        onError: (error) {
          print('Position stream error: $error');
          _startFallbackTracking(); // Try fallback method if primary fails
        },
        onDone: () {
          print("Position stream closed");
        },
      );
      
      print("Location tracking started successfully");
      return true;
    } catch (e) {
      print('Error starting primary location tracking: $e');
      return _startFallbackTracking(); // Try fallback if primary method fails
    }
  }

  // Stop tracking location
  void stopTracking() {
    _isTracking = false;
    // Calculate final stats
    _calculateAverageSpeed();
  }

  // Handle position updates
  void _onPositionUpdate(Position position) {
    print("Position update received: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m");
    
    // Track GPS accuracy
    _currentAccuracy = position.accuracy;
    _currentPosition = position;
    
    // Calculate time delta between updates for more accurate calculations
    final now = DateTime.now();
    final timeDelta = _lastUpdateTime != null 
        ? now.difference(_lastUpdateTime!).inMilliseconds / 1000 
        : 0.0;
    _lastUpdateTime = now;
    
    // Extract speed (m/s to km/h)
    _rawSpeed = position.speed * 3.6;
    
    // Skip obviously erroneous readings
    if (_rawSpeed > 250) { // Filter out impossible speeds (>250 km/h)
      print("Skipping erroneous speed reading: ${_rawSpeed} km/h");
      return;
    }
    
    // Calculate speed using position delta if speed is very low and we have history
    // This can be more accurate at low speeds
    if (_rawSpeed < 3.0 && _locationHistory.isNotEmpty && timeDelta > 0) {
      final lastPosition = _locationHistory.last;
      final distance = Geolocator.distanceBetween(
        lastPosition.latitude,
        lastPosition.longitude,
        position.latitude,
        position.longitude,
      );
      
      // Only use calculated speed if the positions are accurate enough
      if (lastPosition.accuracy < 20 && position.accuracy < 20) {
        final calculatedSpeed = (distance / timeDelta) * 3.6; // m/s to km/h
        // Use calculated speed if it seems reasonable
        if (calculatedSpeed < 10) {
          print("Using calculated speed: ${calculatedSpeed.toStringAsFixed(2)} km/h (raw: ${_rawSpeed.toStringAsFixed(2)})");
          _rawSpeed = calculatedSpeed;
        }
      }
    }
    
    // Add to recent readings queue
    _recentSpeedReadings.add(_rawSpeed);
    if (_recentSpeedReadings.length > _maxRecentReadings) {
      _recentSpeedReadings.removeFirst();
    }
    
    // Apply advanced filtering and smoothing
    double filteredSpeed = _applySpeedFilter(_rawSpeed);
    
    // Apply adaptive smoothing based on acceleration
    double smoothingFactor = 0.9; // Increased from 0.8 for more responsiveness
    
    // If we have enough readings, adjust smoothing factor based on acceleration
    if (_recentSpeedReadings.length >= 3) {
      // Calculate rate of change in speed
      List<double> speedList = _recentSpeedReadings.toList();
      double acceleration = (speedList.last - speedList[speedList.length - 3]).abs();
      
      // More rapid changes get more weight to current reading
      if (acceleration > 5) {
        smoothingFactor = 0.95; // Higher weight for more responsive updates
      } else if (acceleration < 1) {
        smoothingFactor = 0.8; // Increased from 0.6 for faster updates even when steady
      }
    }
    
    // Apply the adaptive smoothing
    if (_currentSpeed == 0) {
      _currentSpeed = filteredSpeed; // First reading
    } else {
      _currentSpeed = (_currentSpeed * (1 - smoothingFactor)) + (filteredSpeed * smoothingFactor);
    }
    
    // Ensure speed is never negative
    _currentSpeed = math.max(0, _currentSpeed);
    
    // Update max speed if current speed is higher
    if (_currentSpeed > _maxSpeed) {
      _maxSpeed = _currentSpeed;
    }
    
    // Calculate distance if we have previous positions
    if (_locationHistory.isNotEmpty) {
      Position lastPosition = _locationHistory.last;
      
      // Only calculate distance if the accuracy is good enough
      if (position.accuracy < 20 && lastPosition.accuracy < 20) {
        double distance = Geolocator.distanceBetween(
          lastPosition.latitude,
          lastPosition.longitude,
          position.latitude,
          position.longitude,
        );
        
        // Filter out impossibly large jumps that might be GPS errors
        if (distance < 50 || timeDelta > 2) { // 50m jump in less than 2 seconds
          _totalDistance += distance;
        }
      }
    }
    
    // Add to history (but don't add too many points)
    if (_locationHistory.isEmpty || 
        _locationHistory.length < 1000 || 
        _locationHistory.length % 5 == 0) { // Store every 5th position after 1000 points
      _locationHistory.add(position);
    }
    
    // Calculate average speed
    _calculateAverageSpeed();
    
    // Broadcast updates immediately
    _locationController.add(position);
    _speedController.add(_currentSpeed);
  }
  
  // Apply median filtering to remove outliers and smooth speed
  double _applySpeedFilter(double rawSpeed) {
    if (_recentSpeedReadings.length < 3) {
      return rawSpeed; // Not enough data for filtering
    }
    
    // Create a sorted copy of recent readings for median calculation
    List<double> sortedReadings = List.from(_recentSpeedReadings)..sort();
    
    // Calculate median (middle value)
    double median;
    int middle = sortedReadings.length ~/ 2;
    
    if (sortedReadings.length % 2 == 1) {
      median = sortedReadings[middle];
    } else {
      median = (sortedReadings[middle - 1] + sortedReadings[middle]) / 2.0;
    }
    
    // Calculate mean absolute deviation for outlier detection
    double mad = 0;
    for (double reading in sortedReadings) {
      mad += (reading - median).abs();
    }
    mad /= sortedReadings.length;
    
    // If the current reading deviates too much from median, adjust it
    if ((rawSpeed - median).abs() > (mad * 2) && sortedReadings.length >= 3) {
      // Reading is an outlier, use a weighted combination of median and raw
      return (median * 0.7) + (rawSpeed * 0.3);
    }
    
    return rawSpeed;
  }

  // Calculate average speed with improved accuracy
  void _calculateAverageSpeed() {
    if (_locationHistory.isEmpty) {
      _averageSpeed = 0.0;
      return;
    }
    
    // Use weighted average that prioritizes recent speeds
    double totalWeight = 0;
    double weightedSum = 0;
    
    for (int i = 0; i < _locationHistory.length; i++) {
      // More recent positions get higher weight
      double weight = 1 + (i / _locationHistory.length);
      double speed = _locationHistory[i].speed * 3.6; // m/s to km/h
      
      // Extra weight to speeds with good accuracy
      if (_locationHistory[i].accuracy < 10) {
        weight *= 1.5;
      }
      
      weightedSum += speed * weight;
      totalWeight += weight;
    }
    
    _averageSpeed = weightedSum / totalWeight;
  }

  // Check and request location permissions
  Future<bool> _checkLocationPermission() async {
    // Check if location service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location service is not enabled
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    // Check for location permission
    var locationStatus = await Permission.location.status;
    
    // For Android 13+ we need foreground service location permission
    var foregroundServiceStatus = 
        await Permission.locationWhenInUse.status;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        foregroundServiceStatus = await Permission.locationAlways.request();
      } catch (e) {
        print('Error requesting location always permission: $e');
      }
    }

    // Request location permission if needed
    if (locationStatus.isDenied) {
      locationStatus = await Permission.location.request();
      if (locationStatus.isDenied) return false;
    }
    
    // Handle background location for tracking
    if (foregroundServiceStatus.isDenied) {
      // Show message explaining why we need background location
      // This request will likely need to be triggered by user action
      // in the app due to Android requirements
      print('Background location permission needed for accurate tracking');
    }

    // Check if permanently denied
    if (locationStatus.isPermanentlyDenied) {
      // Open app settings for user to manually grant permission
      await openAppSettings();
      return false;
    }

    return true;
  }

  // Fallback tracking method with simpler settings when foreground service fails
  bool _startFallbackTracking() {
    print("Starting fallback location tracking...");
    try {
      // Try direct location manager approach
      if (defaultTargetPlatform == TargetPlatform.android) {
        print("Using Android location manager directly");
        final LocationSettings settings = AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          forceLocationManager: true, // Use Android's LocationManager directly
          timeLimit: const Duration(seconds: 10),
        );
        
        Geolocator.getPositionStream(locationSettings: settings)
          .listen(
            _onPositionUpdate,
            onError: (error) {
              print("Fallback position stream error: $error");
              // Try one last resort approach
              _startLastResortTracking();
            }
          );
          
        return true;
      } else {
        // Basic location settings without foreground service for iOS and other platforms
        const LocationSettings simpleSettings = LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        );
        
        Geolocator.getPositionStream(locationSettings: simpleSettings)
          .listen(_onPositionUpdate);
          
        return true;
      }
    } catch (e) {
      print('Fallback location tracking failed: $e');
      return _startLastResortTracking(); // Try the absolute simplest approach
    }
  }
  
  // Last resort extremely simplified tracking
  bool _startLastResortTracking() {
    print("Starting last resort location tracking...");
    try {
      // Use the simplest possible tracking configuration
      const LocationSettings basicSettings = LocationSettings(
        accuracy: LocationAccuracy.medium, // Less accurate but more reliable
        distanceFilter: 5, // Only update when moved 5 meters
        timeLimit: Duration(seconds: 15),
      );
      
      // Try one last time with minimal settings
      Geolocator.getPositionStream(locationSettings: basicSettings)
        .listen(_onPositionUpdate);
        
      return true;
    } catch (e) {
      print("Last resort tracking failed: $e");
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    _locationController.close();
    _speedController.close();
  }
} 