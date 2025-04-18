import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';
import 'menu_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final Function onComplete;

  const OnboardingScreen({Key? key, required this.onComplete}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Permission states
  bool _locationPermissionGranted = false;
  bool _batteryOptimizationDisabled = false;
  bool _storagePermissionGranted = false;
  bool _notificationPermissionGranted = false;
  
  // User preferences
  String _selectedSpeedUnit = AppSettings.defaultSettings.speedUnit;
  String _selectedDistanceUnit = AppSettings.defaultSettings.distanceUnit;
  bool _keepScreenOn = AppSettings.defaultSettings.keepScreenOn;
  int _maxSpeedometer = AppSettings.defaultSettings.maxSpeedometer;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Check location permission
    final locationStatus = await Permission.location.status;
    
    // Check battery optimization status
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    
    // Check storage permission
    final storageStatus = await Permission.storage.status;
    
    // Check notification permission
    final notificationStatus = await Permission.notification.status;
    
    setState(() {
      _locationPermissionGranted = locationStatus.isGranted;
      _batteryOptimizationDisabled = batteryStatus.isGranted;
      _storagePermissionGranted = storageStatus.isGranted;
      _notificationPermissionGranted = notificationStatus.isGranted;
    });
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _requestLocationPermission() async {
    // Check if location service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location service is not enabled
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
    }

    // Request location permission
    final status = await Permission.location.request();
    setState(() {
      _locationPermissionGranted = status.isGranted;
    });
    
    // If granted, also try to request background location
    if (status.isGranted) {
      final backgroundStatus = await Permission.locationAlways.request();
      print('Background location permission: ${backgroundStatus.name}');
    }
  }

  Future<void> _requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    setState(() {
      _batteryOptimizationDisabled = status.isGranted;
    });
  }

  Future<void> _requestStoragePermission() async {
    // On Android 13+ (API 33+), we need to use more specific permissions
    try {
      // First try with the modern Android permission approach
      if (await Permission.photos.request().isGranted &&
          await Permission.videos.request().isGranted) {
        setState(() {
          _storagePermissionGranted = true;
        });
        return;
      }
      
      // For older Android versions, use the storage permission
      final status = await Permission.storage.request();
      
      // If still not granted, try explicit external storage management on Android 11+
      if (!status.isGranted) {
        // Using manageExternalStorage for Android 11+
        final externalStatus = await Permission.manageExternalStorage.request();
        setState(() {
          _storagePermissionGranted = externalStatus.isGranted;
        });
      } else {
        setState(() {
          _storagePermissionGranted = status.isGranted;
        });
      }
    } catch (e) {
      print('Error requesting storage permission: $e');
      // Fallback to basic storage permission
      final status = await Permission.storage.request();
      setState(() {
        _storagePermissionGranted = status.isGranted;
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    setState(() {
      _notificationPermissionGranted = status.isGranted;
    });
  }

  Future<void> _completeOnboarding() async {
    // Get settings service
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    
    // Create settings object with user preferences
    final newSettings = AppSettings(
      speedUnit: _selectedSpeedUnit,
      distanceUnit: _selectedDistanceUnit,
      keepScreenOn: _keepScreenOn,
      maxSpeedometer: _maxSpeedometer,
    );
    
    // Save settings
    await settingsService.saveSettings(newSettings);
    
    // Mark onboarding as complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    
    // Call the completion callback
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                physics: const ClampingScrollPhysics(),
                children: [
                  _buildWelcomePage(),
                  _buildPermissionsPage(),
                  _buildBatteryOptimizationPage(),
                  _buildOptionalPermissionsPage(),
                  _buildPreferencesPage(),
                ],
              ),
            ),
            _buildPageIndicator(),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.speed_rounded,
            size: 80,
            color: AppTheme.primaryColor,
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          Text(
            'Welcome to DashTime',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fade(duration: 500.ms).slide(begin: const Offset(0, 0.2), curve: Curves.easeOutQuad),
          const SizedBox(height: 16),
          Text(
            'Your advanced GPS speedometer for accurate speed tracking',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 200.ms).fade(duration: 500.ms).slide(begin: const Offset(0, 0.2), curve: Curves.easeOutQuad),
          const SizedBox(height: 48),
          Text(
            'Let\'s set up your app for the best experience',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 400.ms).fade(duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildPermissionsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 64,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Location Access',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'DashTime needs location access to track your speed and movement accurately.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _locationPermissionGranted ? null : _requestLocationPermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: _locationPermissionGranted ? Colors.green : AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _locationPermissionGranted ? Icons.check_circle : Icons.not_listed_location_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _locationPermissionGranted ? 'Granted' : 'Grant Permission',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_locationPermissionGranted)
            Text(
              'Permission granted successfully!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildBatteryOptimizationPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.battery_charging_full_rounded,
            size: 64,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Battery Optimization',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'To keep the screen on and maintain accurate tracking, DashTime needs to be excluded from battery optimization.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _batteryOptimizationDisabled ? null : _requestBatteryOptimization,
            style: ElevatedButton.styleFrom(
              backgroundColor: _batteryOptimizationDisabled ? Colors.green : AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _batteryOptimizationDisabled ? Icons.check_circle : Icons.battery_alert_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _batteryOptimizationDisabled ? 'Disabled' : 'Disable Optimization',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_batteryOptimizationDisabled)
            Text(
              'Battery optimization disabled successfully!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildOptionalPermissionsPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.app_settings_alt_rounded,
              size: 64,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Optional Permissions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'These permissions are optional but enhance your experience',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Storage permission
            Card(
              color: AppTheme.cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage Access',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Allow DashTime to save trip data and screenshots to your device',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _storagePermissionGranted ? null : _requestStoragePermission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _storagePermissionGranted ? Colors.green : AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _storagePermissionGranted ? Icons.check_circle : Icons.sd_storage_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _storagePermissionGranted ? 'Granted' : 'Grant Permission',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Notification permission
            Card(
              color: AppTheme.cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Allow DashTime to send speed alerts and trip information',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _notificationPermissionGranted ? null : _requestNotificationPermission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _notificationPermissionGranted ? Colors.green : AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _notificationPermissionGranted ? Icons.check_circle : Icons.notifications_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _notificationPermissionGranted ? 'Granted' : 'Grant Permission',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'You can change these permissions later in settings',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.settings_rounded,
              size: 64,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Your Preferences',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Customize your experience by setting your preferences',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Speed unit selection
            ListTile(
              title: Text(
                'Speed Unit',
                style: TextStyle(color: Colors.white),
              ),
              trailing: DropdownButton<String>(
                value: _selectedSpeedUnit,
                dropdownColor: AppTheme.backgroundDark,
                onChanged: (value) {
                  setState(() {
                    _selectedSpeedUnit = value!;
                  });
                },
                items: const [
                  DropdownMenuItem(
                    value: 'km/h',
                    child: Text('km/h', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'mph',
                    child: Text('mph', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'm/s',
                    child: Text('m/s', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            
            // Distance unit selection
            ListTile(
              title: Text(
                'Distance Unit',
                style: TextStyle(color: Colors.white),
              ),
              trailing: DropdownButton<String>(
                value: _selectedDistanceUnit,
                dropdownColor: AppTheme.backgroundDark,
                onChanged: (value) {
                  setState(() {
                    _selectedDistanceUnit = value!;
                  });
                },
                items: const [
                  DropdownMenuItem(
                    value: 'km',
                    child: Text('km', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'mi',
                    child: Text('mi', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'm',
                    child: Text('m', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            
            // Keep screen on
            SwitchListTile(
              title: Text(
                'Keep Screen On',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Prevents screen from turning off while using the app',
                style: TextStyle(color: Colors.white70),
              ),
              value: _keepScreenOn,
              activeColor: AppTheme.primaryColor,
              onChanged: (value) {
                setState(() {
                  _keepScreenOn = value;
                });
              },
            ),
            
            // Max speedometer value
            ListTile(
              title: Text(
                'Max Speedometer Value',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Maximum value shown on the speedometer',
                style: TextStyle(color: Colors.white70),
              ),
              trailing: DropdownButton<int>(
                value: _maxSpeedometer,
                dropdownColor: AppTheme.backgroundDark,
                onChanged: (value) {
                  setState(() {
                    _maxSpeedometer = value!;
                  });
                },
                items: const [
                  DropdownMenuItem(
                    value: 60,
                    child: Text('60', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 100,
                    child: Text('100', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 180,
                    child: Text('180', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 240,
                    child: Text('240', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 300,
                    child: Text('300', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    List<Widget> indicators = [];
    
    for (int i = 0; i < 5; i++) {
      indicators.add(
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == i ? AppTheme.primaryColor : Colors.grey.shade600,
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: indicators,
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            _currentPage == 4 ? 'Get Started' : 'Next',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
} 