import 'package:arelia_supervisor/models/additional_budget_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fields = [
    '_additionalBudget',
    '_additionalBudgetReason',
    '_additionalBudgetHistory',
    '_additionalBudgetRejectionReason',
  ];
  test(
    'default Pending with null or blank request fields allows submission',
    () {
      expect(
        AdditionalBudgetPolicy.isPendingRequest({
          '_additionalRequestStatus': 'Pending',
          for (final field in fields) field: null,
        }),
        false,
      );
      expect(
        AdditionalBudgetPolicy.isPendingRequest({
          '_additionalRequestStatus': ' Pending ',
          for (final field in fields) field: '  ',
        }),
        false,
      );
    },
  );
  for (final field in fields) {
    test('Pending with populated $field blocks even a partial request', () {
      expect(
        AdditionalBudgetPolicy.isPendingRequest({
          '_additionalRequestStatus': 'Pending',
          field: field == '_additionalBudget' ? 1000 : 'Existing details',
        }),
        true,
      );
    });
  }
  test('zero is populated, not null', () {
    expect(
      AdditionalBudgetPolicy.isPendingRequest({
        '_additionalRequestStatus': 'pending',
        '_additionalBudget': 0,
      }),
      true,
    );
  });
  for (final status in ['Approved', 'Rejected']) {
    test('$status allows another request with previous details retained', () {
      expect(
        AdditionalBudgetPolicy.isPendingRequest({
          '_additionalRequestStatus': status,
          for (final field in fields) field: 'Previous value',
        }),
        false,
      );
    });
  }
}
