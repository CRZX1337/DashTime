import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'screens/menu_screen.dart';
import 'screens/speedometer_screen.dart';
import 'screens/acceleration_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/settings_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize settings service
  final settingsService = SettingsService();
  await settingsService.init();
  
  // Configure LocationService with current settings
  final locationService = LocationService();
  locationService.setSettings(settingsService.settings);
  
  // Apply keep screen on setting
  WakelockPlus.toggle(enable: settingsService.settings.keepScreenOn);
  
  // Listen for settings changes to update LocationService
  settingsService.addListener(() {
    locationService.setSettings(settingsService.settings);
    WakelockPlus.toggle(enable: settingsService.settings.keepScreenOn);
  });
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(
    ChangeNotifierProvider<SettingsService>.value(
      value: settingsService,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showOnboarding = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    
    setState(() {
      _showOnboarding = !onboardingComplete;
      _initialized = true;
    });
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DashTime GPS Speedometer',
      theme: AppTheme.darkTheme(),
      debugShowCheckedModeBanner: false,
      home: _initialized 
          ? (_showOnboarding 
              ? OnboardingScreen(onComplete: _onOnboardingComplete)
              : const MainNavigator())
          : const LoadingScreen(),
      builder: (context, child) {
        // Add responsive sizing and orientation support
        final mediaQuery = MediaQuery.of(context);
        
        // Apply text scaling factor limit for consistency
        final constrainedTextScaleFactor = 
            mediaQuery.textScaleFactor.clamp(0.8, 1.3);
        
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaleFactor: constrainedTextScaleFactor,
          ),
          child: child!,
        );
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.speed_rounded,
              size: 80,
              color: AppTheme.primaryColor,
            ).animate().scale(duration: 600.ms),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  // Simplified navigation approach
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  void _navigateToSpeedometer() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SpeedometerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }
  
  void _navigateToAcceleration() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AccelerationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  void _navigateToHistory() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HistoryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuScreen(
      onSpeedometerTap: _navigateToSpeedometer,
      onAccelerationTap: _navigateToAcceleration,
      onHistoryTap: _navigateToHistory,
      onSettingsTap: _navigateToSettings,
    );
  }
}
