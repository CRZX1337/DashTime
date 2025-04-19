import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../widgets/speedometer.dart';
import '../widgets/stats_card.dart';
import '../models/acceleration_data.dart';
import '../services/acceleration_storage_service.dart';

class AccelerationScreen extends StatefulWidget {
  const AccelerationScreen({super.key});

  @override
  State<AccelerationScreen> createState() => _AccelerationScreenState();
}

class _AccelerationScreenState extends State<AccelerationScreen>
    with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final AccelerationStorageService _storageService = AccelerationStorageService();
  final TextEditingController _customSpeedController = TextEditingController();
  
  StreamSubscription<double>? _speedSubscription;
  
  // States
  bool _isReady = false;
  bool _isMeasuring = false;
  bool _isComplete = false;
  bool _hasGpsSignal = false;
  bool _isSaving = false;
  bool _showTestHistory = false;
  
  // Add a new property to track if target was reached
  bool _targetReached = false;
  
  // Acceleration data
  double _currentSpeed = 0.0;
  double _startSpeed = 0.0;
  double _targetSpeed = 100.0; // Default target 0-100
  
  // Timer
  Stopwatch _stopwatch = Stopwatch();
  Timer? _updateTimer;
  String _elapsedTimeStr = "00:00.00";
  int _elapsedMilliseconds = 0;
  
  // Test history
  List<AccelerationData> _testResults = [];
  AccelerationData? _selectedResult;
  bool _isLoadingTests = false;
  
  // Animation controllers
  late AnimationController _readyAnimationController;
  late AnimationController _measureAnimationController;
  late AnimationController _resultAnimationController;
  late AnimationController _saveButtonController;
  late AnimationController _historyAnimationController;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _readyAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _measureAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _resultAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _saveButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _historyAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    // Initialize location services
    _checkLocationService();
    
    // Load test history
    _loadTestHistory();
  }
  
  @override
  void dispose() {
    _speedSubscription?.cancel();
    _updateTimer?.cancel();
    _readyAnimationController.dispose();
    _measureAnimationController.dispose();
    _resultAnimationController.dispose();
    _saveButtonController.dispose();
    _historyAnimationController.dispose();
    _customSpeedController.dispose();
    
    // Make sure to stop tracking when the screen is closed
    if (_isMeasuring) {
      _locationService.stopTracking();
    }
    
    super.dispose();
  }
  
  // Check location service on startup
  Future<void> _checkLocationService() async {
    bool available = await _locationService.startTracking();
    
    if (!available && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enable location services to use acceleration measurement',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    } else {
      // Listen for speed updates
      _speedSubscription = _locationService.speedStream.listen(_updateSpeed);
      
      // If using simulation, make sure it's prepared but not running yet
      if (_locationService.isSimulationMode) {
        // Reset state for when user presses start
        _locationService.resetDemoState();
      }
      
      // Start in ready state
      setState(() {
        _isReady = true;
        _hasGpsSignal = _locationService.currentPosition != null;
      });
      
      _readyAnimationController.forward();
    }
  }
  
  void _updateSpeed(double speed) {
    if (!mounted) return;
    
    // Get settings for unit conversion
    final settings = Provider.of<SettingsService>(context, listen: false).settings;
    
    // Convert to desired units
    double displaySpeed = speed;
    if (settings.speedUnit == 'mph') {
      displaySpeed = speed * 0.621371;
    } else if (settings.speedUnit == 'm/s') {
      displaySpeed = speed / 3.6;
    }
    
    setState(() {
      _currentSpeed = displaySpeed;
      _hasGpsSignal = _locationService.currentPosition != null;
      
      // If we're measuring and just passed the target speed, complete the measurement
      if (_isMeasuring && !_isComplete) {
        if (_currentSpeed >= _targetSpeed) {
          _targetReached = true;
          _completeMeasurement();
        }
      }
    });
  }
  
  void _startMeasurement() {
    // Reset data
    _stopwatch.reset();
    _elapsedMilliseconds = 0;
    _elapsedTimeStr = "00:00.00";
    _isComplete = false;
    _targetReached = false;
    
    // Set starting speed
    _startSpeed = _currentSpeed;
    
    // Start measuring
    setState(() {
      _isMeasuring = true;
      _isReady = false;
    });
    
    // If in simulation mode, start the demo movement
    if (_locationService.isSimulationMode) {
      _locationService.startDemoMovement();
    }
    
    // Start the stopwatch
    _stopwatch.start();
    
    // Start display timer
    _updateTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (!_isMeasuring || _isComplete) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _elapsedMilliseconds = _stopwatch.elapsedMilliseconds;
        _formatElapsedTime();
      });
    });
    
    _readyAnimationController.reverse();
    _measureAnimationController.forward();
  }
  
  void _completeMeasurement() {
    _stopwatch.stop();
    _elapsedMilliseconds = _stopwatch.elapsedMilliseconds;
    _formatElapsedTime();
    
    // If in simulation mode, stop the demo movement
    if (_locationService.isSimulationMode) {
      _locationService.stopDemoMovement();
    }
    
    setState(() {
      _isMeasuring = false;
      _isComplete = true;
    });
    
    _measureAnimationController.reverse();
    _resultAnimationController.forward();
    
    // Update selected result for comparison if this is a completed test
    if (_targetReached) {
      _updateSelectedResult();
    }
  }
  
  void _resetMeasurement() {
    // If in simulation mode, reset demo state for a new test
    if (_locationService.isSimulationMode) {
      _locationService.resetDemoState();
    }
    
    setState(() {
      _isReady = true;
      _isComplete = false;
      _currentSpeed = 0.0; // Reset current speed to zero
    });
    
    _resultAnimationController.reverse();
    _readyAnimationController.forward();
  }
  
  void _formatElapsedTime() {
    int minutes = (_elapsedMilliseconds ~/ 60000) % 60;
    int seconds = (_elapsedMilliseconds ~/ 1000) % 60;
    int milliseconds = (_elapsedMilliseconds % 1000) ~/ 10;
    
    _elapsedTimeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
  }
  
  void _showTargetDialog() {
    // Set the controller's text to the current target speed
    _customSpeedController.text = _targetSpeed.toString();
    
    // Calculate screen height to position dialog better
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = screenHeight * 0.6; // Limit dialog height
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxHeight: dialogHeight),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set Target Speed',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Select the target speed for your acceleration test:',
                        style: TextStyle(color: AppTheme.textSecondaryDark),
                      ),
                      const SizedBox(height: 16),
                      _buildTargetButton(context, 10),
                      const SizedBox(height: 8),
                      _buildTargetButton(context, 50),
                      const SizedBox(height: 8),
                      _buildTargetButton(context, 100),
                      const SizedBox(height: 8),
                      _buildTargetButton(context, 120),
                      const SizedBox(height: 16),
                      const Divider(color: AppTheme.textSecondaryDark),
                      const SizedBox(height: 12),
                      const Text(
                        'Or set a custom target speed:',
                        style: TextStyle(color: AppTheme.textSecondaryDark),
                      ),
                      const SizedBox(height: 12),
                      // Custom target speed input field
                      TextField(
                        controller: _customSpeedController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: AppTheme.textDark),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.backgroundDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          labelText: 'Custom Target Speed',
                          labelStyle: const TextStyle(color: AppTheme.textSecondaryDark),
                          suffixText: Provider.of<SettingsService>(context).settings.speedUnit,
                          suffixStyle: const TextStyle(color: AppTheme.textSecondaryDark),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () {
                          // Parse the custom speed input
                          final customSpeed = double.tryParse(_customSpeedController.text);
                          if (customSpeed != null && customSpeed > 0) {
                            setState(() {
                              _targetSpeed = customSpeed;
                            });
                            Navigator.pop(context);
                          } else {
                            // Show error for invalid input
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid speed greater than 0'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text('SET CUSTOM TARGET'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Check if the current target speed is a custom value
  bool _isCustomTargetSpeed() {
    // Standard targets
    const standardTargets = [10, 50, 100, 120];
    
    // Check if current target is not one of the standard targets
    return !standardTargets.contains(_targetSpeed.toInt());
  }
  
  Widget _buildTargetButton(BuildContext context, double target) {
    final settings = Provider.of<SettingsService>(context).settings;
    String unit = settings.speedUnit;
    
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _targetSpeed == target 
          ? AppTheme.primaryColor 
          : AppTheme.backgroundDark,
        foregroundColor: _targetSpeed == target 
          ? Colors.white 
          : AppTheme.textDark,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () {
        setState(() {
          _targetSpeed = target;
        });
        Navigator.pop(context);
      },
      child: Text('0-$target $unit'),
    );
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
    String speedUnit = settings.speedUnit;
    
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    // Calculate appropriate speedometer size
    final speedometerSize = isLandscape
        ? min(240.0, screenSize.height * 0.5)
        : min(240.0, screenSize.width * 0.7).clamp(180.0, 300.0);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppTheme.primaryColor,
                  ).animate().fadeIn().scale(
                    delay: 200.milliseconds,
                    duration: 200.milliseconds,
                  ),
                  
                  Text(
                    _showTestHistory ? 'Acceleration History' : 'Acceleration Test',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ).animate().fadeIn(delay: 300.milliseconds),
                  
                  Row(
                    children: [
                      // History button
                      IconButton(
                        icon: Icon(_showTestHistory ? Icons.speed : Icons.history),
                        onPressed: _toggleHistoryView,
                        color: AppTheme.primaryColor,
                      ).animate().fadeIn().scale(
                        delay: 200.milliseconds,
                        duration: 200.milliseconds,
                      ),
                      
                      // Settings button (only visible in test mode)
                      if (!_showTestHistory)
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: _showTargetDialog,
                          color: AppTheme.primaryColor,
                        ).animate().fadeIn().scale(
                          delay: 200.milliseconds,
                          duration: 200.milliseconds,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Main content in a scrollable container
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _showTestHistory
                      ? _buildHistoryView()  // Show history view
                      : Column(  // Show test UI
                        children: [
                          // GPS status indicator
                          Center(
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _hasGpsSignal
                                      ? Icon(
                                          Icons.gps_fixed,
                                          color: _getGpsAccuracyColor(),
                                          size: 18,
                                        )
                                      : const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.orange,
                                          ),
                                        ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _hasGpsSignal
                                        ? _getGpsAccuracyLevel()
                                        : 'Waiting for GPS...',
                                    style: TextStyle(
                                      color: _hasGpsSignal
                                          ? AppTheme.textDark
                                          : Colors.orange,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 350.milliseconds),
                          
                          const SizedBox(height: 24),
                          
                          // Target speed display
                          Center(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '0-$_targetSpeed $speedUnit',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    if (_isCustomTargetSpeed())
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'CUSTOM',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.accentColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Target Speed',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 400.milliseconds),
                          
                          const SizedBox(height: 16),
                          
                          // Ready state
                          AnimatedBuilder(
                            animation: _readyAnimationController,
                            builder: (context, child) {
                              final opacity = _readyAnimationController.value;
                              final scale = 0.8 + (0.2 * _readyAnimationController.value);
                              
                              return Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  child: child,
                                ),
                              );
                            },
                            child: _isReady
                                ? Column(
                                    children: [
                                      const SizedBox(height: 5),
                                      // Speedometer widget instead of text
                                      Speedometer(
                                        speed: _currentSpeed,
                                        maxSpeed: _targetSpeed.toDouble() * 1.2, // Set max a bit higher than target
                                        size: speedometerSize,
                                        unit: speedUnit,
                                      ),
                                      const SizedBox(height: 24),
                                      Container(
                                        width: 200,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: _hasGpsSignal 
                                              ? AppTheme.primaryColor 
                                              : Colors.grey,
                                          borderRadius: BorderRadius.circular(30),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (_hasGpsSignal 
                                                  ? AppTheme.primaryColor 
                                                  : Colors.grey)
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
                                            onTap: _hasGpsSignal 
                                                ? _startMeasurement 
                                                : null,
                                            borderRadius: BorderRadius.circular(30),
                                            child: const Center(
                                              child: Text(
                                                'START TEST',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                          
                          // Measuring state
                          AnimatedBuilder(
                            animation: _measureAnimationController,
                            builder: (context, child) {
                              final opacity = _measureAnimationController.value;
                              final scale = 0.8 + (0.2 * _measureAnimationController.value);
                              
                              return Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  child: child,
                                ),
                              );
                            },
                            child: _isMeasuring
                                ? Column(
                                    children: [
                                      Text(
                                        'Measuring...',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: AppTheme.textSecondaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _elapsedTimeStr,
                                            style: const TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textDark,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      // Speedometer widget instead of text
                                      Speedometer(
                                        speed: _currentSpeed,
                                        maxSpeed: _targetSpeed.toDouble() * 1.2, // Set max a bit higher than target
                                        size: speedometerSize,
                                        unit: speedUnit,
                                      ),
                                      const SizedBox(height: 24),
                                      Container(
                                        width: 200,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(30),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.3),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _completeMeasurement,
                                            borderRadius: BorderRadius.circular(30),
                                            child: const Center(
                                              child: Text(
                                                'STOP',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                          
                          // Result state
                          AnimatedBuilder(
                            animation: _resultAnimationController,
                            builder: (context, child) {
                              final opacity = _resultAnimationController.value;
                              final scale = 0.8 + (0.2 * _resultAnimationController.value);
                              
                              return Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  child: child,
                                ),
                              );
                            },
                            child: _isComplete
                                ? Column(
                                    children: [
                                      Text(
                                        _targetReached ? 'Result' : 'Test Stopped',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: AppTheme.textSecondaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Speedometer widget for consistent visuals - show current speed if target wasn't reached
                                      Speedometer(
                                        speed: _targetReached ? _targetSpeed : _currentSpeed,
                                        maxSpeed: _targetSpeed.toDouble() * 1.2,
                                        size: speedometerSize * 0.9,
                                        unit: speedUnit,
                                      ),
                                      const SizedBox(height: 16),
                                      if (_targetReached)
                                        // Show successful completion results
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cardDark,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    '0-$_targetSpeed $speedUnit',
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.textDark,
                                                    ),
                                                  ),
                                                  if (_isCustomTargetSpeed())
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 8.0),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.accentColor.withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: const Text(
                                                          'CUSTOM',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppTheme.accentColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    _elapsedTimeStr,
                                                    style: const TextStyle(
                                                      fontSize: 42,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primaryColor,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'seconds',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: AppTheme.textSecondaryDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              
                                              // Compare with personal best if available
                                              if (_selectedResult != null && _targetReached)
                                                Column(
                                                  children: [
                                                    const SizedBox(height: 16),
                                                    const Divider(color: AppTheme.textSecondaryDark),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        const Text(
                                                          'Your Best: ',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: AppTheme.textSecondaryDark,
                                                          ),
                                                        ),
                                                        Text(
                                                          _selectedResult!.getFormattedTime(),
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppTheme.textDark,
                                                            fontFamily: 'monospace',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      _elapsedMilliseconds < _selectedResult!.elapsedMilliseconds
                                                          ? 'New personal best! 🎉'
                                                          : _elapsedMilliseconds == _selectedResult!.elapsedMilliseconds
                                                              ? 'Matched your best time'
                                                              : 'Difference: +${((_elapsedMilliseconds - _selectedResult!.elapsedMilliseconds) / 1000).toStringAsFixed(2)}s',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: _elapsedMilliseconds <= _selectedResult!.elapsedMilliseconds
                                                            ? Colors.green
                                                            : AppTheme.textSecondaryDark,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        )
                                      else
                                        // Show incomplete test message
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cardDark,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              const Text(
                                                'Test stopped before reaching target',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textDark,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Current speed: ${_currentSpeed.toStringAsFixed(1)} $speedUnit',
                                                style: const TextStyle(
                                                  fontSize: 16, 
                                                  color: AppTheme.textSecondaryDark,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Target: $_targetSpeed $speedUnit',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: AppTheme.textSecondaryDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 20),
                                      
                                      // Action buttons - Save and New Test
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Save button
                                          if (_targetReached)
                                            AnimatedBuilder(
                                              animation: _saveButtonController,
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale: _isSaving
                                                    ? Curves.easeInBack.transform(_saveButtonController.value) * 0.8
                                                    : 1.0,
                                                  child: Container(
                                                    width: 150,
                                                    height: 60,
                                                    margin: const EdgeInsets.only(right: 10),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.accentColor,
                                                      borderRadius: BorderRadius.circular(30),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppTheme.accentColor.withOpacity(0.3),
                                                          blurRadius: 10,
                                                          spreadRadius: 2,
                                                          offset: const Offset(0, 3),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: _isSaving ? null : _saveCurrentTest,
                                                        borderRadius: BorderRadius.circular(30),
                                                        child: Center(
                                                          child: _isSaving
                                                            ? const Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  SizedBox(
                                                                    width: 20,
                                                                    height: 20,
                                                                    child: CircularProgressIndicator(
                                                                      color: Colors.white,
                                                                      strokeWidth: 2,
                                                                    ),
                                                                  ),
                                                                  SizedBox(width: 10),
                                                                  Text(
                                                                    'SAVING',
                                                                    style: TextStyle(
                                                                      color: Colors.white,
                                                                      fontSize: 16,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ],
                                                              )
                                                            : const Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  Icon(
                                                                    Icons.save,
                                                                    color: Colors.white,
                                                                  ),
                                                                  SizedBox(width: 8),
                                                                  Text(
                                                                    'SAVE',
                                                                    style: TextStyle(
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
                                                  ),
                                                );
                                              },
                                            ),
                                          
                                          // New Test button
                                          Container(
                                            width: _targetReached ? 150 : 200,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor,
                                              borderRadius: BorderRadius.circular(30),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: _resetMeasurement,
                                                borderRadius: BorderRadius.circular(30),
                                                child: const Center(
                                                  child: Text(
                                                    'NEW TEST',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Load saved test history from storage
  Future<void> _loadTestHistory() async {
    setState(() {
      _isLoadingTests = true;
    });
    
    try {
      final tests = await _storageService.getAllAccelerationTests();
      setState(() {
        _testResults = tests;
        _isLoadingTests = false;
        
        // Select fastest test for current target if available
        _updateSelectedResult();
      });
    } catch (e) {
      print('Error loading test history: $e');
      setState(() {
        _isLoadingTests = false;
      });
    }
  }
  
  // Update the selected result based on current target speed
  void _updateSelectedResult() {
    if (_testResults.isEmpty) {
      _selectedResult = null;
      return;
    }
    
    // Find tests matching the current target speed
    final matchingTests = _testResults
        .where((test) => test.targetSpeed == _targetSpeed && test.targetReached)
        .toList();
    
    if (matchingTests.isEmpty) {
      _selectedResult = null;
      return;
    }
    
    // Sort by elapsed time (fastest first)
    matchingTests.sort((a, b) => a.elapsedMilliseconds.compareTo(b.elapsedMilliseconds));
    
    // Select the fastest test
    setState(() {
      _selectedResult = matchingTests.first;
    });
  }
  
  // Save current test result
  Future<bool> _saveCurrentTest() async {
    setState(() {
      _isSaving = true;
    });
    
    // Start the button animation
    _saveButtonController.forward().then((_) {
      _saveButtonController.reverse();
    });
    
    // Get current settings
    final settings = Provider.of<SettingsService>(context, listen: false).settings;
    
    // Create acceleration data
    final testData = AccelerationData(
      dateTime: DateTime.now(),
      startSpeed: _startSpeed,
      targetSpeed: _targetSpeed,
      achievedSpeed: _targetReached ? _targetSpeed : _currentSpeed,
      elapsedMilliseconds: _elapsedMilliseconds,
      targetReached: _targetReached,
      speedUnit: settings.speedUnit,
    );
    
    // Save to storage
    final success = await _storageService.saveAccelerationTest(testData);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Test saved successfully' : 'Failed to save test',
          ),
          backgroundColor: success ? AppTheme.accentColor : Colors.red,
        ),
      );
      
      setState(() {
        _isSaving = false;
      });
      
      if (success) {
        // Reload test history
        await _loadTestHistory();
      }
    }
    
    return success;
  }
  
  // Delete a test result
  Future<void> _deleteTest(AccelerationData test) async {
    final success = await _storageService.deleteTest(test.dateTime);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test deleted'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Reload test history
      await _loadTestHistory();
    }
  }
  
  // Toggle between current test and history view
  void _toggleHistoryView() {
    setState(() {
      _showTestHistory = !_showTestHistory;
    });
    
    if (_showTestHistory) {
      _historyAnimationController.forward();
    } else {
      _historyAnimationController.reverse();
    }
  }

  // Build the history view UI
  Widget _buildHistoryView() {
    if (_isLoadingTests) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_testResults.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer_off,
                size: 80,
                color: AppTheme.textSecondaryDark,
              ),
              const SizedBox(height: 16),
              const Text(
                'No acceleration tests saved yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete a test and tap "Save" to see it here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _toggleHistoryView,
                icon: const Icon(Icons.speed),
                label: const Text('Start Testing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Group tests by target speed
    final groupedTests = <double, List<AccelerationData>>{};
    for (final test in _testResults) {
      if (!groupedTests.containsKey(test.targetSpeed)) {
        groupedTests[test.targetSpeed] = [];
      }
      groupedTests[test.targetSpeed]!.add(test);
    }
    
    // Sort keys (target speeds)
    final sortedTargets = groupedTests.keys.toList()..sort();
    
    return AnimatedBuilder(
      animation: _historyAnimationController,
      builder: (context, child) {
        final scale = 0.8 + (0.2 * _historyAnimationController.value);
        final opacity = _historyAnimationController.value;
        
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Header with clear all button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Acceleration Tests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showClearConfirmationDialog(),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Build sections for each target speed
          ...sortedTargets.map((target) {
            // Get tests for this target
            final tests = groupedTests[target]!;
            
            // Sort tests by elapsed time (fastest first)
            tests.sort((a, b) => a.elapsedMilliseconds.compareTo(b.elapsedMilliseconds));
            
            // Find successful tests
            final successfulTests = tests.where((test) => test.targetReached).toList();
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Target speed header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '0-$target ${tests.first.speedUnit}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${successfulTests.length} of ${tests.length} completed',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Best time if available
                if (successfulTests.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Best Time: ',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondaryDark,
                          ),
                        ),
                        Text(
                          successfulTests.first.getFormattedTime(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          ' (${successfulTests.first.getFormattedDate()})',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Test list
                ...tests.map((test) => _buildTestResultCard(test)),
                
                const SizedBox(height: 24),
              ],
            );
          }).toList(),
          
          // Bottom padding
          SizedBox(height: MediaQuery.of(context).size.height * 0.05),
        ],
      ),
    );
  }
  
  // Build a single test result card
  Widget _buildTestResultCard(AccelerationData test) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and result row
            Row(
              children: [
                Icon(
                  test.targetReached ? Icons.check_circle : Icons.cancel,
                  color: test.targetReached ? Colors.green : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  test.getFormattedTimeOfDay(),
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _deleteTest(test),
                  color: Colors.red,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Test details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Test result description
                      Text(
                        test.getTestDescription(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Time display
                      if (test.targetReached)
                        Row(
                          children: [
                            const Text(
                              'Time: ',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryDark,
                              ),
                            ),
                            Text(
                              test.getFormattedTime(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Show confirmation dialog before clearing history
  void _showClearConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'Clear All Tests?',
          style: TextStyle(color: AppTheme.textDark),
        ),
        content: const Text(
          'This will delete all your saved acceleration test results. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllTests();
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
  
  // Clear all test results
  Future<void> _clearAllTests() async {
    final success = await _storageService.clearAllTests();
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All test results cleared'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Reload test history
      await _loadTestHistory();
    }
  }
} 