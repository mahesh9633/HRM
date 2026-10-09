import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/session_manager.dart';
import 'webview_screen.dart';

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

      // Minimum splash duration, then navigate to WebViewScreen.
      // flutter_inappwebview creates its controller inside the widget
      // itself (no separate "preload" controller needed here) — the
      // real page load starts as soon as WebViewScreen mounts.
      final elapsed = DateTime.now().difference(_startTime);
      final remaining = const Duration(seconds: 3) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }

      _goToWebView();
    });
  }

  void _goToWebView() {
    if (!mounted || _navigated) return;

    _navigated = true;

    debugPrint('GO TO WEBVIEW');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const WebViewScreen(),
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Stack(
          children: [
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Image.asset(
                      //   'assets/images/logo.webp',
                      //   height: size.height * 0.32,
                      //   width: size.width * 0.72,
                      //   fit: BoxFit.contain,
                      // ),
                      ClipOval(
                        child: Image.asset(
                          'assets/images/logo.webp',
                          height: (size.shortestSide * 0.55).clamp(120.0, 260.0),
                          width: (size.shortestSide * 0.55).clamp(120.0, 260.0),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size.height * 0.08,
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
            color: const Color(0xFFFF6B1A).withOpacity(value),
          ),
        );
      },
    );
  }
}