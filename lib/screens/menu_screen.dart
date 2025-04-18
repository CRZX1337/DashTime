import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';

class MenuScreen extends StatefulWidget {
  final VoidCallback onSpeedometerTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onSettingsTap;

  const MenuScreen({
    super.key,
    required this.onSpeedometerTap,
    required this.onHistoryTap,
    required this.onSettingsTap,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Timer? _devMenuTimer;
  bool _isHolding = false;

  @override
  void dispose() {
    _devMenuTimer?.cancel();
    super.dispose();
  }

  void _startDevMenuTimer() {
    _isHolding = true;
    _devMenuTimer?.cancel();
    _devMenuTimer = Timer(const Duration(seconds: 5), () {
      if (_isHolding) {
        _showDevMenu();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundDark,
              Color.lerp(AppTheme.backgroundDark, AppTheme.primaryColor, 0.2) ?? AppTheme.backgroundDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // App title
              Center(
                child: Text(
                  'DashTime',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn().slideY(
                  begin: -0.2,
                  end: 0,
                  duration: 500.milliseconds,
                  curve: Curves.easeOutQuart,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // App subtitle with long press detection for developer menu
              Center(
                child: GestureDetector(
                  onLongPressStart: (_) => _startDevMenuTimer(),
                  onLongPressEnd: (_) => _cancelDevMenuTimer(),
                  child: Text(
                    'GPS Speedometer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      letterSpacing: 2.0,
                    ),
                  ).animate().fadeIn(delay: 200.milliseconds).slideY(
                    begin: -0.2,
                    end: 0,
                    duration: 400.milliseconds,
                    curve: Curves.easeOutQuart,
                  ),
                ),
              ),
              
              const SizedBox(height: 80),
              
              // Menu items
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem(
                        context,
                        'Speedometer',
                        Icons.speed,
                        widget.onSpeedometerTap,
                        delay: 300.milliseconds,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildMenuItem(
                        context,
                        'History',
                        Icons.history,
                        widget.onHistoryTap,
                        delay: 400.milliseconds,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildMenuItem(
                        context,
                        'Settings',
                        Icons.settings,
                        widget.onSettingsTap,
                        delay: 500.milliseconds,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Version info
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Version 1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondaryDark.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ).animate().fadeIn(delay: 600.milliseconds),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    Duration delay = Duration.zero,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.textSecondaryDark,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: delay).slideX(
      begin: 0.2,
      end: 0,
      delay: delay,
      duration: 400.milliseconds,
      curve: Curves.easeOutQuart,
    );
  }
} 