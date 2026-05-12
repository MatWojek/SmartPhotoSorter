import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/core/theme_controller.dart';
import 'package:frontend_flutter/features/auth/auth_login_page.dart' as auth_login;
import 'package:frontend_flutter/features/auth/auth_registration_page.dart' as auth_reg;
import 'package:frontend_flutter/features/navigation/app_top_bar.dart';
import 'package:frontend_flutter/features/home/widgets/photo_list.dart';

void main() {
  testWidgets('App builds and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(SmartPhotoOrganizerApp(controller: ThemeController()));
    // The visible title is set by AppTopBar: 'SmartPhotoSorter'
    expect(find.text('SmartPhotoSorter'), findsOneWidget);
  });

  testWidgets('Login and Register pages mount', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: auth_login.AuthLoginPage(onAuthChanged: (_, {userId, token}) {})));
    expect(find.text('Login'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: auth_reg.AuthRegistrationPage(onAuthChanged: (_, {userId, token}) {})));
    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets('TopBar shows account menu when logged in', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: AppTopBar(
          loggedIn: true,
          userId: 'u1',
          onAuthChanged: (_, {userId, token}) {},
        ),
      ),
    ),
  );
    // Stabilize initial frame
    await tester.pump();
    // Robust assertions
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(find.byTooltip('Account'), findsOneWidget);
    // Optional: keep the icon assertion if you want it too
    expect(find.byIcon(Icons.account_circle), findsOneWidget);
  });

  testWidgets('PhotoList includes Move to collection option', (WidgetTester tester) async {
    final photos = [
      {'photo_id': 'p1', 'filename': 'a.jpg', 'path': '/tmp/a.jpg', 'date_taken': '2025-01-01'},
    ];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PhotoList(userId: 'u1', photos: photos))));
    // Open popup menu
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Move to collection'), findsOneWidget);
  });
}
