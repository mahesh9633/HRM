import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/session_manager.dart';
import 'restaurant_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final DateTime _startTime = DateTime.now();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    debugPrint('SPLASH INIT');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));

      final isLoggedIn = await SessionManager.isLoggedIn();

      debugPrint('==============================');
      debugPrint('IS LOGGED IN = $isLoggedIn');
      debugPrint('==============================');

      _controller.forward();

      // Request runtime permissions once, before the WebView loads.
      await Permission.camera.request();
      await Permission.location.request();

      // Minimum splash duration, then navigate to RestaurantSelectionScreen.
      final elapsed = DateTime.now().difference(_startTime);
      final remaining = const Duration(seconds: 3) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }

      _goToNextScreen();
    });
  }

  void _goToNextScreen() {
    if (!mounted || _navigated) return;

    _navigated = true;

    debugPrint('GO TO RESTAURANT SELECTION');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const RestaurantSelectionScreen(),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('SPLASH DISPOSE');
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxHeight = constraints.maxHeight;
            final double maxWidth = constraints.maxWidth;

            return Stack(
              children: [
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/logo.webp',
                            height: (maxHeight * 0.32).clamp(120.0, 280.0),
                            width: (maxWidth * 0.72).clamp(180.0, 400.0),
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: (maxHeight * 0.06).clamp(16.0, 60.0),
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildDot(0),
                            const SizedBox(width: 8),
                            _buildDot(200),
                            const SizedBox(width: 8),
                            _buildDot(400),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Powered by Myteknoland',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF80CC00).withOpacity(value),
          ),
        );
      },
    );
  }
}
