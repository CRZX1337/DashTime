import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_settings.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  
  SettingsService._internal();

  late SharedPreferences _prefs;
  late AppSettings _settings;

  // Getter for current settings
  AppSettings get settings => _settings;

  // Initialize settings
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    _applySettings();
  }

  // Load settings from SharedPreferences
  void _loadSettings() {
    try {
      final Map<String, dynamic> settingsMap = {
        'speedUnit': _prefs.getString('speedUnit') ?? AppSettings.defaultSettings.speedUnit,
        'distanceUnit': _prefs.getString('distanceUnit') ?? AppSettings.defaultSettings.distanceUnit,
        'keepScreenOn': _prefs.getBool('keepScreenOn') ?? AppSettings.defaultSettings.keepScreenOn,
        'maxSpeedometer': _prefs.getInt('maxSpeedometer') ?? AppSettings.defaultSettings.maxSpeedometer,
      };
      
      _settings = AppSettings.fromJson(settingsMap);
    } catch (e) {
      // If loading fails, use default settings
      _settings = AppSettings.defaultSettings;
    }
  }

  // Apply the current settings to device
  Future<void> _applySettings() async {
    // Apply keep screen on setting
    await WakelockPlus.toggle(enable: _settings.keepScreenOn);
    
    // If screen should stay on, request battery optimization exemption
    if (_settings.keepScreenOn && Platform.isAndroid) {
      await _requestBatteryOptimizationExemption();
    }
  }

  // Request battery optimization exemption
  Future<void> _requestBatteryOptimizationExemption() async {
    if (!kIsWeb && Platform.isAndroid) {
      // Check if we already have the exemption
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isDenied) {
        // Request the permission
        final result = await Permission.ignoreBatteryOptimizations.request();
        
        // If still denied, offer to open settings
        if (result.isDenied || result.isPermanentlyDenied) {
          print("Battery optimization exemption denied");
        }
      }
    }
  }

  // Update speed unit
  Future<void> updateSpeedUnit(String speedUnit) async {
    _settings = _settings.copyWith(speedUnit: speedUnit);
    await _prefs.setString('speedUnit', speedUnit);
    notifyListeners();
  }

  // Update distance unit
  Future<void> updateDistanceUnit(String distanceUnit) async {
    _settings = _settings.copyWith(distanceUnit: distanceUnit);
    await _prefs.setString('distanceUnit', distanceUnit);
    notifyListeners();
  }

  // Update keep screen on
  Future<void> updateKeepScreenOn(bool keepScreenOn) async {
    _settings = _settings.copyWith(keepScreenOn: keepScreenOn);
    await _prefs.setBool('keepScreenOn', keepScreenOn);
    
    // Apply the keep screen on setting
    await WakelockPlus.toggle(enable: keepScreenOn);
    
    // Request battery optimization exemption if enabled
    if (keepScreenOn && Platform.isAndroid) {
      await _requestBatteryOptimizationExemption();
    }
    
    notifyListeners();
  }

  // Update max speedometer value
  Future<void> updateMaxSpeedometer(int maxSpeedometer) async {
    _settings = _settings.copyWith(maxSpeedometer: maxSpeedometer);
    await _prefs.setInt('maxSpeedometer', maxSpeedometer);
    notifyListeners();
  }

  // Save all settings at once
  Future<void> saveSettings(AppSettings newSettings) async {
    bool screenOnChanged = _settings.keepScreenOn != newSettings.keepScreenOn;
    _settings = newSettings;
    
    await _prefs.setString('speedUnit', newSettings.speedUnit);
    await _prefs.setString('distanceUnit', newSettings.distanceUnit);
    await _prefs.setBool('keepScreenOn', newSettings.keepScreenOn);
    await _prefs.setInt('maxSpeedometer', newSettings.maxSpeedometer);
    
    await _applySettings();
    notifyListeners();
  }
} 