import 'package:arelia_supervisor/services/notification_service.dart';
import 'package:arelia_supervisor/widgets/notification_inbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<NotificationService> open(
    WidgetTester tester, {
    double scale = 1,
  }) async {
    final service = NotificationService();
    service.items.addAll([
      {
        'id': '1',
        'source': 'Project',
        'title': 'Project updated · Shyam & Sons Kitchen Project',
        'body': 'Additional Request Status: Pending',
        'time': DateTime.now().toIso8601String(),
        'read': false,
      },
      {
        'id': '2',
        'source': 'Email',
        'title': 'Email from your client',
        'body': 'Please check your inbox.',
        'time': DateTime.now().toIso8601String(),
        'read': true,
      },
    ]);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(body: NotificationInbox(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('narrow phone layout and unread filter, actions and clear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = await open(tester);
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byTooltip('Clear notification').first).right,
      greaterThan(330),
    );
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('Email from your client'), findsNothing);
    await tester.tap(find.byTooltip('Notification actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(service.unreadCount, 0);
    expect(find.text('Nothing here just yet'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notification actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all notifications'));
    await tester.pumpAndSettle();
    expect(service.items, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('large text remains scrollable without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = await open(tester, scale: 1.8);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
