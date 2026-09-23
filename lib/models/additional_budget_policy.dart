/// Uses the current request fields, including partially populated requests.
/// A default Pending status with no request details is not a submission.
class AdditionalBudgetPolicy {
  static const pendingMessage =
      'An additional budget request has already been submitted and is pending '
      'approval. Please wait until it is Approved or Rejected before submitting '
      'another request.';

  static bool isPendingRequest(Map<String, dynamic> project) {
    final status = project['_additionalRequestStatus']
        ?.toString()
        .trim()
        .toLowerCase();
    if (status != 'pending') return false;
    return const [
      '_additionalBudget',
      '_additionalBudgetReason',
      '_additionalBudgetHistory',
      '_additionalBudgetRejectionReason',
    ].any((key) {
      final value = project[key];
      return value != null && (value is! String || value.trim().isNotEmpty);
    });
  }
}
