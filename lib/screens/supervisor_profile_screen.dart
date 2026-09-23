import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class SupervisorProfileScreen extends StatefulWidget {
  const SupervisorProfileScreen({super.key});

  @override
  State<SupervisorProfileScreen> createState() =>
      _SupervisorProfileScreenState();
}

class _SupervisorProfileScreenState extends State<SupervisorProfileScreen> {
  late final Future<Map<String, dynamic>> _profile =
      ApiService.getCurrentUser();
  bool _loggingOut = false;

  String _value(Map<String, dynamic> profile, List<String> keys) {
    for (final key in keys) {
      final value = profile[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '—';
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    await StorageService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFBF8F3),
    appBar: AppBar(title: const Text('Supervisor Profile')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Unable to load profile: ${snapshot.error}'),
            ),
          );
        }
        final profile = snapshot.data!;
        final name = _value(profile, [
          'name',
          'display_name',
          'preferred_username',
        ]);
        final email = _value(profile, ['email', 'preferred_username']);
        final username = _value(profile, ['preferred_username', 'username']);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: Color(0xFFF0D7AF),
              child: Icon(
                Icons.badge_outlined,
                size: 44,
                color: Color(0xFF9B6010),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(email),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Username'),
                    subtitle: Text(username),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Role'),
                    subtitle: const Text('Supervisor'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loggingOut ? null : _logout,
              icon: _loggingOut
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(_loggingOut ? 'Logging out…' : 'Log out'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: Colors.red.shade700,
              ),
            ),
          ],
        );
      },
    ),
  );
}
