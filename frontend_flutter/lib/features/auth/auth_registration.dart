import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AuthRegistrationCard extends StatefulWidget {
  final void Function() onSwitchToSignIn;
  final void Function(bool loggedIn, {String? userId, String? token}) onAuthChanged;

  const AuthRegistrationCard({
    super.key,
    required this.onSwitchToSignIn,
    required this.onAuthChanged,
  });

  @override
  State<AuthRegistrationCard> createState() => _AuthRegistrationCardState();
}

class _AuthRegistrationCardState extends State<AuthRegistrationCard> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false;
  String? _userId; // keep id returned by register (demo)

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _register() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      _showMsg('Enter your email and password');
      return;
    }
    if (_pass2Ctrl.text != pass) {
      _showMsg('Login error');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.register(email, pass);

      if (res.containsKey('user_id')) {
        _userId = res['user_id'] as String?;
        // Auto-login
        final loginRes = await ApiService.login(email, pass);
        if (loginRes.containsKey('access_token')) {
          final token = loginRes['access_token'] as String;
          widget.onAuthChanged(true, userId: _userId, token: token);
          _showMsg('Registered and logged in');
        } else {
          _showMsg('Registered but login failed: ${loginRes.toString()}');
        }
      } else if (res.containsKey('access_token')) {
        final token = res['access_token'] as String;
        widget.onAuthChanged(true, token: token);
        _showMsg('Registered and logged in');
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
        // Left panel – CTA to login
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
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black12, offset: Offset(0, 6))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Welcome Back!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary)),
                const SizedBox(height: 12),
                Text('To keep connected please login with your personal info',
                    textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7))),
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    side: BorderSide(color: Theme.of(context).colorScheme.onPrimary),
                  ),
                  onPressed: widget.onSwitchToSignIn,
                  child: const Text('SIGN IN'),
                ),
              ],
            ),
          ),
        ),
        // Right panel – registration 
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black12, offset: Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                const SizedBox(height: 12),
                TextField(controller: _pass2Ctrl, decoration: const InputDecoration(labelText: 'Confirm password'), obscureText: true),
                const SizedBox(height: 16),
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('SIGN UP'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
