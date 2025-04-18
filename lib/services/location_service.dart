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

  // Simulation mode properties
  bool _isSimulationMode = false;
  double _simulatedSpeed = 0.0;
  Timer? _simulationTimer;
  final math.Random _random = math.Random();
  
  // Additional properties for more realistic simulation
  String _demoScenario = 'city'; // city, highway, racetrack, mountain
  int _scenarioPhase = 0; // Used to track phases of the scenario
  int _phaseCounter = 0; // Counter within each phase
  double _targetSpeed = 0.0; // Target speed for acceleration/deceleration
  double _accelerationRate = 1.0; // Controls how quickly speed changes (1.0 = normal, 2.0 = twice as fast)
  
  // Getters for simulation status
  bool get isSimulationMode => _isSimulationMode;
  double get simulatedSpeed => _simulatedSpeed;

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
    // Special handling for simulation mode
    if (_isSimulationMode) {
      // Check if this is a real GPS update by checking timestamp type
      // Our simulated positions use local time (non-UTC)
      bool isRealGpsUpdate = position.timestamp.isUtc;
      
      if (isRealGpsUpdate) {
        // In simulation mode, we only take real GPS updates to update our position reference
        // but we don't process them for speed/distance as that would conflict with simulation
        _currentPosition = position;
        print("Real GPS update received during simulation - updating reference position only");
        return;
      }
    }
    
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
    
    // In simulation mode, use the simulated speed directly without smoothing
    if (_isSimulationMode) {
      _currentSpeed = _simulatedSpeed;
    } else {
      // Apply the adaptive smoothing
      if (_currentSpeed == 0) {
        _currentSpeed = filteredSpeed; // First reading
      } else {
        _currentSpeed = (_currentSpeed * (1 - smoothingFactor)) + (filteredSpeed * smoothingFactor);
      }
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

  // Enable simulation mode with a specific speed
  void enableSimulation(double speed, {double accelerationRate = 1.0}) {
    _simulatedSpeed = 0.0; // Start from zero and accelerate to target
    _targetSpeed = speed;
    _accelerationRate = accelerationRate.clamp(0.1, 5.0); // Limit to reasonable values
    _isSimulationMode = true;
    _scenarioPhase = 0;
    _phaseCounter = 0;
    
    // If no current position exists, create a default one
    if (_currentPosition == null) {
      print("No initial position, creating default position for simulation");
      _currentPosition = Position(
        latitude: 37.4220, // Default location (Google HQ)
        longitude: -122.0841,
        timestamp: DateTime.now(),
        accuracy: 3.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
    }
    
    // Set demo scenario based on target speed
    if (speed <= 40) {
      _demoScenario = 'city';
    } else if (speed <= 80) {
      _demoScenario = 'mountain';
    } else if (speed <= 120) {
      _demoScenario = 'highway';
    } else {
      _demoScenario = 'racetrack';
    }
    
    // Start simulation timer if not already running
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!_isSimulationMode) {
        timer.cancel();
        return;
      }
      
      _generateSimulatedLocation();
    });
    
    print("Location simulation enabled with speed: $_targetSpeed km/h, acceleration: $_accelerationRate, scenario: $_demoScenario");
  }
  
  // Disable simulation mode
  void disableSimulation() {
    _isSimulationMode = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _simulatedSpeed = 0.0;
    
    print("Location simulation disabled");
  }
  
  // Generate simulated location data based on current position and simulated speed
  void _generateSimulatedLocation() {
    if (!_isSimulationMode || _currentPosition == null) return;
    
    // Update the simulated speed based on scenario
    _updateSimulatedSpeed();
    
    // Speed is in km/h, convert to m/s for calculations
    final speedMps = _simulatedSpeed / 3.6;
    
    // Current coordinates
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    
    // Distance traveled in simulation interval (in meters)
    final distance = speedMps * 0.8; // t = 0.8 second
    
    // Generate heading based on scenario
    double heading = _generateRealisticHeading();
    
    // Convert heading to radians
    final headingRad = heading * math.pi / 180;
    
    // Earth's radius in meters
    const earthRadius = 6378137.0;
    
    // Calculate new position using flat earth approximation
    final newLat = lat + (distance * math.cos(headingRad)) / (earthRadius * math.pi / 180);
    final newLng = lng + (distance * math.sin(headingRad)) / (earthRadius * math.cos(lat * math.pi / 180) * math.pi / 180);
    
    // Create simulated position
    final simulatedPosition = Position(
      latitude: newLat,
      longitude: newLng,
      timestamp: DateTime.now(),
      accuracy: 3.0, // Good GPS accuracy
      altitude: _currentPosition!.altitude,
      heading: heading,
      speed: speedMps, // speed in m/s
      speedAccuracy: 1.0,
      altitudeAccuracy: 1.0,
      headingAccuracy: 1.0,
    );
    
    // Force direct speed update for simulation
    _currentSpeed = _simulatedSpeed;
    
    // Process the simulated position as if it came from GPS
    _onPositionUpdate(simulatedPosition);
    
    // Directly broadcast speed update to ensure UI gets notified
    _speedController.add(_currentSpeed);
    
    print("Simulated speed: $_simulatedSpeed km/h");
  }
  
  // Generate a realistic heading based on scenario
  double _generateRealisticHeading() {
    double heading = _currentPosition!.heading;
    
    switch (_demoScenario) {
      case 'city':
        // City driving has frequent turns
        if (_phaseCounter % 10 == 0) {
          // Make occasional sharp turns (90 degrees +/- 20)
          heading = (heading + (90 * (_random.nextBool() ? 1 : -1) + (_random.nextDouble() * 40 - 20))) % 360;
        } else {
          // Smaller corrections
          heading = (heading + (_random.nextDouble() * 10 - 5)) % 360;
        }
        break;
        
      case 'highway':
        // Highway has very slight curves
        heading = (heading + (_random.nextDouble() * 2 - 1)) % 360;
        break;
        
      case 'racetrack':
        // Racetrack has rhythmic turns
        if (_phaseCounter % 15 == 0) {
          // Sharp turn in alternating directions
          final turnDirection = _scenarioPhase % 2 == 0 ? 1 : -1;
          heading = (heading + (60 * turnDirection)) % 360;
        } else {
          // Straight sections
          heading = (heading + (_random.nextDouble() * 1 - 0.5)) % 360;
        }
        break;
        
      case 'mountain':
        // Mountain roads have consistent winding
        if (_phaseCounter % 8 == 0) {
          // Alternating moderate turns
          final turnDirection = _scenarioPhase % 2 == 0 ? 1 : -1;
          heading = (heading + (30 * turnDirection + (_random.nextDouble() * 10 - 5))) % 360;
        } else {
          // Slight corrections
          heading = (heading + (_random.nextDouble() * 5 - 2.5)) % 360;
        }
        break;
        
      default:
        // Default small variation
        heading = (heading + (_random.nextDouble() * 6 - 3)) % 360;
    }
    
    return heading;
  }
  
  // Update the simulated speed based on scenario
  void _updateSimulatedSpeed() {
    _phaseCounter++;
    
    // Regular scenario phase transitions
    if (_phaseCounter >= 20) {
      _phaseCounter = 0;
      _scenarioPhase = (_scenarioPhase + 1) % 5; // 5 phases in each scenario
    }
    
    // Calculate speed pattern based on scenario
    switch (_demoScenario) {
      case 'city':
        _updateCityDriving();
        break;
        
      case 'highway':
        _updateHighwayDriving();
        break;
        
      case 'racetrack':
        _updateRacetrackDriving();
        break;
        
      case 'mountain':
        _updateMountainDriving();
        break;
        
      default:
        // Simple approach for default
        _simulatedSpeed = _targetSpeed + (_random.nextDouble() * 5 - 2.5);
    }
    
    // Ensure speed is never negative
    _simulatedSpeed = math.max(0, _simulatedSpeed);
  }
  
  // City driving patterns (stop and go traffic, traffic lights)
  void _updateCityDriving() {
    switch (_scenarioPhase) {
      case 0: // Accelerating from stop
        _simulatedSpeed = math.min(_targetSpeed, _simulatedSpeed + (3.0 * _accelerationRate));
        break;
        
      case 1: // Cruising
        _simulatedSpeed = _targetSpeed + (_random.nextDouble() * 5 - 2.5);
        break;
        
      case 2: // Slowing for traffic/light
        _simulatedSpeed = math.max(5, _simulatedSpeed - (2.0 * _accelerationRate));
        break;
        
      case 3: // Stopped or very slow
        _simulatedSpeed = math.max(0, _simulatedSpeed - (2.5 * _accelerationRate));
        if (_simulatedSpeed < 3) _simulatedSpeed = 0;
        break;
        
      case 4: // Accelerating again
        _simulatedSpeed = math.min(_targetSpeed, _simulatedSpeed + (2.5 * _accelerationRate));
        break;
    }
  }
  
  // Highway driving patterns (consistent high speed with occasional slowdowns)
  void _updateHighwayDriving() {
    switch (_scenarioPhase) {
      case 0: // Accelerating to highway speed
        _simulatedSpeed = math.min(_targetSpeed, _simulatedSpeed + (2.0 * _accelerationRate));
        break;
        
      case 1: // Cruising at target
        _simulatedSpeed = _targetSpeed + (_random.nextDouble() * 5 - 2.5);
        break;
        
      case 2: // Slight slowdown (traffic)
        _simulatedSpeed = math.max(_targetSpeed * 0.7, _simulatedSpeed - (1.0 * _accelerationRate));
        break;
        
      case 3: // Resuming speed
        _simulatedSpeed = math.min(_targetSpeed, _simulatedSpeed + (1.5 * _accelerationRate));
        break;
        
      case 4: // Slight variation in speed
        _simulatedSpeed = _targetSpeed + (_random.nextDouble() * 8 - 4);
        break;
    }
  }
  
  // Racetrack driving patterns (high speed, hard acceleration and braking)
  void _updateRacetrackDriving() {
    switch (_scenarioPhase) {
      case 0: // Hard acceleration
        _simulatedSpeed = math.min(_targetSpeed * 1.1, _simulatedSpeed + (5.0 * _accelerationRate));
        break;
        
      case 1: // Top speed on straight
        _simulatedSpeed = _targetSpeed + (_random.nextDouble() * 10);
        break;
        
      case 2: // Hard braking for turn
        _simulatedSpeed = math.max(_targetSpeed * 0.6, _simulatedSpeed - (4.0 * _accelerationRate));
        break;
        
      case 3: // Through the turn
        _simulatedSpeed = _simulatedSpeed - (1.0 * _accelerationRate) + (_random.nextDouble() * 2);
        break;
        
      case 4: // Accelerating out of turn
        _simulatedSpeed = math.min(_targetSpeed, _simulatedSpeed + (4.0 * _accelerationRate));
        break;
    }
  }
  
  // Mountain driving patterns (winding roads, varied speeds)
  void _updateMountainDriving() {
    switch (_scenarioPhase) {
      case 0: // Uphill section
        _simulatedSpeed = math.max(_targetSpeed * 0.7, _simulatedSpeed - (1.0 * _accelerationRate));
        break;
        
      case 1: // Cruising on straight section
        _simulatedSpeed = _targetSpeed + (_random.nextDouble() * 5 - 2.5);
        break;
        
      case 2: // Slowing for curve
        _simulatedSpeed = math.max(_targetSpeed * 0.5, _simulatedSpeed - (2.0 * _accelerationRate));
        break;
        
      case 3: // Through tight curves
        _simulatedSpeed = _targetSpeed * 0.6 + (_random.nextDouble() * 5 - 2.5);
        break;
        
      case 4: // Accelerating on straightaway
        _simulatedSpeed = math.min(_targetSpeed, _simulatedSpeed + (2.0 * _accelerationRate));
        break;
    }
  }

  // Dispose resources
  void dispose() {
    _locationController.close();
    _speedController.close();
  }
} 