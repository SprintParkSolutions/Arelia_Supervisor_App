import 'package:arelia_supervisor/models/notification_fields.dart';
import 'package:arelia_supervisor/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracks business fields without requiring known workflow keywords', () {
    for (final type in [
      'string',
      'textarea',
      'currency',
      'percent',
      'date',
      'boolean',
      'reference',
      'email',
      'phone',
      'url',
      'multipicklist',
    ]) {
      expect(
        isNotificationField({'name': 'Custom_Detail__c', 'type': type}),
        isTrue,
      );
    }
    expect(
      isNotificationField({'name': 'LastModifiedDate', 'type': 'datetime'}),
      isFalse,
    );
    expect(
      isNotificationField({
        'name': 'Secret__c',
        'type': 'string',
        'encrypted': true,
      }),
      isFalse,
    );
    expect(
      isNotificationField({
        'name': 'Old__c',
        'type': 'string',
        'deprecatedAndHidden': true,
      }),
      isFalse,
    );
    expect(isNotificationField({'name': 'Blob__c', 'type': 'base64'}), isFalse);
  });

  test('every monitored record type describes arbitrary business changes', () {
    for (final source in NotificationService.sources) {
      final result = notificationForChange(
        source,
        {
          'Id': 'record1',
          'Name': 'Example',
          'LastModifiedDate': '2026-09-11T10:00:00Z',
          'Finish__c': 'Matte',
          'Phone': '12345',
          'Discount__c': 12,
          'Reason__c': null,
          'Milestone__c': true,
          '_labels': {
            'Finish__c': 'Finish',
            'Phone': 'Phone',
            'Discount__c': 'Discount',
            'Reason__c': 'Reason',
            'Milestone__c': 'Milestone',
          },
          '_types': {'Discount__c': 'percent'},
        },
        {
          'Finish__c': 'Gloss',
          'Phone': '67890',
          'Discount__c': 5,
          'Reason__c': 'Old reason',
          'Milestone__c': false,
        },
      );
      expect(
        result['body'],
        'Finish: Matte\nPhone: 12345\nDiscount: 12%\nReason: Cleared\nMilestone: Yes',
      );
    }
  });

  test('related record changes are links, not staff assignments', () {
    final result = notificationForChange(
      'Project',
      {
        'Id': 'p1',
        'Name': 'Project',
        'LastModifiedDate': '2026-09-11T10:00:00Z',
        'AccountId': 'a2',
        '_labels': {'AccountId': 'Account'},
        '_types': {'AccountId': 'reference'},
        '_displayValues': {'AccountId': 'New Client'},
      },
      {'AccountId': 'a1'},
    );
    expect(result['body'], 'Account changed: New Client');
    expect(notificationValue('A;B', 'multipicklist'), 'A, B');
    expect(
      notificationValue('x' * 1000, 'textarea').length,
      lessThanOrEqualTo(180),
    );
  });
}
