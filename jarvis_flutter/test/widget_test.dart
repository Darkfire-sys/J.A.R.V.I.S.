import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:jarvis_flutter/main.dart';

void main() {
  testWidgets('renders Jarvis empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const JarvisApp(startupLaunch: false, autoInitialize: false),
    );

    expect(find.text('Good afternoon, sir'), findsOneWidget);
  });
}
