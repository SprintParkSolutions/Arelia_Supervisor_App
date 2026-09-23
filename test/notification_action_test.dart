import 'dart:async';
import 'package:arelia_supervisor/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'confirmed assignment displays immediately during a slow poll and deduplicates catch-up',
    () async {
      var modified = '2026-09-11T10:00:00Z';
      String? supervisor;
      var stage = 'Open';
      Completer<List<Map<String, dynamic>>>? slow;
      final popups = <Map<String, dynamic>>[];
      final service =
          NotificationService(
              getToken: () async => 'session',
              getUser: () async => {
                'organization_id': 'org',
                'user_id': 'user',
              },
              readState: (_) async => null,
              writeState: (_, _) async {},
              fetchChanges: (source, _) async {
                if (source == 'Project' && slow != null) return slow.future;
                if (source != 'Lead') return [];
                return [
                  {
                    'Id': 'l1',
                    'Name': 'Client',
                    'LastModifiedDate': modified,
                    'Supervisor_User__c': supervisor,
                    'Status': stage,
                    '_labels': {
                      'Supervisor_User__c': 'Supervisor User',
                      'Status': 'Stage',
                    },
                    '_types': {'Supervisor_User__c': 'reference'},
                    '_displayValues': {'Supervisor_User__c': 'Priya'},
                  },
                ];
              },
            )
            ..onSystemNotification = (event, _) async {
              popups.add(event);
            };
      await service.refresh();
      slow = Completer();
      final poll = service.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(service.busy, true);
      await service.recordConfirmedAction(
        source: 'Lead',
        recordId: 'l1',
        title: 'Supervisor assigned · Client',
        body: 'Supervisor assigned: Priya',
        fields: {'Supervisor_User__c': 'u1'},
      );
      expect(popups.single['body'], 'Supervisor assigned: Priya');
      expect(service.items.single['body'], popups.single['body']);
      expect(service.busy, true);
      slow.complete([]);
      await poll;
      slow = null;
      supervisor = 'u1';
      modified = '2026-09-11T10:01:00Z';
      await service.refresh();
      expect(popups.length, 1);
      // An independent update without field details must still reach the user.
      modified = '2026-09-11T10:02:00Z';
      await service.refresh();
      expect(popups.length, 2);
      // Other real changes still arrive before an unrelated query finishes.
      stage = 'In Progress';
      modified = '2026-09-11T10:03:00Z';
      slow = Completer();
      final next = service.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(service.busy, true);
      expect(popups.last['body'], 'Stage: In Progress');
      slow.complete([]);
      await next;
      service.dispose();
    },
  );
}
