import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_data.dart';

class TripStorageService {
  static const String _tripsKey = 'saved_trips';
  
  // Singleton instance
  static final TripStorageService _instance = TripStorageService._internal();
  factory TripStorageService() => _instance;
  TripStorageService._internal();
  
  // Save a trip to local storage
  Future<bool> saveTrip(TripData trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing trips
      List<String> tripStrings = prefs.getStringList(_tripsKey) ?? [];
      
      // Convert trip to JSON and add to list
      String tripJson = jsonEncode(trip.toJson());
      tripStrings.add(tripJson);
      
      // Save the updated list
      return await prefs.setStringList(_tripsKey, tripStrings);
    } catch (e) {
      print('Error saving trip: $e');
      return false;
    }
  }
  
  // Get all saved trips
  Future<List<TripData>> getAllTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get trips JSON strings
      List<String> tripStrings = prefs.getStringList(_tripsKey) ?? [];
      
      // Convert each JSON string to TripData object
      List<TripData> trips = tripStrings.map((tripString) {
        Map<String, dynamic> json = jsonDecode(tripString);
        return TripData.fromJson(json);
      }).toList();
      
      // Sort by date (newest first)
      trips.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      
      return trips;
    } catch (e) {
      print('Error retrieving trips: $e');
      return [];
    }
  }
  
  // Clear all trip data
  Future<bool> clearAllTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_tripsKey);
    } catch (e) {
      print('Error clearing trips: $e');
      return false;
    }
  }
  
  // Delete a specific trip by its date
  Future<bool> deleteTrip(DateTime tripDate) async {
    try {
      List<TripData> trips = await getAllTrips();
      
      // Remove the trip with matching date
      trips.removeWhere((trip) => 
        trip.dateTime.year == tripDate.year && 
        trip.dateTime.month == tripDate.month && 
        trip.dateTime.day == tripDate.day &&
        trip.dateTime.hour == tripDate.hour &&
        trip.dateTime.minute == tripDate.minute
      );
      
      // Convert updated list back to JSON strings
      List<String> tripStrings = trips.map((trip) => 
        jsonEncode(trip.toJson())
      ).toList();
      
      // Save the updated list
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setStringList(_tripsKey, tripStrings);
    } catch (e) {
      print('Error deleting trip: $e');
      return false;
    }
  }
} 