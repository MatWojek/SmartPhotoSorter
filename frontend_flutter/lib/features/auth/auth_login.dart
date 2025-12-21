import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';

class AuthLoginCard extends StatefulWidget {
  final void Function() onSwitchToSignUp;
  final void Function(bool loggedIn, {String? userId, String? token}) onAuthChanged;

  const AuthLoginCard({
    super.key,
    required this.onSwitchToSignUp,
    required this.onAuthChanged,
  });

  @override
  State<AuthLoginCard> createState() => _AuthLoginCardState();
}

class _AuthLoginCardState extends State<AuthLoginCard> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      _showMsg('Enter your email and password');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.login(email, pass);
      if (res.containsKey('access_token')) {
        final token = res['access_token'] as String;
        _showMsg('Zalogowano');
        widget.onAuthChanged(true, token: token);
      } else {
        _showMsg(res.toString());
      }
    } catch (e) {
      _showMsg('Login error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left panel - login form
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black12, offset: Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sign in', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: () {}, child: const Text('Forgot your password?')),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('SIGN IN'),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right panel – CTA to registration 
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black12, offset: Offset(0, 6))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Hello, Friend!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary)),
                const SizedBox(height: 12),
                Text(
                  'Enter your personal details and start journey with us',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    side: BorderSide(color: Theme.of(context).colorScheme.onPrimary),
                  ),
                  onPressed: widget.onSwitchToSignUp,
                  child: const Text('SIGN UP'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
