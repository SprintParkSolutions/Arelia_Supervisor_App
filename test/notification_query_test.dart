import 'dart:convert';
import 'package:arelia_supervisor/services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({'access_token': 'test'}),
  );

  test('an invalid optional field falls back to record updates', () async {
    var fallbacks = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/describe')) {
        return http.Response(
          jsonEncode({
            'fields': [
              {
                'name': 'Unavailable__c',
                'label': 'Unavailable',
                'type': 'string',
              },
            ],
          }),
          200,
        );
      }
      final query = request.url.queryParameters['q']!;
      if (query.contains('Unavailable__c')) {
        return http.Response(
          jsonEncode([
            {'errorCode': 'INVALID_FIELD', 'message': 'Unavailable field'},
          ]),
          400,
        );
      }
      fallbacks++;
      return http.Response(
        jsonEncode({
          'done': true,
          'records': [
            {
              'Id': 'p1',
              'Name': 'Project',
              'LastModifiedDate': '2026-09-11T10:00:00Z',
            },
          ],
        }),
        200,
      );
    });
    await http.runWithClient(() async {
      final rows = await ApiService.getNotificationChanges('Project', null);
      expect(rows.single['_limitedDetails'], true);
      expect(rows.single['Id'], 'p1');
    }, () => client);
    expect(fallbacks, 1);
  });

  for (final changedDuringRead in [false, true]) {
    test(
      changedDuringRead
          ? 'retries mixed record versions instead of inventing changes'
          : 'queries and merges all business fields on wide objects',
      () async {
        var queries = 0;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/describe')) {
            return http.Response(
              jsonEncode({
                'fields': [
                  for (var i = 0; i < 85; i++)
                    {
                      'name': 'Detail${i}__c',
                      'label': 'Detail $i',
                      'type': 'string',
                    },
                  {
                    'name': 'LastViewedDate',
                    'label': 'Last Viewed',
                    'type': 'datetime',
                  },
                ],
              }),
              200,
            );
          }
          queries++;
          final query = request.url.queryParameters['q']!;
          expect(query, isNot(contains('LastViewedDate')));
          final fields = query.split(' FROM ').first.substring(7).split(',');
          expect(fields.length, lessThanOrEqualTo(83));
          return http.Response(
            jsonEncode({
              'done': true,
              'records': [
                {
                  for (final field in fields) field: 'value of $field',
                  'Id': 'lead1',
                  'Name': 'Client',
                  'LastModifiedDate': changedDuringRead && queries == 2
                      ? '2026-09-11T10:01:00Z'
                      : '2026-09-11T10:00:00Z',
                },
              ],
            }),
            200,
          );
        });
        await http.runWithClient(() async {
          final request = ApiService.getNotificationChanges('Lead', null);
          if (changedDuringRead) {
            await expectLater(request, throwsStateError);
          } else {
            final rows = await request;
            expect(rows.single['Detail0__c'], 'value of Detail0__c');
            expect(rows.single['Detail84__c'], 'value of Detail84__c');
            expect((rows.single['_labels'] as Map).length, 85);
          }
        }, () => client);
        expect(queries, 2);
      },
    );
  }
}
