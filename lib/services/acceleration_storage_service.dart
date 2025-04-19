import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/acceleration_data.dart';

class AccelerationStorageService {
  static const String _accelerationKey = 'saved_acceleration_tests';
  
  // Singleton instance
  static final AccelerationStorageService _instance = AccelerationStorageService._internal();
  factory AccelerationStorageService() => _instance;
  AccelerationStorageService._internal();
  
  // Save an acceleration test to local storage
  Future<bool> saveAccelerationTest(AccelerationData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing acceleration tests
      List<String> testStrings = prefs.getStringList(_accelerationKey) ?? [];
      
      // Convert data to JSON and add to list
      String dataJson = jsonEncode(data.toJson());
      testStrings.add(dataJson);
      
      // Save the updated list
      return await prefs.setStringList(_accelerationKey, testStrings);
    } catch (e) {
      print('Error saving acceleration test: $e');
      return false;
    }
  }
  
  // Get all saved acceleration tests
  Future<List<AccelerationData>> getAllAccelerationTests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get acceleration tests JSON strings
      List<String> testStrings = prefs.getStringList(_accelerationKey) ?? [];
      
      // Convert each JSON string to AccelerationData object
      List<AccelerationData> tests = testStrings.map((testString) {
        Map<String, dynamic> json = jsonDecode(testString);
        return AccelerationData.fromJson(json);
      }).toList();
      
      // Sort by date (newest first)
      tests.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      
      return tests;
    } catch (e) {
      print('Error retrieving acceleration tests: $e');
      return [];
    }
  }
  
  // Get acceleration tests with specific target speed
  Future<List<AccelerationData>> getTestsByTargetSpeed(double targetSpeed) async {
    List<AccelerationData> allTests = await getAllAccelerationTests();
    return allTests.where((test) => test.targetSpeed == targetSpeed).toList();
  }
  
  // Get fastest successful test for given target speed
  Future<AccelerationData?> getFastestTestForTarget(double targetSpeed) async {
    List<AccelerationData> targetTests = await getTestsByTargetSpeed(targetSpeed);
    
    // Filter for successful tests (target reached)
    List<AccelerationData> successfulTests = targetTests.where((test) => test.targetReached).toList();
    
    if (successfulTests.isEmpty) {
      return null;
    }
    
    // Sort by elapsed time (fastest first)
    successfulTests.sort((a, b) => a.elapsedMilliseconds.compareTo(b.elapsedMilliseconds));
    
    return successfulTests.first;
  }
  
  // Clear all acceleration test data
  Future<bool> clearAllTests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_accelerationKey);
    } catch (e) {
      print('Error clearing acceleration tests: $e');
      return false;
    }
  }
  
  // Delete a specific acceleration test by its date
  Future<bool> deleteTest(DateTime testDate) async {
    try {
      List<AccelerationData> tests = await getAllAccelerationTests();
      
      // Remove the test with matching date
      tests.removeWhere((test) => 
        test.dateTime.year == testDate.year && 
        test.dateTime.month == testDate.month && 
        test.dateTime.day == testDate.day &&
        test.dateTime.hour == testDate.hour &&
        test.dateTime.minute == testDate.minute &&
        test.dateTime.second == testDate.second
      );
      
      // Convert updated list back to JSON strings
      List<String> testStrings = tests.map((test) => 
        jsonEncode(test.toJson())
      ).toList();
      
      // Save the updated list
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setStringList(_accelerationKey, testStrings);
    } catch (e) {
      print('Error deleting acceleration test: $e');
      return false;
    }
  }
} 