import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/location_service.dart';
import '../services/trip_storage_service.dart';
import '../services/settings_service.dart';
import '../models/trip_data.dart';
import '../models/app_settings.dart';
import '../widgets/speedometer.dart';
import '../widgets/stats_card.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class SpeedometerScreen extends StatefulWidget {
  const SpeedometerScreen({super.key});

  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen>
    with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _avgSpeed = 0.0;
  double _distance = 0.0;
  bool _isTracking = false;
  bool _hasUnsavedTrip = false;
  bool _isSaving = false;
  bool _isDiscarding = false;
  bool _isExiting = false;
  late AnimationController _animationController;
  late AnimationController _saveButtonController;
  late AnimationController _discardButtonController;
  late AnimationController _containerExitController;

  // Timer related variables
  int _elapsedSeconds = 0;
  Timer? _timer;
  String _formattedTime = '00:00';

  StreamSubscription<double>? _speedSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _saveButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _discardButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _containerExitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Initial location setup
    _checkLocationService();
  }

  // Check location service on startup
  Future<void> _checkLocationService() async {
    bool available = await _locationService.startTracking();
    if (!available && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enable location services to use the speedometer',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    } else if (available) {
      // If we started tracking during the check, stop it until user explicitly starts
      _locationService.stopTracking();
      
      // If using simulation, make sure it's prepared but not running yet
      if (_locationService.isSimulationMode) {
        // Reset state for when user presses start
        _locationService.resetDemoState();
      }
    }
  }

  @override
  void dispose() {
    _speedSubscription?.cancel();
    _timer?.cancel();
    _animationController.dispose();
    _saveButtonController.dispose();
    _discardButtonController.dispose();
    _containerExitController.dispose();

    // Make sure to stop tracking when the screen is closed
    if (_isTracking) {
      _locationService.stopTracking();
    }

    super.dispose();
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      // Stop tracking
      _locationService.stopTracking();
      
      // If in simulation mode, stop the demo movement
      if (_locationService.isSimulationMode) {
        _locationService.stopDemoMovement();
      }
      
      _speedSubscription?.cancel();
      _timer?.cancel();
      _animationController.reverse();

      // Set both state variables in a single setState call
      setState(() {
        _isTracking = false;
        _hasUnsavedTrip = true;
        print("DEBUG: _isTracking set to false, _hasUnsavedTrip set to true");
      });
      
      // Apply screen settings from user preferences
      final settings = Provider.of<SettingsService>(context, listen: false).settings;
      WakelockPlus.toggle(enable: settings.keepScreenOn);
    } else {
      // Start tracking
      bool success = await _locationService.startTracking();
      if (success) {
        // Reset timer
        _elapsedSeconds = 0;
        _formattedTime = '00:00';

        // Reset hasUnsavedTrip flag and set tracking state
        setState(() {
          _isTracking = true;
          _hasUnsavedTrip = false;
          print("DEBUG: _isTracking set to true, _hasUnsavedTrip set to false");
        });

        // Force screen to stay on during tracking
        WakelockPlus.toggle(enable: true);
        
        // If in simulation mode, start the demo movement
        if (_locationService.isSimulationMode) {
          _locationService.startDemoMovement();
        }
        
        // Start the timer
        _startTimer();

        // Listen to speed updates
        _speedSubscription = _locationService.speedStream.listen(_updateSpeed);
        _animationController.forward();
      } else {
        // Show error snackbar if location permission denied
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
  }

  // Start the timer for tracking duration
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
          _updateFormattedTime();
        });
      }
    });
  }

  // Format the timer display
  void _updateFormattedTime() {
    int minutes = _elapsedSeconds ~/ 60;
    int seconds = _elapsedSeconds % 60;
    _formattedTime =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _updateSpeed(double speed) {
    if (mounted) {
      final settings = Provider.of<SettingsService>(context, listen: false).settings;
      
      // Get the received speed in km/h and convert if needed
      double displaySpeed = speed;
      double maxSpeedValue = _locationService.maxSpeed;
      double avgSpeedValue = _locationService.averageSpeed;
      
      // Convert to mph if needed
      if (settings.speedUnit == 'mph') {
        displaySpeed = speed * 0.621371;
        maxSpeedValue = maxSpeedValue * 0.621371;
        avgSpeedValue = avgSpeedValue * 0.621371;
      }
      // Convert to m/s if needed
      else if (settings.speedUnit == 'm/s') {
        displaySpeed = speed / 3.6;
        maxSpeedValue = maxSpeedValue / 3.6;
        avgSpeedValue = avgSpeedValue / 3.6;
      }
      
      // Use setState to immediately update the UI with the new speed
      setState(() {
        _currentSpeed = displaySpeed;
        _maxSpeed = maxSpeedValue;
        _avgSpeed = avgSpeedValue;
        _distance = _locationService.totalDistance;
      });
    }
  }

  String _formatDistance(double meters) {
    final settings = Provider.of<SettingsService>(context, listen: false).settings;
    
    if (settings.distanceUnit == 'km') {
      if (meters < 1000) {
        return meters.toStringAsFixed(0);
      } else {
        double km = meters / 1000;
        return km.toStringAsFixed(2);
      }
    } else if (settings.distanceUnit == 'miles') {
      double miles = meters / 1609.34;
      if (miles < 0.1) {
        // If less than 0.1 miles, show in feet
        double feet = meters * 3.28084;
        return feet.toStringAsFixed(0);
      } else {
        return miles.toStringAsFixed(2);
      }
    } else {
      // Unit is meters
      return meters.toStringAsFixed(0);
    }
  }

  // Determine the unit for distance display
  String _getDistanceUnit(double meters) {
    final settings = Provider.of<SettingsService>(context, listen: false).settings;
    
    if (settings.distanceUnit == 'km') {
      return meters < 1000 ? 'm' : 'km';
    } else if (settings.distanceUnit == 'miles') {
      return meters < 160.934 ? 'ft' : 'mi';
    } else {
      return 'm';
    }
  }

  // Get GPS accuracy level based on accuracy in meters
  String _getGpsAccuracyLevel() {
    double accuracy = _locationService.currentAccuracy;

    if (accuracy <= 0) {
      return 'Unknown';
    } else if (accuracy < 8) {
      return 'Excellent (±${accuracy.toStringAsFixed(1)}m)';
    } else if (accuracy < 15) {
      return 'Good (±${accuracy.toStringAsFixed(1)}m)';
    } else if (accuracy < 30) {
      return 'Moderate (±${accuracy.toStringAsFixed(1)}m)';
    } else {
      return 'Poor (±${accuracy.toStringAsFixed(1)}m)';
    }
  }

  // Get color based on GPS accuracy
  Color _getGpsAccuracyColor() {
    double accuracy = _locationService.currentAccuracy;

    if (accuracy <= 0) {
      return Colors.grey;
    } else if (accuracy < 8) {
      return Colors.green;
    } else if (accuracy < 15) {
      return Colors.lightGreen;
    } else if (accuracy < 30) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context).settings;
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // App bar with back button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _hasUnsavedTrip ? _showExitDialog : () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Speedometer',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Check if we're in a very small screen (either height or width limited)
                    final isCompactScreen = constraints.maxHeight < 550 || constraints.maxWidth < 350;
                    
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactScreen ? 12 : 20,
                        vertical: isCompactScreen ? 8 : 16
                      ),
                      child: Column(
                        children: [
                          // Speedometer with adaptive sizing
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate safe speedometer size based on screen dimensions
                              final screenWidth = MediaQuery.of(context).size.width;
                              final screenHeight = MediaQuery.of(context).size.height;
                              final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                              
                              // Calculate base size with a different approach for portrait/landscape
                              final baseSize = isLandscape 
                                  ? min(screenWidth * 0.5, screenHeight * 0.7)
                                  : min(screenWidth * 0.85, screenHeight * 0.4);
                              
                              // Ensure the speedometer size is reasonable with hard limits
                              final safeSize = baseSize.clamp(
                                200.0,  // Minimum size 
                                min(screenWidth * 0.85, 400.0)  // Maximum size
                              ).toDouble();
                              
                              return Center(
                                child: Speedometer(
                                  speed: _currentSpeed,
                                  maxSpeed: Provider.of<SettingsService>(context).settings.maxSpeedometer.toDouble(),
                                  size: safeSize,
                                  unit: Provider.of<SettingsService>(context).settings.speedUnit,
                                ),
                              ).animate().fadeIn().scale(
                                delay: 300.milliseconds,
                                duration: 500.milliseconds,
                                curve: Curves.easeOutBack,
                              );
                            }
                          ),

                          SizedBox(height: isCompactScreen ? 8 : 16),

                          // GPS status indicator - always visible
                          Center(
                            child: GestureDetector(
                              onTap: _showGpsDetailsDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardDark,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _isTracking && _locationService.currentPosition == null 
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.orange,
                                                ),
                                              )
                                            : Icon(
                                                Icons.gps_fixed,
                                                color:
                                                    _locationService.currentPosition != null
                                                        ? _getGpsAccuracyColor()
                                                        : Colors.grey,
                                                size: 18,
                                              ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'GPS Signal',
                                              style: TextStyle(
                                                color: AppTheme.textSecondaryDark,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  _locationService.currentPosition != null
                                                      ? _getGpsAccuracyLevel()
                                                      : _isTracking 
                                                          ? 'Activating GPS...'
                                                          : 'Waiting for GPS...',
                                                  style: TextStyle(
                                                    color:
                                                        _locationService.currentPosition != null
                                                            ? AppTheme.textDark
                                                            : _isTracking
                                                                ? Colors.orange
                                                                : AppTheme.textSecondaryDark,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    
                                    // Show retry button if GPS is unavailable for some time while tracking
                                    if (_isTracking && _locationService.currentPosition == null)
                                      TextButton(
                                        onPressed: () async {
                                          // Stop current tracking
                                          _locationService.stopTracking();
                                          // Restart tracking
                                          await _locationService.startTracking();
                                          // Update subscriptions
                                          _speedSubscription?.cancel();
                                          _speedSubscription = _locationService.speedStream.listen(_updateSpeed);
                                        },
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.refresh, size: 14),
                                            SizedBox(width: 4),
                                            Text(
                                              'Retry GPS',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 350.milliseconds),

                          const SizedBox(height: 24),

                          // Start/Stop tracking button
                          Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 180,
                              height: 56,
                              decoration: BoxDecoration(
                                color:
                                    _isTracking ? Colors.red : AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isTracking
                                            ? Colors.red
                                            : AppTheme.primaryColor)
                                        .withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _toggleTracking,
                                  borderRadius: BorderRadius.circular(28),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _animationController,
                                        builder: (context, child) {
                                          return Icon(
                                            _isTracking
                                                ? Icons.stop
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size:
                                                24 + (_animationController.value * 4),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isTracking ? 'STOP' : 'START',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ).animate().fadeIn().scale(
                            delay: 400.milliseconds,
                            duration: 200.milliseconds,
                          ),

                          const SizedBox(height: 24),

                          // Stats grid with adaptive layout - completely redesigned
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate available width
                              final availableWidth = constraints.maxWidth;
                              
                              // For extremely small screens, use a column layout
                              if (availableWidth < 300) {
                                return Column(
                                  children: [
                                    _buildStatsRow(
                                      context,
                                      'MAX SPEED',
                                      _maxSpeed.toStringAsFixed(1),
                                      Provider.of<SettingsService>(context).settings.speedUnit,
                                      Icons.speed,
                                      Colors.orange,
                                      500.milliseconds,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildStatsRow(
                                      context,
                                      'AVG SPEED',
                                      _avgSpeed.toStringAsFixed(1),
                                      Provider.of<SettingsService>(context).settings.speedUnit,
                                      Icons.calculate,
                                      Colors.green,
                                      600.milliseconds,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildStatsRow(
                                      context,
                                      'DISTANCE',
                                      _formatDistance(_distance),
                                      _getDistanceUnit(_distance),
                                      Icons.straighten,
                                      Colors.blue,
                                      700.milliseconds,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildStatsRow(
                                      context,
                                      'TIME',
                                      _formattedTime,
                                      'min',
                                      Icons.timer,
                                      Colors.purple,
                                      800.milliseconds,
                                    ),
                                  ],
                                );
                              }
                              
                              // For other screens, use a grid but with adjusted parameters
                              return Column(
                                children: [
                                  // First row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: StatsCard(
                                          title: 'MAX SPEED',
                                          value: _maxSpeed.toStringAsFixed(1),
                                          unit: Provider.of<SettingsService>(context).settings.speedUnit,
                                          icon: Icons.speed,
                                          color: Colors.orange,
                                        ).animate().fadeIn(delay: 500.milliseconds),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: StatsCard(
                                          title: 'AVG SPEED',
                                          value: _avgSpeed.toStringAsFixed(1),
                                          unit: Provider.of<SettingsService>(context).settings.speedUnit,
                                          icon: Icons.calculate,
                                          color: Colors.green,
                                        ).animate().fadeIn(delay: 600.milliseconds),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Second row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: StatsCard(
                                          title: 'DISTANCE',
                                          value: _formatDistance(_distance),
                                          unit: _getDistanceUnit(_distance),
                                          icon: Icons.straighten,
                                          color: Colors.blue,
                                        ).animate().fadeIn(delay: 700.milliseconds),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: StatsCard(
                                          title: 'TIME',
                                          value: _formattedTime,
                                          unit: 'min',
                                          icon: Icons.timer,
                                          color: Colors.purple,
                                        ).animate().fadeIn(delay: 800.milliseconds),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                          ),

                          // Bottom padding for scrolling
                          SizedBox(height: MediaQuery.of(context).padding.bottom + 30),
                        ],
                      ),
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle save button press with animation
  Future<void> _handleSaveTrip() async {
    // Start the save animation
    setState(() {
      _isSaving = true;
    });

    // Start the button press animation
    _saveButtonController.forward().then((_) {
      _saveButtonController.reverse();
    });

    // Add a small delay to show the animation
    await Future.delayed(const Duration(milliseconds: 300));

    // Call the actual save method
    await _saveCurrentTrip();

    // We'll handle the exit animation in _saveCurrentTrip
  }

  // Handle discard button press with animation
  Future<void> _handleDiscardTrip() async {
    // Start the discard animation
    setState(() {
      _isDiscarding = true;
    });

    // Start the button press animation
    _discardButtonController.forward().then((_) {
      _discardButtonController.reverse();
    });

    // Add a small delay to show the animation
    await Future.delayed(const Duration(milliseconds: 300));

    // Play exit animation before removing from widget tree
    await _playExitAnimation();

    // After exit animation completes, update state
    setState(() {
      _hasUnsavedTrip = false;
      _isDiscarding = false;
    });

    // Show a snackbar to confirm discard
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip discarded'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Play the exit animation for the container
  Future<void> _playExitAnimation() async {
    // Set exiting state to true
    setState(() {
      _isExiting = true;
    });

    // Reset and play the exit animation
    _containerExitController.reset();
    await _containerExitController.forward();

    // After animation completes, update state if still mounted
    if (mounted) {
      setState(() {
        _isExiting = false;
      });
    }
  }

  // Helper method to build a horizontally compact stats row for very small screens
  Widget _buildStatsRow(
    BuildContext context,
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
    Duration animationDelay,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardDark,
            Color.lerp(AppTheme.cardDark, color, 0.1) ?? AppTheme.cardDark,
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            height: 24,
            width: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: animationDelay).slideX(
      begin: 0.05,
      end: 0,
      delay: animationDelay,
      curve: Curves.easeOutQuint,
    );
  }

  // Save the current trip data
  Future<bool> _saveCurrentTrip() async {
    final TripStorageService storageService = TripStorageService();

    // Create trip data object
    final tripData = TripData(
      dateTime: DateTime.now(),
      maxSpeed: _maxSpeed,
      avgSpeed: _avgSpeed,
      distance: _distance,
      durationSeconds: _elapsedSeconds,
      locationHistory: _locationService.locationHistory,
    );

    // Save the trip
    bool success = await storageService.saveTrip(tripData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Trip saved successfully' : 'Failed to save trip',
          ),
          backgroundColor: success ? AppTheme.accentColor : Colors.red,
        ),
      );

      // Reset the saving state
      setState(() {
        _isSaving = false;
      });

      // Play exit animation and then set _hasUnsavedTrip to false
      if (success) {
        // Play exit animation
        await _playExitAnimation();

        // After animation completes, update state if still mounted
        if (mounted) {
          setState(() {
            _hasUnsavedTrip = false;
          });
        }
      }
    }

    return success;
  }

  // Display the save confirmation dialog
  Future<bool> _onWillPop() async {
    if (_hasUnsavedTrip) {
      _showExitDialog();
      return false;
    }
    return true;
  }
  
  // Show dialog when trying to exit with unsaved changes
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'Unsaved Trip',
          style: TextStyle(color: AppTheme.textDark),
        ),
        content: const Text(
          'You have an unsaved trip. Do you want to save it before exiting?',
          style: TextStyle(color: AppTheme.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _handleDiscardTrip();
              Navigator.pop(context); // Exit screen
            },
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _handleSaveTrip();
              Navigator.pop(context); // Exit screen
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  // Helper methods to determine GPS accuracy display
  String _getAccuracyText(double? accuracy) {
    if (accuracy == null) return 'No Signal';
    if (accuracy <= 4) return 'Excellent';
    if (accuracy <= 8) return 'Good';
    if (accuracy <= 15) return 'Moderate';
    if (accuracy <= 30) return 'Poor';
    return 'Weak';
  }
  
  Color _getAccuracyColor(double? accuracy) {
    if (accuracy == null) return Colors.grey;
    if (accuracy <= 4) return Colors.greenAccent;
    if (accuracy <= 8) return Colors.green;
    if (accuracy <= 15) return Colors.amber;
    if (accuracy <= 30) return Colors.orange;
    return Colors.red;
  }

  // Add a new method to show detailed GPS information
  void _showGpsDetailsDialog() {
    if (_locationService.currentPosition == null) {
      // If no position available, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS data not available yet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final position = _locationService.currentPosition!;
    final speedInKmh = position.speed * 3.6; // Convert m/s to km/h
    final speedInMph = position.speed * 2.23694; // Convert m/s to mph
    
    // Format timestamp for better readability
    final timestamp = position.timestamp;
    final formattedTimestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp.toLocal());
    final timeAgo = DateTime.now().difference(timestamp);
    
    // Format lat/long with appropriate precision
    final latString = position.latitude.toStringAsFixed(6);
    final longString = position.longitude.toStringAsFixed(6);
    
    // Format accuracy values
    final horizontalAccuracy = position.accuracy.toStringAsFixed(2);
    final speedAccuracy = position.speedAccuracy.toStringAsFixed(2);
    final altitudeAccuracy = position.altitudeAccuracy?.toStringAsFixed(2) ?? 'N/A';
    final headingAccuracy = position.headingAccuracy?.toStringAsFixed(2) ?? 'N/A';
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.cardDark,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog title
                Row(
                  children: [
                    Icon(
                      Icons.satellite_alt,
                      color: _getGpsAccuracyColor(),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'GPS Signal Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Information in sections for readability
                // Location Section
                _buildGpsDetailSection(
                  'LOCATION',
                  [
                    _buildDetailRow('Latitude', latString),
                    _buildDetailRow('Longitude', longString),
                    _buildDetailRow('Altitude', '${position.altitude.toStringAsFixed(2)} m'),
                  ],
                ),
                
                const Divider(color: AppTheme.textSecondaryDark),
                
                // Accuracy Section
                _buildGpsDetailSection(
                  'ACCURACY',
                  [
                    _buildDetailRow('Horizontal', '$horizontalAccuracy m', 
                      valueColor: _getAccuracyColor(position.accuracy)),
                    _buildDetailRow('Altitude', '$altitudeAccuracy m'),
                    _buildDetailRow('Speed', '$speedAccuracy m/s'),
                    _buildDetailRow('Heading', '$headingAccuracy°'),
                  ],
                ),
                
                const Divider(color: AppTheme.textSecondaryDark),
                
                // Motion Section
                _buildGpsDetailSection(
                  'MOTION',
                  [
                    _buildDetailRow('Speed (m/s)', '${position.speed.toStringAsFixed(2)} m/s'),
                    _buildDetailRow('Speed (km/h)', '${speedInKmh.toStringAsFixed(2)} km/h'),
                    _buildDetailRow('Speed (mph)', '${speedInMph.toStringAsFixed(2)} mph'),
                    _buildDetailRow('Heading', '${position.heading.toStringAsFixed(1)}°'),
                  ],
                ),
                
                const Divider(color: AppTheme.textSecondaryDark),
                
                // Timestamp Section
                _buildGpsDetailSection(
                  'TIMESTAMP',
                  [
                    _buildDetailRow('Time', formattedTimestamp),
                    _buildDetailRow('Age', _formatTimeDifference(timeAgo)),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Copy coordinates button
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Coordinates'),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: '$latString, $longString'),
                      ).then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Coordinates copied to clipboard'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.of(context).pop();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Center(
                  child: TextButton(
                    child: const Text('Close'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Helper method to build a section of GPS details
  Widget _buildGpsDetailSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        ...items,
        const SizedBox(height: 8),
      ],
    );
  }
  
  // Helper method to build a detail row with label and value
  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryDark,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              color: valueColor ?? AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to format time difference for display
  String _formatTimeDifference(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds} seconds ago';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} minutes ago';
    } else {
      return '${duration.inHours} hours ago';
    }
  }
}
