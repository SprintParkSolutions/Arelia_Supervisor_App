import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'leads_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _gold = Color(0xFFC7964D);
  static const _ink = Color(0xFF181715);

  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);
    final success = await AuthService.login();

    if (!mounted) return;
    setState(() => loading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LeadsScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login failed. Please try again.')),
    );
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
              'assets/images/arelia_login_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x12FFFFFF),
                    Color(0x00FFFFFF),
                    Color(0x10FFF9F1),
                    Color(0xCFFAF4EC),
                  ],
                  stops: [0, 0.42, 0.78, 1],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  final horizontalPadding = (constraints.maxWidth * 0.08).clamp(
                    24.0,
                    38.0,
                  );

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: constraints.maxHeight * 0.105),
                        Image.asset(
                          'assets/images/arelia_logo.webp',
                          width: (constraints.maxWidth * 0.39).clamp(
                            142.0,
                            190.0,
                          ),
                          fit: BoxFit.contain,
                          semanticLabel: 'Arelia Space',
                        ),
                        Transform.translate(
                          offset: const Offset(0, -7),
                          child: const _SpaceWordmark(),
                        ),
                        SizedBox(height: compact ? 14 : 24),
                        Text(
                          'Arelia Supervisor',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _ink,
                            fontSize: compact ? 27 : 31,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Interior Project Management',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _gold,
                            fontSize: compact ? 15 : 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: compact ? 15 : 22),
                        const SizedBox(
                          width: 54,
                          child: Divider(color: _gold, thickness: 1),
                        ),
                        SizedBox(height: compact ? 12 : 17),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, color: _gold, size: 21),
                            SizedBox(width: 9),
                            Text(
                              'Secure supervisor access',
                              style: TextStyle(
                                color: Color(0xFF77736D),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 22 : 30),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: loading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _gold,
                              disabledBackgroundColor: _gold.withValues(
                                alpha: 0.72,
                              ),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: _gold.withValues(alpha: 0.32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: loading
                                  ? const SizedBox(
                                      key: ValueKey('loading'),
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      key: ValueKey('label'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 28),
                                        Icon(Icons.arrow_forward_ios, size: 18),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Version 1.0',
                          style: TextStyle(
                            color: Color(0xFF68645E),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const SizedBox(
                          width: 165,
                          child: Divider(color: Color(0x55C7964D), height: 1),
                        ),
                        const SizedBox(height: 13),
                        const Text.rich(
                          TextSpan(
                            text: 'Powered by ',
                            children: [
                              TextSpan(
                                text: 'AreliaSpace',
                                style: TextStyle(
                                  color: _gold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            color: Color(0xFF8D8881),
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 18),
                      ],
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
