import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/core/theme_controller.dart';

void main() {
  testWidgets('App builds and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(SmartPhotoOrganizerApp(controller: ThemeController()));
    // The visible title is set by AppTopBar: 'SmartPhotoSorter'
    expect(find.text('SmartPhotoSorter'), findsOneWidget);
  });
}
