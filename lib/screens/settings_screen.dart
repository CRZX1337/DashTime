import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ffi';
import '../config/theme.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';

// Force crash using multiple approaches
class ForceCrash {
  // Using FFI to cause a native crash (this is very likely to crash)
  static void causeCrash() {
    try {
      // Try multiple approaches to ensure a crash
      
      // Approach 1: Force exit with error code
      exit(1); // This should terminate the app immediately

      // If somehow the above doesn't work, these will:
      
      // Approach 2: Force divide by zero
      int result = 1 ~/ 0;
      print(result); // Never reached

      // Approach 3: Access invalid memory (most guaranteed to crash on all devices)
      Pointer<Int32> invalidPointer = Pointer.fromAddress(0xDEADBEEF);
      invalidPointer.value = 42; // This will definitely crash

      // Approach 4: Recursion until stack overflow
      _recursiveCrash(1000000);
    } catch (e) {
      // If all else fails, exit
      exit(1);
    }
  }
  
  // Recursive function to cause stack overflow
  static void _recursiveCrash(int depth) {
    _recursiveCrash(depth + 1);
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings options
  late String _speedUnit;
  late String _distanceUnit;
  late bool _keepScreenOn;
  late int _maxSpeedometer;
  
  // Developer menu timer
  Timer? _devMenuTimer;
  bool _isHolding = false;
  bool _developerModeEnabled = false;
  
  // Add state variables for developer features
  double _simulatedSpeed = 60.0;
  bool _isSimulatingLocation = false;
  double _accelerationRate = 1.0; // Controls how quickly speed changes
  
  @override
  void dispose() {
    _devMenuTimer?.cancel();
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    // Initialize with default values first
    _speedUnit = 'km/h';
    _distanceUnit = 'km';
    _keepScreenOn = true;
    _maxSpeedometer = 180;
    
    // Check if developer mode is enabled and load developer settings
    _loadDeveloperSettings();
    
    // Schedule loading from service after widget is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettingsFromService();
    });
  }
  
  // Load developer mode and settings from SharedPreferences
  Future<void> _loadDeveloperSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _developerModeEnabled = prefs.getBool('developer_mode_enabled') ?? false;
      _isSimulatingLocation = prefs.getBool('simulate_location') ?? false;
      _simulatedSpeed = prefs.getDouble('simulated_speed') ?? 60.0;
      _accelerationRate = prefs.getDouble('acceleration_rate') ?? 1.0;
    });
    
    // Apply loaded settings
    if (_developerModeEnabled) {
      _applyDeveloperSettings();
    }
  }
  
  // Apply developer settings to the app
  void _applyDeveloperSettings() {
    // Apply location simulation
    if (_isSimulatingLocation) {
      _applyLocationSimulation();
    }
  }
  
  // Save developer settings to SharedPreferences
  Future<void> _saveDeveloperSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('developer_mode_enabled', _developerModeEnabled);
    await prefs.setBool('simulate_location', _isSimulatingLocation);
    await prefs.setDouble('simulated_speed', _simulatedSpeed);
    await prefs.setDouble('acceleration_rate', _accelerationRate);
  }
  
  // Save developer mode to SharedPreferences and update other settings
  Future<void> _saveDeveloperMode(bool enabled) async {
    setState(() {
      _developerModeEnabled = enabled;
    });
    
    if (!enabled) {
      // Disable all developer features when turning off developer mode
      _isSimulatingLocation = false;
    }
    
    await _saveDeveloperSettings();
    
    if (enabled) {
      // Log the change
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer mode enabled'),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Log the change
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer mode disabled'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  void _startDevMenuTimer() {
    _isHolding = true;
    _devMenuTimer?.cancel();
    _devMenuTimer = Timer(const Duration(seconds: 5), () {
      if (_isHolding) {
        setState(() {
          _developerModeEnabled = true;
        });
        // Save developer mode state
        _saveDeveloperMode(true);
        
        // Apply developer settings
        _applyDeveloperSettings();
        
        // Force a refresh of the page
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Developer mode enabled!'),
            backgroundColor: AppTheme.primaryColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _cancelDevMenuTimer() {
    _isHolding = false;
    _devMenuTimer?.cancel();
  }
  
  Future<void> _openGitHub() async {
    final Uri url = Uri.parse('https://github.com/CryZuX/DashTimeRevamped');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
  
  void _showDevMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'Developer Menu',
          style: TextStyle(color: AppTheme.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDevMenuItem(
              icon: Icons.bug_report,
              title: 'Debug Information',
              onTap: () {
                Navigator.pop(context);
                // Show debug info dialog
                _showDebugInfo();
              },
            ),
            const SizedBox(height: 12),
            _buildDevMenuItem(
              icon: Icons.code,
              title: 'GitHub Repository',
              onTap: () {
                Navigator.pop(context);
                _openGitHub();
              },
            ),
            const SizedBox(height: 12),
            _buildDevMenuItem(
              icon: Icons.data_usage,
              title: 'App Statistics',
              onTap: () {
                Navigator.pop(context);
                // Show app statistics
                _showAppStatistics();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDevMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'Debug Information',
          style: TextStyle(color: AppTheme.textDark),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Version: 1.0.0', style: TextStyle(color: AppTheme.textDark)),
            SizedBox(height: 8),
            Text('Build: Development', style: TextStyle(color: AppTheme.textDark)),
            SizedBox(height: 8),
            Text('Device: Flutter Emulator', style: TextStyle(color: AppTheme.textDark)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAppStatistics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'App Statistics',
          style: TextStyle(color: AppTheme.textDark),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sessions: 0', style: TextStyle(color: AppTheme.textDark)),
            SizedBox(height: 8),
            Text('Total Distance: 0 km', style: TextStyle(color: AppTheme.textDark)),
            SizedBox(height: 8),
            Text('Max Speed: 0 km/h', style: TextStyle(color: AppTheme.textDark)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
  
  void _loadSettingsFromService() {
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    final settings = settingsService.settings;
    
    setState(() {
      _speedUnit = settings.speedUnit;
      _distanceUnit = settings.distanceUnit;
      _keepScreenOn = settings.keepScreenOn;
      _maxSpeedometer = settings.maxSpeedometer;
    });
  }

  void _saveSettings() {
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    
    final newSettings = AppSettings(
      speedUnit: _speedUnit,
      distanceUnit: _distanceUnit,
      keepScreenOn: _keepScreenOn,
      maxSpeedometer: _maxSpeedometer,
    );
    
    settingsService.saveSettings(newSettings).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    });
  }

  void _showBatteryOptimizationInfo() {
    // Only show on Android
    if (!Platform.isAndroid) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Battery Optimization'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To keep the screen on reliably, this app needs to be exempted from battery optimization.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'You will be prompted to allow this permission. Please select "Allow" to ensure the screen stays on even when the device is in your pocket.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Request battery optimization exemption
              Permission.ignoreBatteryOptimizations.request();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // General Settings Section
            _buildSectionHeader('General Settings')
                .animate()
                .fadeIn()
                .slideY(begin: -0.2, end: 0, duration: 300.milliseconds),
            
            _buildSettingCard(
              title: 'Speed Unit',
              subtitle: 'Choose your preferred speed measurement unit',
              child: _buildDropdownSetting<String>(
                value: _speedUnit,
                items: const ['km/h', 'mph', 'm/s'],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _speedUnit = value;
                    });
                  }
                },
              ),
            ),
            
            _buildSettingCard(
              title: 'Maximum Speedometer',
              subtitle: 'Set the maximum speed displayed on the speedometer',
              child: _buildDropdownSetting<int>(
                value: _maxSpeedometer,
                items: const [60, 100, 180, 240, 300],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _maxSpeedometer = value;
                    });
                  }
                },
              ),
            ),
            
            _buildSettingCard(
              title: 'Distance Unit',
              subtitle: 'Choose your preferred distance measurement unit',
              child: _buildDropdownSetting<String>(
                value: _distanceUnit,
                items: const ['km', 'miles', 'm'],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _distanceUnit = value;
                    });
                  }
                },
              ),
            ),
            
            _buildSettingCard(
              title: 'Keep Screen On',
              subtitle: 'Prevent screen from turning off while using the app',
              child: Switch(
                value: _keepScreenOn,
                activeColor: AppTheme.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _keepScreenOn = value;
                  });
                  // Show battery optimization notice when enabling
                  if (value) {
                    _showBatteryOptimizationInfo();
                  }
                },
              ),
            ),
            
            // Battery notice (only shown when screen on is enabled)
            if (_keepScreenOn)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.battery_alert,
                      color: Colors.amber,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'This app needs battery optimization exemption to keep the screen on reliably.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // GPS Notice
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.gps_fixed,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'High-Accuracy GPS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'This app always uses the highest possible GPS accuracy and update frequency for best performance.',
                            style: TextStyle(
                              color: AppTheme.textSecondaryDark,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.milliseconds).slideY(
              begin: -0.2,
              end: 0,
              duration: 300.milliseconds,
            ),
            
            // About Section
            _buildSectionHeader('About')
                .animate()
                .fadeIn(delay: 300.milliseconds)
                .slideY(begin: -0.2, end: 0, duration: 300.milliseconds),
            
            _buildSimpleCard(
              child: GestureDetector(
                onLongPressStart: (_) => _startDevMenuTimer(),
                onLongPressEnd: (_) => _cancelDevMenuTimer(),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: const Text(
                    'DashTime GPS Speedometer',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  subtitle: const Text(
                    'Version 1.0.0\nDeveloped by CryZuX',
                    style: TextStyle(
                      color: AppTheme.textSecondaryDark,
                    ),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondaryDark,
                  ),
                  onTap: () async {
                    final Uri url = Uri.parse('https://github.com/CRZX1337');
                    if (!await launchUrl(url)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not launch GitHub page')),
                      );
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ).animate().fadeIn(delay: 400.milliseconds).slideY(
              begin: 0.2,
              end: 0,
              delay: 400.milliseconds,
              duration: 300.milliseconds,
            ),
            
            // Developer Section - only visible when developer mode is enabled
            if (_developerModeEnabled) ...[
              _buildSectionHeader('Developer')
                .animate()
                .fadeIn(delay: 300.milliseconds)
                .slideY(begin: -0.2, end: 0, duration: 300.milliseconds),
              
              // Location Simulator - Renamed to Demo Mode
              _buildSimpleCard(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.orange,
                    ),
                  ),
                  title: const Text(
                    'Demo Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  subtitle: Text(
                    _isSimulatingLocation 
                        ? 'Active: ${_simulatedSpeed.toInt()} km/h'
                        : 'Activate realistic driving demo',
                    style: TextStyle(
                      color: _isSimulatingLocation ? Colors.orange : AppTheme.textSecondaryDark,
                      fontWeight: _isSimulatingLocation ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: _isSimulatingLocation 
                    ? IconButton(
                        icon: const Icon(Icons.stop_circle, color: Colors.red),
                        tooltip: 'Stop Demo',
                        onPressed: () {
                          // Stop simulation
                          setState(() {
                            _isSimulatingLocation = false;
                          });
                          _saveDeveloperSettings();
                          _applyLocationSimulation();
                          
                          // Show toast
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demo mode stopped'),
                              backgroundColor: Colors.grey,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                        tooltip: 'Start Demo',
                        onPressed: () {
                          // Quick-start simulation at 60 km/h
                          setState(() {
                            _simulatedSpeed = 60.0;
                            _isSimulatingLocation = true;
                          });
                          _saveDeveloperSettings();
                          _applyLocationSimulation();
                          
                          // Show toast
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demo mode activated - Now view the speedometer!'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 3),
                            ),
                          );
                          
                          // Go back to main menu
                          Navigator.of(context).pop();
                        },
                      ),
                  onTap: () {
                    _showDemoModeDialog();
                  },
                ),
              ),
              
              // Crash Testing
              _buildSimpleCard(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                    ),
                  ),
                  title: const Text(
                    'Force Crash Test',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  subtitle: const Text(
                    'Trigger a test crash (for testing error reporting)',
                    style: TextStyle(
                      color: AppTheme.textSecondaryDark,
                    ),
                  ),
                  onTap: () {
                    _showCrashTestDialog();
                  },
                ),
              ),
              
              // Button to disable developer mode
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.code_off, color: Colors.white),
                label: const Text('Disable Developer Mode'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF616161), // Grey 700
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _developerModeEnabled = false;
                    _isSimulatingLocation = false; // Turn off simulation when disabling dev mode
                  });
                  _saveDeveloperMode(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Developer mode disabled'),
                      backgroundColor: Colors.grey,
                    ),
                  );
                },
              ),
            ],
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return _buildSimpleCard(
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondaryDark,
            fontSize: 12,
          ),
        ),
        trailing: SizedBox(
          width: 120,
          child: child,
        ),
      ),
    );
  }

  Widget _buildSimpleCard({required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: child,
    );
  }

  Widget _buildDropdownSetting<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.backgroundDark,
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: DropdownButton<T>(
        value: value,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(
              item.toString(),
              style: const TextStyle(
                color: AppTheme.textDark,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(
          Icons.arrow_drop_down,
          color: AppTheme.primaryColor,
        ),
        dropdownColor: AppTheme.cardDark,
      ),
    );
  }

  // Apply location simulation to the location service
  void _applyLocationSimulation() {
    try {
      // Get access to location service 
      final locationService = LocationService();
      
      if (_isSimulatingLocation) {
        // Enable simulation with the set speed and acceleration rate
        locationService.enableSimulation(_simulatedSpeed, accelerationRate: _accelerationRate);
        
        // Show a snackbar to confirm simulation is active
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location simulation active: ${_simulatedSpeed.toInt()} km/h'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Force a test crash if simulation speed is exactly 200
        if (_simulatedSpeed == 200) {
          Future.delayed(Duration(seconds: 1), () {
            throw Exception('Manual crash triggered by maximum simulation speed');
          });
        }
      } else {
        // Disable simulation
        locationService.disableSimulation();
        
        // Show a snackbar to confirm simulation is disabled
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location simulation disabled'),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Handle any errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying location simulation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Show Demo Mode dialog
  void _showDemoModeDialog() {
    // Start with current values
    double currentSpeed = _simulatedSpeed;
    bool currentSimulating = _isSimulatingLocation;
    double currentAcceleration = _accelerationRate;
    
    // Define presets for demo mode
    final List<Map<String, dynamic>> demoPresets = [
      {'name': 'City Driving', 'speed': 40.0, 'description': 'Simulates urban driving with traffic'},
      {'name': 'Highway', 'speed': 100.0, 'description': 'Fast driving on open highway'},
      {'name': 'Racetrack', 'speed': 180.0, 'description': 'High-speed performance driving'},
      {'name': 'Mountain Road', 'speed': 60.0, 'description': 'Winding roads with varying speeds'},
    ];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardDark,
            title: Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.orange),
                const SizedBox(width: 12),
                const Text(
                  'Demo Mode',
                  style: TextStyle(color: AppTheme.textDark),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a driving scenario:',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Demo presets
                  ...demoPresets.map((preset) => RadioListTile<double>(
                    title: Text(
                      preset['name'],
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      preset['description'],
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                    value: preset['speed'],
                    groupValue: currentSpeed,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      setState(() {
                        currentSpeed = value!;
                      });
                    },
                  )),
                  
                  const SizedBox(height: 20),
                  
                  // Custom speed slider
                  const Text(
                    'or set custom speed:',
                    style: TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 14,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: currentSpeed,
                          min: 0,
                          max: 200,
                          divisions: 20,
                          activeColor: Colors.orange,
                          inactiveColor: Colors.orange.withOpacity(0.2),
                          onChanged: (value) {
                            setState(() {
                              currentSpeed = value;
                            });
                          },
                        ),
                      ),
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${currentSpeed.toInt()} km/h',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text(
                      'Activate Demo Mode',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Simulates realistic driving patterns',
                      style: TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                    value: currentSimulating,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      setState(() {
                        currentSimulating = value;
                      });
                    },
                  ),
                  
                  // After the SwitchListTile, add a slider for acceleration rate
                  if (currentSimulating)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Acceleration Rate:',
                          style: TextStyle(
                            color: AppTheme.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Smooth', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark)),
                            Expanded(
                              child: Slider(
                                value: currentAcceleration,
                                min: 0.1,
                                max: 3.0,
                                divisions: 29,
                                activeColor: Colors.orange,
                                inactiveColor: Colors.orange.withOpacity(0.3),
                                label: currentAcceleration.toStringAsFixed(1) + 'x',
                                onChanged: (value) {
                                  setState(() {
                                    currentAcceleration = value;
                                  });
                                },
                              ),
                            ),
                            const Text('Rapid', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark)),
                          ],
                        ),
                        Text(
                          'Controls how quickly speed changes (${currentAcceleration.toStringAsFixed(1)}x)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),

                  if (currentSimulating)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Demo mode will simulate realistic driving with speed variations. Perfect for demonstrations!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Cancel without saving
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Save demo settings and close
                  this.setState(() {
                    // Update main state with the values from dialog's state
                    _isSimulatingLocation = currentSimulating;
                    _simulatedSpeed = currentSpeed;
                    _accelerationRate = currentAcceleration;
                  });
                  
                  // Apply the demo mode settings
                  if (currentSimulating) {
                    _applyLocationSimulation();
                  } else {
                    // If disabling, make sure simulation is stopped
                    LocationService().disableSimulation();
                  }
                  
                  // Save settings
                  _saveDeveloperSettings();
                  
                  // Show snackbar based on status
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        currentSimulating 
                            ? 'Demo mode activated! View the Speedometer to see it in action' 
                            : 'Demo mode disabled'
                      ),
                      backgroundColor: currentSimulating ? Colors.green : Colors.grey,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  
                  // Close dialog
                  Navigator.pop(context);
                  
                  // Go directly to speedometer if demo was activated
                  if (currentSimulating) {
                    Navigator.of(context).pop(); // Pop settings screen
                  }
                },
                child: const Text(
                  'Apply',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Implement a guaranteed crash method 
  void _showCrashTestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'Confirm App Termination',
          style: TextStyle(color: AppTheme.textDark),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'This will immediately terminate the app. The app will close abruptly.',
              style: TextStyle(color: AppTheme.textDark),
            ),
            SizedBox(height: 12),
            Text(
              'This is NOT a crash test - this is a FORCE CLOSE action.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
              
              // Show confirmation toast
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Terminating app NOW...'),
                  backgroundColor: Colors.red,
                  duration: Duration(milliseconds: 500),
                ),
              );
              
              // Give snackbar time to show before termination
              Future.delayed(const Duration(milliseconds: 600), () {
                // Force exit the app - this WILL terminate
                ForceCrash.causeCrash();
              });
            },
            child: const Text(
              'Force Close App',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
} 