import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AuthPanel extends StatefulWidget {
  final bool loggedIn;
  final void Function(bool loggedIn, {String? userId, String? token})? onAuthChanged;

  const AuthPanel({super.key, required this.loggedIn, this.onAuthChanged});

  @override
  State<AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<AuthPanel> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _userId; // keep id returned by register (demo)

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _register() async {
    try {
      final res = await ApiService.register(_emailCtrl.text.trim(), _passCtrl.text);
      if (res.containsKey('user_id')) {
        _userId = res['user_id'] as String?;
        _showMsg('Registered: ${_userId ?? ''}');
        widget.onAuthChanged?.call(true, userId: _userId);
      } else {
        _showMsg(res.toString());
      }
    } catch (e) { _showMsg('Register error'); }
  }

  Future<void> _login() async {
    try {
      final res = await ApiService.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (res.containsKey('access_token')) {
        final token = res['access_token'] as String;
        _showMsg('Logged in');
        widget.onAuthChanged?.call(true, token: token);
      } else {
        _showMsg(res.toString());
      }
    } catch (e) { _showMsg('Login error'); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: widget.loggedIn
          ? Align(alignment: Alignment.centerLeft, child: Text('Logged in: ${_userId ?? 'User'}'))
          : Row(
              children: [
                Expanded(child: TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true)),
                IconButton(onPressed: _register, icon: const Icon(Icons.app_registration)),
                IconButton(onPressed: _login, icon: const Icon(Icons.login)),
              ],
            ),
    );
  }
}