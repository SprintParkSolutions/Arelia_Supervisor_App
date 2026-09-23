import 'package:arelia_supervisor/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'recipient settings backfill silently, new sent emails alert and cleared mail stays cleared',
    () async {
      String? saved;
      var popups = 0;
      final sinceValues = <String>[];
      final emails = <Map<String, dynamic>>[
        {
          'Id': 'old-email',
          'ToAddress': 'manager@example.com',
          'FromAddress': 'salesforce@example.com',
          'Incoming': false,
          'Subject': 'Additional Budget approval requested',
          'CreatedDate': DateTime.now()
              .toUtc()
              .subtract(const Duration(days: 7))
              .toIso8601String(),
        },
        {
          'Id': 'unrelated',
          'ToAddress': 'someone@example.com',
          'CreatedDate': DateTime.now().toUtc().toIso8601String(),
        },
      ];
      NotificationService make() => NotificationService(
        getToken: () async => 'test',
        getUser: () async => {'organization_id': 'org', 'user_id': 'user'},
        readState: (_) async => saved,
        writeState: (_, value) async {
          saved = value;
        },
        fetchChanges: (_, _) async => [],
        fetchEmails: (since) async {
          sinceValues.add(since);
          return emails;
        },
      );
      final service = make();
      service.onSystemNotification = (_, _) async {
        popups++;
      };
      await service.refresh();
      await service.configureEmailRecipients(
        supervisor: '',
        manager: 'manager@example.com',
      );
      expect(service.items.length, 1);
      expect(service.items.single['title'], 'Email sent to Manager');
      expect(popups, 0);
      expect(
        DateTime.parse(
          sinceValues.first,
        ).isBefore(DateTime.now().subtract(const Duration(days: 29))),
        true,
      );
      emails.add({
        ...emails.first,
        'Id': 'new-email',
        'CreatedDate': DateTime.now().toUtc().toIso8601String(),
      });
      await service.refresh();
      expect(service.items.length, 2);
      expect(popups, 1);
      await service.clear('Email:old-email');
      await service.loadEmailHistory(allHistory: true);
      expect(sinceValues.last, '1970-01-01T00:00:00.000Z');
      expect(service.items.length, 1);
      expect(popups, 1);
      final restored = make();
      await restored.refresh();
      expect(restored.emailRecipients['manager@example.com'], 'Manager');
      expect(restored.items.length, 1);
      service.dispose();
      restored.dispose();
    },
  );
}
