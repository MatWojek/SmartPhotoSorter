import 'package:flutter/material.dart';
import 'auth_registration.dart';
import 'auth_login_page.dart';
import '../../core/theme_controller.dart';

class AuthRegistrationPage extends StatelessWidget {
  final void Function(bool loggedIn, {String? userId, String? token}) onAuthChanged;

  const AuthRegistrationPage({super.key, required this.onAuthChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
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
        child: AuthRegistrationCard(
          onSwitchToSignIn: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AuthLoginPage(onAuthChanged: onAuthChanged),
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
