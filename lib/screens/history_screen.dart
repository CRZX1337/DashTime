import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/trip_data.dart';
import '../services/trip_storage_service.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TripStorageService _tripStorageService = TripStorageService();
  List<TripData> _trips = [];
  bool _isLoading = true;
  TripData? _selectedTrip;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  // Load saved trips from storage
  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
    });

    List<TripData> trips = await _tripStorageService.getAllTrips();
    
    setState(() {
      _trips = trips;
      _isLoading = false;
      // Select the most recent trip by default if available
      if (_trips.isNotEmpty) {
        _selectedTrip = _trips.first;
      }
    });
  }

  // Delete a trip and reload the list
  Future<void> _deleteTrip(TripData trip) async {
    bool success = await _tripStorageService.deleteTrip(trip.dateTime);
    if (success) {
      _loadTrips();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip deleted successfully'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get speed data points for selected trip
  List<FlSpot> _getSpeedDataPoints() {
    if (_selectedTrip == null || _selectedTrip!.locationHistory.isEmpty) {
      return [const FlSpot(0, 0)];
    }

    final positions = _selectedTrip!.locationHistory;
    final startTime = positions.first.timestamp.millisecondsSinceEpoch;
    final List<FlSpot> spots = [];
    
    // Get current unit settings
    final settings = Provider.of<SettingsService>(context, listen: false).settings;
    final bool useMph = settings.speedUnit == 'mph';
    
    // Unit conversion factor
    final unitFactor = useMph ? 2.23694 : 3.6; // m/s to mph or km/h

    // Find max speed to ensure capping of outliers
    double maxRecordedSpeed = 0;
    for (final position in positions) {
      final speed = position.speed * unitFactor; // m/s to selected unit
      if (speed > maxRecordedSpeed && speed < (useMph ? 180 : 250)) { // Ignore impossible speeds
        maxRecordedSpeed = speed;
      }
    }
    
    // Use a slightly higher value than max for capping
    final capSpeed = maxRecordedSpeed * 1.1;
    
    // Handle cases with initial outliers by skipping first few readings if they're erratic
    int startIndex = 0;
    if (positions.length > 5) {
      double initialAvg = 0;
      for (int i = 0; i < 3; i++) {
        initialAvg += positions[i].speed * unitFactor;
      }
      initialAvg /= 3;
      
      // Skip initial readings if they're dramatically different
      if (initialAvg > maxRecordedSpeed * 0.8 || initialAvg < 0.5) {
        startIndex = 2; // Skip first two readings which are often erratic
      }
    }

    for (int i = startIndex; i < positions.length; i++) {
      final elapsedMinutes = (positions[i].timestamp.millisecondsSinceEpoch - startTime) / (1000 * 60);
      double speed = positions[i].speed * unitFactor; // m/s to selected unit
      
      // Ignore zero-speed readings at the start if they're very short
      if (i < 3 && speed < 0.5 && positions.length > 10) {
        continue;
      }
      
      // Cap the speed to prevent going outside the box
      speed = speed.clamp(0, capSpeed);
      
      spots.add(FlSpot(elapsedMinutes, speed));
    }

    // Apply more aggressive smoothing - window of 5 for better results
    if (spots.length > 5) {
      final smoothedSpots = <FlSpot>[];
      const windowSize = 5;
      
      // Keep first point
      smoothedSpots.add(spots.first);
      
      // Apply moving average for middle points
      for (int i = 1; i < spots.length - 1; i++) {
        final startIdx = (i - windowSize ~/ 2).clamp(0, spots.length - 1);
        final endIdx = (i + windowSize ~/ 2).clamp(0, spots.length - 1);
        
        double sumY = 0;
        for (int j = startIdx; j <= endIdx; j++) {
          sumY += spots[j].y;
        }
        
        final avgY = sumY / (endIdx - startIdx + 1);
        smoothedSpots.add(FlSpot(spots[i].x, avgY));
      }
      
      // Keep last point
      if (spots.length > 1) {
        smoothedSpots.add(spots.last);
      }
      
      return smoothedSpots;
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    // Example data for the chart
    final List<FlSpot> speedData = _selectedTrip != null 
        ? _getSpeedDataPoints()
        : [const FlSpot(0, 0)];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
            ? _buildEmptyState()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Speed chart card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Speed Over Time',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            _selectedTrip != null
                              ? 'Trip on ${DateFormat('MMM dd, yyyy').format(_selectedTrip!.dateTime)}'
                              : 'No trip data available',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryDark,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          SizedBox(
                            height: 200,
                            child: speedData.length <= 1
                              ? const Center(
                                  child: Text(
                                    'Not enough data points for chart',
                                    style: TextStyle(color: AppTheme.textSecondaryDark),
                                  ),
                                )
                              : LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: true,
                                      horizontalInterval: 20,
                                      verticalInterval: 1,
                                      getDrawingHorizontalLine: (value) {
                                        return FlLine(
                                          color: AppTheme.primaryColor.withOpacity(0.1),
                                          strokeWidth: 1,
                                        );
                                      },
                                      getDrawingVerticalLine: (value) {
                                        return FlLine(
                                          color: AppTheme.primaryColor.withOpacity(0.1),
                                          strokeWidth: 1,
                                        );
                                      },
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                            if (value % 2 == 0) {
                                              return Text(
                                                '${value.toInt()} min',
                                                style: TextStyle(
                                                  color: AppTheme.primaryColor.withOpacity(0.7),
                                                  fontSize: 12,
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 20,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              '${value.toInt()}',
                                              style: TextStyle(
                                                color: AppTheme.primaryColor.withOpacity(0.7),
                                                fontSize: 12,
                                              ),
                                            );
                                          },
                                          reservedSize: 42,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border.all(
                                        color: AppTheme.primaryColor.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    clipData: FlClipData.all(),
                                    minX: 0,
                                    maxX: speedData.isEmpty ? 12 : speedData.last.x + 1,
                                    minY: 0,
                                    maxY: _calculateMaxYValue(speedData),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: speedData,
                                        isCurved: true,
                                        curveSmoothness: 0.3,
                                        preventCurveOverShooting: true,
                                        gradient: LinearGradient(
                                          colors: const [
                                            Color.fromARGB(255, 112, 125, 248), // Primary color explicitly
                                            Color(0xFFCC2E8F), // Accent color explicitly
                                          ],
                                        ),
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 3,
                                              color: const Color(0xFFCC2E8F), // Explicit accent color
                                              strokeWidth: 1,
                                              strokeColor: Colors.white,
                                            );
                                          },
                                          checkToShowDot: (spot, barData) {
                                            // Show dots at specific intervals to reduce clutter
                                            int index = speedData.indexOf(spot);
                                            return index % 5 == 0;
                                          },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            colors: const [
                                              Color.fromARGB(102, 112, 125, 248), // 40% opacity
                                              Color(0x1ACC2E8F), // 10% opacity
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ).animate().fadeIn().slideY(
                            begin: 0.3,
                            end: 0,
                            duration: 500.milliseconds,
                            curve: Curves.easeOutQuart,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn().scale(
                    duration: 400.milliseconds,
                    curve: Curves.easeOutBack,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Recent Trips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Trips',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _trips.isEmpty ? null : () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clear All Trips?'),
                              content: const Text('This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('CANCEL'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _tripStorageService.clearAllTrips();
                                    _loadTrips();
                                  },
                                  child: const Text('CLEAR ALL'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Clear All'),
                        style: TextButton.styleFrom(
                          foregroundColor: _trips.isEmpty ? Colors.grey : Colors.red,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.milliseconds),
                  
                  const SizedBox(height: 16),
                  
                  // Trip history list
                  ..._trips.map((trip) {
                    return _buildTripCard(
                      context: context,
                      trip: trip,
                      isSelected: _selectedTrip?.dateTime == trip.dateTime,
                      onSelect: () {
                        setState(() {
                          _selectedTrip = trip;
                        });
                      },
                      onDelete: () => _deleteTrip(trip),
                    );
                  }).toList(),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: AppTheme.textSecondaryDark.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No trips recorded yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start tracking your trips on the speedometer screen',
            style: TextStyle(
              color: AppTheme.textSecondaryDark,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.speed),
            label: const Text('GO TO SPEEDOMETER'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildTripCard({
    required BuildContext context,
    required TripData trip,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onDelete,
  }) {
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final timeFormatter = DateFormat('hh:mm a');
    
    // Get current unit settings
    final settings = Provider.of<SettingsService>(context, listen: false).settings;
    final bool useMph = settings.speedUnit == 'mph';
    final bool useMiles = settings.distanceUnit == 'miles';
    
    // Convert units if needed
    final double maxSpeed = useMph ? trip.maxSpeed * 0.621371 : trip.maxSpeed;
    final double avgSpeed = useMph ? trip.avgSpeed * 0.621371 : trip.avgSpeed;
    final String speedUnit = useMph ? 'mph' : 'km/h';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isSelected ? AppTheme.cardDark.withOpacity(0.8) : null,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trip date and time with delete option
              Row(
                children: [
                  const Icon(
                    Icons.event,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormatter.format(trip.dateTime),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    timeFormatter.format(trip.dateTime),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.withOpacity(0.7),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Trip?'),
                          content: const Text('This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onDelete();
                              },
                              child: const Text('DELETE'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Trip stats grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTripStat(
                    label: 'Max Speed',
                    value: '${maxSpeed.toStringAsFixed(1)} $speedUnit',
                    icon: Icons.speed,
                    color: AppTheme.accentColor,
                  ),
                  _buildTripStat(
                    label: 'Avg Speed',
                    value: '${avgSpeed.toStringAsFixed(1)} $speedUnit',
                    icon: Icons.calculate,
                    color: AppTheme.primaryColor,
                  ),
                  _buildTripStat(
                    label: 'Distance',
                    value: _formatDistance(trip.distance, useMiles),
                    icon: Icons.straighten,
                    color: AppTheme.accentColor,
                  ),
                  _buildTripStat(
                    label: 'Duration',
                    value: '${trip.getFormattedTime()} min',
                    icon: Icons.timer,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
              
              // Selected indicator
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Selected for chart view',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX(
      begin: 0.1,
      end: 0,
      duration: 300.milliseconds,
    );
  }

  Widget _buildTripStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryDark,
          ),
        ),
      ],
    );
  }

  double _calculateMaxYValue(List<FlSpot> spots) {
    if (spots.isEmpty) return 80;
    double maxY = 0;
    for (var spot in spots) {
      if (spot.y > maxY) {
        maxY = spot.y;
      }
    }
    return maxY * 1.2;
  }

  String _formatDistance(double distance, bool useMiles) {
    if (useMiles) {
      return '${(distance * 0.621371).toStringAsFixed(2)} miles';
    } else {
      return '${distance.toStringAsFixed(2)} km';
    }
  }
} 