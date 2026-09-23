import 'dart:convert';
import 'dart:io';
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
  final metadata = [
    {'name': 'Amount__c', 'label': 'Additional Amount Requested'},
    {'name': 'Reason__c', 'label': 'Additional Amount Request Reason'},
    {'name': 'History__c', 'label': 'Additional Budget History'},
    {'name': 'Rejection__c', 'label': 'Additional Amount Rejection Reason'},
    {
      'name': 'Status__c',
      'label': 'Additional Request Status',
      'updateable': true,
      'type': 'picklist',
      'picklistValues': [
        {'value': 'Pending', 'active': true},
      ],
    },
  ];

  for (final blocked in [true, false]) {
    test(
      blocked
          ? 'pending populated request stops before upload or patch'
          : 'pending empty request can submit',
      () async {
        var writes = 0;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/describe')) {
            return http.Response(jsonEncode({'fields': metadata}), 200);
          }
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'done': true,
                'records': [
                  {
                    'Id': 'project1',
                    'Status__c': 'Pending',
                    'Amount__c': blocked ? 500 : null,
                  },
                ],
              }),
              200,
            );
          }
          writes++;
          expect(request.method, 'PATCH');
          expect(jsonDecode(request.body)['Status__c'], 'Pending');
          return http.Response('', 204);
        });
        await http.runWithClient(() async {
          final submission = ApiService.submitProjectAdditionalBudget(
            projectId: 'project1',
            amount: 1000,
            reason: 'Materials',
            files: blocked ? [File('/not-uploaded.pdf')] : [],
          );
          if (blocked) {
            await expectLater(
              submission,
              throwsA(
                predicate(
                  (error) => error.toString().contains('already been submitted'),
                ),
              ),
            );
          } else {
            await submission;
          }
        }, () => client);
        expect(writes, blocked ? 0 : 1);
      },
    );
  }

  test(
    'status becoming pending during submission is checked again before patch',
    () async {
      var reads = 0;
      var writes = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/describe')) {
          return http.Response(jsonEncode({'fields': metadata}), 200);
        }
        if (request.method == 'GET') {
          reads++;
          return http.Response(
            jsonEncode({
              'done': true,
              'records': [
                {
                  'Id': 'project1',
                  'Status__c': reads == 1 ? 'Approved' : 'Pending',
                  'Amount__c': 500,
                },
              ],
            }),
            200,
          );
        }
        writes++;
        return http.Response('', 204);
      });
      await http.runWithClient(() async {
        await expectLater(
          ApiService.submitProjectAdditionalBudget(
            projectId: 'project1',
            amount: 1000,
            reason: 'Materials',
            files: [],
          ),
          throwsA(isA<Exception>()),
        );
      }, () => client);
      expect(reads, 2);
      expect(writes, 0);
    },
  );
}
