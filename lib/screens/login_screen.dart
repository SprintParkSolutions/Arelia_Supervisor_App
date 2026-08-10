import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'leads_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool loading = false;

Future<void> login() async {
  setState(() {
    loading = true;
  });

  bool success = await AuthService.login();

  setState(() {
    loading = false;
  });

 if (success) {

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const LeadsScreen(),
    ),
  );

} else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Login Failed"),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F0F0F),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
const Icon(
  Icons.apartment_rounded,
  size: 90,
  color: Color(0xffD4AF37),
),

const SizedBox(height: 30),

                const Text(
                  "Supervisor Portal",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Interior Project Management",
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 50),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffD4AF37),
                      foregroundColor: Colors.black,
                    ),
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text(
                            "Login with Salesforce",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  "Version 1.0",
                  style: TextStyle(
                    color: Colors.white54,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}