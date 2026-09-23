import 'package:arelia_supervisor/services/notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'updates without comparable detail reach inbox and phone once',
    () async {
      var modified = '2026-09-11T10:00:00Z';
      var popups = 0;
      final service =
          NotificationService(
              getToken: () async => 'session',
              getUser: () async => {
                'organization_id': 'org',
                'user_id': 'user',
              },
              readState: (_) async => null,
              writeState: (_, _) async {},
              fetchChanges: (source, _) async => source == 'Lead'
                  ? [
                      {
                        'Id': 'l1',
                        'Name': 'Client',
                        'LastModifiedDate': modified,
                        '_labels': {},
                      },
                    ]
                  : [],
            )
            ..onSystemNotification = (_, _) async {
              popups++;
            };
      await service.refresh();
      expect(service.items, isEmpty);
      modified = '2026-09-11T10:01:00Z';
      await service.refresh();
      expect(service.items.length, 1);
      expect(popups, 1);
      await service.refresh();
      expect(popups, 1);
      service.dispose();
    },
  );

  testWidgets('detects changes without a bell, inbox or manual refresh', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var modified = '2026-09-09T10:00:00Z';
    var leadChecks = 0;
    var popups = 0;
    Map<String, dynamic>? lastPopup;
    final service =
        NotificationService(
            getToken: () async => 'session',
            getUser: () async => {'organization_id': 'org', 'user_id': 'user'},
            readState: (_) async => null,
            writeState: (_, _) async {},
            fetchChanges: (source, _) async {
              if (source != 'Lead') return [];
              leadChecks++;
              return [
                {
                  'Id': 'lead1',
                  'Name': 'Client',
                  'LastModifiedDate': modified,
                  'Status': modified,
                  '_labels': {'Status': 'Status'},
                },
              ];
            },
          )
          ..onSystemNotification = (event, _) async {
            lastPopup = Map.from(event);
            popups++;
          };
    await service.start();
    await service.start(); // Multiple screens must not install multiple timers.
    expect(leadChecks, 1);
    modified = '2026-09-09T10:01:00Z';
    await tester.pump(const Duration(seconds: 15));
    expect(leadChecks, 2);
    expect(service.unreadCount, 1);
    expect(popups, 1);
    expect(lastPopup?['body'], service.items.single['body']);
    expect(lastPopup?['title'], service.items.single['title']);

    // Permission dialogs temporarily make the app inactive, not suspended.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 15));
    expect(leadChecks, 3);
    expect(popups, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(leadChecks, 3);
    modified = '2026-09-09T10:02:00Z';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(leadChecks, 4);
    expect(popups, 2);
    service.dispose();
    await tester.pump(const Duration(seconds: 30));
    expect(leadChecks, 4);
  });

  test(
    'silent baseline, durable clear, deduplication and retry after failure',
    () async {
      String? saved;
      var modified = '2026-09-09T10:00:00Z';
      var status = 'Open';
      var fail = false;
      NotificationService create() => NotificationService(
        getToken: () async => 'test-token',
        getUser: () async => {'organization_id': 'org', 'user_id': 'user'},
        readState: (_) async => saved,
        writeState: (_, value) async {
          saved = value;
        },
        fetchChanges: (source, since) async {
          if (source != 'Lead') return [];
          if (fail) throw StateError('offline');
          return [
            {
              'Id': 'lead1',
              'Name': 'Client',
              'LastModifiedDate': modified,
              'Status': status,
              '_labels': {'Status': 'Status'},
            },
          ];
        },
      );
      final service = create();
      await service.refresh();
      expect(service.items, isEmpty);
      modified = '2026-09-09T10:01:00Z';
      status = 'In Progress';
      fail = true;
      await service.refresh();
      expect(service.errors, contains('Lead'));
      expect(service.items, isEmpty);
      fail = false;
      await service.refresh();
      expect(service.errors, isEmpty);
      expect(service.unreadCount, 1);
      expect(service.items.single['body'], 'Status: In Progress');
      await service.refresh();
      expect(service.items.length, 1);
      await service.markRead();
      expect(service.unreadCount, 0);
      await service.clear(service.items.single['id'] as String);
      final restarted = create();
      await restarted.refresh();
      expect(restarted.items, isEmpty);
      modified = '2026-09-09T10:02:00Z';
      status = 'Completed';
      await restarted.refresh();
      expect(restarted.items.single['body'], 'Status: Completed');
      await restarted.clearAll();
      await restarted.refresh();
      expect(restarted.items, isEmpty);
      service.dispose();
      restarted.dispose();
    },
  );

  test(
    'uses actual stage and approval values without inferring completion',
    () {
      final event = notificationForChange(
        'Opportunity',
        {
          'Id': 'opportunity1',
          'Name': 'Kitchen renovation',
          'LastModifiedDate': '2026-09-09T10:00:00Z',
          'StageName': 'In Progress',
          'Manager_Approval__c': false,
          '_labels': {
            'StageName': 'Stage',
            'Manager_Approval__c': 'Manager Approval',
          },
        },
        {'StageName': 'Planning', 'Manager_Approval__c': true},
      );
      expect(event['body'], 'Stage: In Progress\nManager Approval: No');
      expect(event['id'], 'Opportunity:opportunity1:2026-09-09T10:00:00Z');
      expect(event['read'], false);
    },
  );

  test('non-stage edits produce a general update', () {
    final event = notificationForChange(
      'Lead',
      {
        'Id': 'lead1',
        'Name': 'Client',
        'LastModifiedDate': '2026-09-09T10:00:00Z',
        'Status': 'Open',
        '_labels': {'Status': 'Status'},
      },
      {'Status': 'Open'},
    );
    expect(
      event['body'],
      'Other Lead details changed. Open the record to review them.',
    );
  });

  test(
    'first observed record reports current state without invented history',
    () {
      final event = notificationForChange('Proforma Invoice', {
        'Id': 'invoice1',
        'Name': 'PI-001',
        'LastModifiedDate': '2026-09-09T10:00:00Z',
        'Client_Status__c': 'Sent',
        '_labels': {'Client_Status__c': 'Client Status'},
      }, null);
      expect(event['body'], 'Current Client Status: Sent');
    },
  );

  test(
    'assignment describes who was assigned and does not expose lookup IDs',
    () {
      final record = <String, dynamic>{
        'Id': 'lead1',
        'Name': 'Client',
        'LastModifiedDate': '2026-09-09T10:00:00Z',
        'Supervisor_User__c': 'user2',
        '_labels': {'Supervisor_User__c': 'Supervisor User'},
        '_types': {'Supervisor_User__c': 'reference'},
        '_displayValues': {'Supervisor_User__c': 'Priya'},
      };
      expect(
        notificationForChange('Lead', record, {
          'Supervisor_User__c': null,
        })['body'],
        'Supervisor assigned: Priya',
      );
      expect(
        notificationForChange('Lead', record, {
          'Supervisor_User__c': 'user1',
        })['body'],
        'Supervisor reassigned: Priya',
      );
      expect(
        notificationForChange(
          'Lead',
          {...record, 'Supervisor_User__c': null},
          {'Supervisor_User__c': 'user1'},
        )['body'],
        'Supervisor assignment removed',
      );
      expect(
        notificationForChange('Lead', record, {})['body'],
        isNot(contains('assigned')),
      );
    },
  );

  test(
    'invoice status describes the action without claiming confirmed email delivery',
    () {
      final event = notificationForChange(
        'Proforma Invoice',
        {
          'Id': 'invoice1',
          'Name': 'PI-001',
          'LastModifiedDate': '2026-09-09T10:00:00Z',
          'Client_Status__c': 'Sent',
          '_labels': {'Client_Status__c': 'Client Status'},
        },
        {'Client_Status__c': 'Draft'},
      );
      expect(event['body'], 'Proforma Invoice marked as sent to Client');
    },
  );

  test('matches email recipients exactly and ignores unrelated mail', () {
    final email = {
      'Id': 'email1',
      'ToAddress': 'notboss@example.com',
      'Subject': 'Test',
    };
    expect(
      notificationForEmail(email, {'boss@example.com': 'Manager'}),
      isNull,
    );
    email['ToAddress'] = 'Manager <BOSS@example.com>; client@example.com';
    final event = notificationForEmail(email, {'boss@example.com': 'Manager'});
    expect(event?['title'], 'Email for Manager');
  });

  test('uses thread link for replies and includes sender and both roles', () {
    final event = notificationForEmail(
      {
        'Id': 'email1',
        'ToAddress': 'supervisor@example.com',
        'CcAddress': 'manager@example.com',
        'FromAddress': 'client@example.com',
        'Subject': 'Budget approval',
        'ReplyToEmailMessageId': 'email0',
        'CreatedDate': '2026-09-09T10:00:00Z',
      },
      {
        'supervisor@example.com': 'Supervisor',
        'manager@example.com': 'Manager',
      },
    );
    expect(event?['title'], 'Reply email for Supervisor and Manager');
    expect(event?['body'], contains('client@example.com'));
    expect(event?['body'], contains('Please check your email inbox.'));
    expect(event?['id'], 'Email:email1');
  });

  test('subject alone does not prove an email is a reply', () {
    final event = notificationForEmail(
      {
        'Id': 'email1',
        'ToAddress': 'boss@example.com',
        'Subject': 'Re: proposal',
      },
      {'boss@example.com': 'Manager'},
    );
    expect(event?['title'], 'Email for Manager');
  });
}
