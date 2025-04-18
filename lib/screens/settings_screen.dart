import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../config/theme.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

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
  
  @override
  void initState() {
    super.initState();
    // Initialize with default values first
    _speedUnit = 'km/h';
    _distanceUnit = 'km';
    _keepScreenOn = true;
    _maxSpeedometer = 180;
    
    // Schedule loading from service after widget is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettingsFromService();
    });
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
} 