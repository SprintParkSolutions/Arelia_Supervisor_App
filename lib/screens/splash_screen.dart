import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_screen.dart';
import 'leads_screen.dart';
import '../services/push_notification_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFC79A53);

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fadeAnimation);
    _entranceController.forward();

    _navigationTimer = Timer(const Duration(seconds: 2), () async {
      var resumeInbox = false;
      if (PushNotificationService.instance.openInboxRequested.value) {
        try {
          if (await StorageService.getAccessToken() != null) {
            final user = await ApiService.getCurrentUser().timeout(
              const Duration(seconds: 10),
            );
            resumeInbox = user['user_id'] != null;
          }
        } catch (_) {
          /* Expired sessions must sign in; keep the inbox tap pending. */
        }
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              resumeInbox ? const LeadsScreen() : const LoginScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFF7F1E9),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/arelia_splash_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x08FFFFFF),
                    Color(0x00FFFFFF),
                    Color(0x30FFFDF9),
                  ],
                  stops: [0, 0.68, 1],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 650;
                  final logoWidth = (constraints.maxWidth * 0.43).clamp(
                    150.0,
                    205.0,
                  );

                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.17),
                          Image.asset(
                            'assets/images/arelia_logo.webp',
                            width: logoWidth,
                            fit: BoxFit.contain,
                            semanticLabel: 'Arelia Space',
                          ),
                          Transform.translate(
                            offset: const Offset(0, -8),
                            child: const _SpaceWordmark(),
                          ),
                          SizedBox(height: compact ? 18 : 30),
                          Text(
                            'Arelia Supervisor',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF171513),
                              fontSize: compact ? 27 : 31,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Interior Project Management',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.15,
                            ),
                          ),
                          SizedBox(height: compact ? 28 : 42),
                          const SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: _gold,
                              backgroundColor: Color(0x40C79A53),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Loading...',
                            style: TextStyle(
                              color: _gold,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceWordmark extends StatelessWidget {
  const _SpaceWordmark();

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: Divider(color: Color(0xFF27231F), thickness: 0.8),
    );

    return const SizedBox(
      width: 176,
      child: Row(
        children: [
          line,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 13),
            child: Text(
              'S P A C E',
              style: TextStyle(
                color: Color(0xFF27231F),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}
