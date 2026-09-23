import 'package:arelia_supervisor/models/email_recipients.dart';
import 'package:arelia_supervisor/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts mixed separators, aliases and case-insensitive duplicates', () {
    expect(
      EmailRecipients.parse(
        ' One@example.com;two+test@example.com\nONE@example.com,\r\nthree@example.com;',
      ),
      ['one@example.com', 'two+test@example.com', 'three@example.com'],
    );
    expect(EmailRecipients.parse('  ; ,\n'), isEmpty);
    expect(
      EmailRecipients.validate('valid@example.com;invalid'),
      contains('invalid'),
    );
  });

  test(
    'multiple matches and shared addresses produce one event with distinct roles',
    () {
      final recipients = EmailRecipients.groups(
        supervisor: 'one@example.com;shared@example.com;one@example.com',
        manager: 'two@example.com,shared@example.com',
      );
      expect(recipients.length, 3);
      expect(recipients['one@example.com'], 'Supervisor');
      expect(recipients['shared@example.com'], 'Supervisor and Manager');
      final event = notificationForEmail({
        'Id': 'message1',
        'ToAddress': 'shared@example.com;one@example.com',
        'CcAddress': 'two@example.com',
        'Incoming': false,
      }, recipients);
      expect(event?['title'], 'Email sent to Supervisor and Manager');
      expect(event?['id'], 'Email:message1');
    },
  );

  test(
    'multiple recipient groups persist across restart without losing any addresses',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      String? saved;
      NotificationService create() => NotificationService(
        getToken: () async => 'test',
        getUser: () async => {'organization_id': 'org', 'user_id': 'user'},
        readState: (_) async => saved,
        writeState: (_, value) async {
          saved = value;
        },
        fetchChanges: (_, _) async => [],
        fetchEmails: (_) async => [],
      );
      final service = create();
      await service.refresh();
      await service.configureEmailRecipients(
        supervisor: 's1@example.com,s2@example.com',
        manager: 'm1@example.com\nm2@example.com;s2@example.com',
      );
      final restored = create();
      await restored.refresh();
      expect(restored.emailRecipients, {
        's1@example.com': 'Supervisor',
        's2@example.com': 'Supervisor and Manager',
        'm1@example.com': 'Manager',
        'm2@example.com': 'Manager',
      });
      await expectLater(
        restored.configureEmailRecipients(supervisor: 'bad-email', manager: ''),
        throwsFormatException,
      );
      expect(restored.emailRecipients.length, 4);
      service.dispose();
      restored.dispose();
    },
  );
}
