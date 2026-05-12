import 'package:flutter/material.dart';
import 'auth_login.dart';
import 'auth_registration_page.dart';
import '../../core/theme_controller.dart';

class AuthLoginPage extends StatelessWidget {
  final void Function(bool loggedIn, {String? userId, String? token}) onAuthChanged;

  const AuthLoginPage({super.key, required this.onAuthChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        actions: [
          Builder(builder: (context) {
            final controller = ThemeControllerProvider.of(context);
            final isDark = controller.mode == ThemeMode.dark;
            return IconButton(
              tooltip: isDark ? 'Light mode' : 'Dark mode',
              icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
              onPressed: () => controller.toggle(),
            );
          }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: AuthLoginCard(
          onSwitchToSignUp: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AuthRegistrationPage(onAuthChanged: onAuthChanged),
              ),
            );
          },
          onAuthChanged: (loggedIn, {userId, token}) {
            onAuthChanged(loggedIn, userId: userId, token: token);
            if (loggedIn) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
