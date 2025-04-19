import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../config/responsive_util.dart';
import '../widgets/responsive_builder.dart';

class MenuScreen extends StatefulWidget {
  final VoidCallback onSpeedometerTap;
  final VoidCallback onAccelerationTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onSettingsTap;

  const MenuScreen({
    super.key,
    required this.onSpeedometerTap,
    required this.onAccelerationTap,
    required this.onHistoryTap,
    required this.onSettingsTap,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  Timer? _devMenuTimer;
  bool _isHolding = false;
  Map<String, bool> _hoveredItems = {};
  Map<String, bool> _pressedItems = {};
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _devMenuTimer?.cancel();
    _rippleController.dispose();
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
    final isLandscape = ResponsiveUtil.isLandscape(context);
    final deviceType = ResponsiveUtil.getDeviceType(context);
    
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
          child: OrientationLayoutBuilder(
            portrait: _buildPortraitLayout(context),
            landscape: _buildLandscapeLayout(context),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPortraitLayout(BuildContext context) {
    final deviceType = ResponsiveUtil.getDeviceType(context);
    
    // Adjust spacing based on screen size
    final topSpacing = ResponsiveUtil.value<double>(
      context: context,
      small: 30,
      medium: 40,
      large: 50,
      tablet: 60,
      desktop: 70,
    );
    
    final menuSpacing = ResponsiveUtil.value<double>(
      context: context,
      small: 60,
      medium: 70,
      large: 80,
      tablet: 90,
      desktop: 100,
    );
    
    final itemSpacing = ResponsiveUtil.value<double>(
      context: context,
      small: 16,
      medium: 18,
      large: 20,
      tablet: 24,
      desktop: 28,
    );
    
    // Adjust horizontal padding based on screen size
    final horizontalPadding = ResponsiveUtil.value<double>(
      context: context,
      small: 24,
      medium: 32,
      large: 32,
      tablet: 48,
      desktop: 64,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topSpacing),
        
        // App title
        Center(
          child: Text(
            'DashTime',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: AppTheme.textDark,
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveUtil.scaledFontSize(
                context, 
                base: 36,
                minFontSize: 28,
                maxFontSize: 48,
              ),
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
                fontSize: ResponsiveUtil.scaledFontSize(
                  context, 
                  base: 16,
                  minFontSize: 14,
                  maxFontSize: 20,
                ),
              ),
            ).animate().fadeIn(delay: 200.milliseconds).slideY(
              begin: -0.2,
              end: 0,
              duration: 400.milliseconds,
              curve: Curves.easeOutQuart,
            ),
          ),
        ),
        
        SizedBox(height: menuSpacing),
        
        // Menu items
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                
                SizedBox(height: itemSpacing),
                
                _buildMenuItem(
                  context,
                  'Acceleration',
                  Icons.timer,
                  widget.onAccelerationTap,
                  delay: 350.milliseconds,
                ),
                
                SizedBox(height: itemSpacing),
                
                _buildMenuItem(
                  context,
                  'History',
                  Icons.history,
                  widget.onHistoryTap,
                  delay: 400.milliseconds,
                ),
                
                SizedBox(height: itemSpacing),
                
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
              fontSize: ResponsiveUtil.scaledFontSize(
                context, 
                base: 12,
                minFontSize: 10,
                maxFontSize: 14,
              ),
            ),
          ).animate().fadeIn(delay: 600.milliseconds),
        ),
      ],
    );
  }
  
  Widget _buildLandscapeLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Row(
      children: [
        // Left side with title
        SizedBox(
          width: screenWidth * 0.4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App title
              Text(
                'DashTime',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtil.scaledFontSize(
                    context, 
                    base: 36,
                    minFontSize: 24,
                    maxFontSize: 40,
                  ),
                ),
              ).animate().fadeIn().slideY(
                begin: -0.2,
                end: 0,
                duration: 500.milliseconds,
                curve: Curves.easeOutQuart,
              ),
              
              const SizedBox(height: 8),
              
              // App subtitle with long press detection for developer menu
              GestureDetector(
                onLongPressStart: (_) => _startDevMenuTimer(),
                onLongPressEnd: (_) => _cancelDevMenuTimer(),
                child: Text(
                  'GPS Speedometer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    letterSpacing: 2.0,
                    fontSize: ResponsiveUtil.scaledFontSize(
                      context, 
                      base: 16,
                      minFontSize: 12,
                      maxFontSize: 18,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.milliseconds).slideY(
                  begin: -0.2,
                  end: 0,
                  duration: 400.milliseconds,
                  curve: Curves.easeOutQuart,
                ),
              ),
              
              // Version info at bottom of left side
              const Spacer(),
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
        
        // Right side with menu items
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                
                const SizedBox(height: 16),
                
                _buildMenuItem(
                  context,
                  'Acceleration',
                  Icons.timer,
                  widget.onAccelerationTap,
                  delay: 350.milliseconds,
                ),
                
                const SizedBox(height: 16),
                
                _buildMenuItem(
                  context,
                  'History',
                  Icons.history,
                  widget.onHistoryTap,
                  delay: 400.milliseconds,
                ),
                
                const SizedBox(height: 16),
                
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
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    Duration delay = Duration.zero,
  }) {
    final deviceType = ResponsiveUtil.getDeviceType(context);
    final isLandscape = ResponsiveUtil.isLandscape(context);
    
    // Adjust font size based on device
    final fontSize = ResponsiveUtil.value<double>(
      context: context,
      small: 16,
      medium: 17,
      large: 18,
      tablet: 20,
      desktop: 22,
    );
    
    // Adjust icon size based on device
    final iconSize = ResponsiveUtil.value<double>(
      context: context,
      small: 24,
      medium: 26,
      large: 28,
      tablet: 30,
      desktop: 32,
    );
    
    // Adjust padding based on orientation and device
    final verticalPadding = ResponsiveUtil.value<double>(
      context: context,
      small: isLandscape ? 12 : 16,
      medium: isLandscape ? 14 : 18,
      large: isLandscape ? 16 : 20,
      tablet: isLandscape ? 18 : 22,
      desktop: isLandscape ? 20 : 24,
    );
    
    final horizontalPadding = ResponsiveUtil.value<double>(
      context: context,
      small: 16,
      medium: 20,
      large: 24,
      tablet: 28,
      desktop: 32,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppTheme.primaryColor.withOpacity(0.15),
        highlightColor: AppTheme.primaryColor.withOpacity(0.05),
        child: Ink(
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
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: verticalPadding, 
              horizontal: horizontalPadding
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
                    size: iconSize,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: fontSize,
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