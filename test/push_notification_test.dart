import 'package:arelia_supervisor/services/notification_service.dart';
import 'package:arelia_supervisor/services/push_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final event = <String, dynamic>{
    'id': 'server-event-1',
    'title': 'Project updated',
    'body': 'Stage: In progress',
    'time': '2026-09-09T10:00:00Z',
    'source': 'Project',
    'recordId': 'project-1',
  };

  test('requires valid stable event data and normalizes timestamps', () {
    expect(parsePushEvent({}), isNull);
    expect(parsePushEvent({...event, 'time': 'invalid'}), isNull);
    expect(parsePushEvent({...event, 'title': 42}), isNull);
    expect(parsePushEvent(event)?['time'], '2026-09-09T10:00:00.000Z');
    expect(systemNotificationId('hello'), 1335831723);
  });

  test(
    'foreground push and feed produce one inbox item and one popup; clear survives restart',
    () async {
      String? saved;
      var popupCount = 0;
      String? cancelled;
      NotificationService create() =>
          NotificationService(
              getToken: () async => 'session',
              getUser: () async => {
                'organization_id': 'org',
                'user_id': 'user',
              },
              readState: (_) async => saved,
              writeState: (_, state) async {
                saved = state;
              },
              fetchChanges: (_, _) async =>
                  throw StateError('Polling should be skipped'),
            )
            ..fetchRemote = (_) async => {
              'events': [event],
              'cursor': 'cursor-1',
            };
      final service = create();
      service.onSystemNotification = (_, sound) async {
        popupCount++;
        expect(sound, true);
      };
      service.onSystemClear = (id) async {
        cancelled = id;
      };
      service.enqueueRemote(parsePushEvent(event)!, popup: true);
      await service.refresh();
      expect(service.items.length, 1);
      expect(popupCount, 1);
      expect(service.errors, isEmpty);
      service.enqueueRemote(parsePushEvent(event)!, popup: true);
      await service.refresh();
      expect(popupCount, 1);
      await service.clear('server-event-1');
      expect(cancelled, 'server-event-1');
      final restarted = create();
      await restarted.refresh();
      expect(restarted.items, isEmpty);
      service.dispose();
      restarted.dispose();
    },
  );

  test(
    'background catch-up does not repeat OS popups and clear-all cancels tray',
    () async {
      var popups = 0;
      var cleared = false;
      final service =
          NotificationService(
              getToken: () async => 'session',
              getUser: () async => {
                'organization_id': 'org',
                'user_id': 'user',
              },
              readState: (_) async => null,
              writeState: (_, _) async {},
              fetchChanges: (_, _) async => [],
            )
            ..fetchRemote = (_) async => {
              'events': [event],
              'cursor': 'cursor-1',
            };
      service.onSystemNotification = (_, _) async {
        popups++;
      };
      service.onSystemClearAll = () async {
        cleared = true;
      };
      await service.refresh();
      expect(service.unreadCount, 1);
      expect(popups, 0);
      await service.clearAll();
      expect(cleared, true);
      await service.refresh();
      expect(service.items, isEmpty);
      service.dispose();
    },
  );
  test(
    'a feed arriving before a foreground push does not swallow the popup',
    () async {
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
              fetchChanges: (_, _) async => [],
            )
            ..fetchRemote = (_) async => {
              'events': [event],
              'cursor': 'cursor-1',
            };
      service.onSystemNotification = (_, _) async {
        popups++;
      };
      await service.refresh();
      expect(popups, 0);
      service.enqueueRemote(parsePushEvent(event)!, popup: true);
      await service.refresh();
      expect(popups, 1);
      expect(service.items.length, 1);
      await service.clearAll();
      service.enqueueRemote(parsePushEvent(event)!, popup: true);
      await service.refresh();
      expect(popups, 1);
      expect(service.items, isEmpty);
      service.dispose();
    },
  );
}
