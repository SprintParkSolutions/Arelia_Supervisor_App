/// Track readable business values without a workflow-specific keyword list.
/// Audit bookkeeping and binary/compound values aren't useful change messages.
bool isNotificationField(Map field) {
  const auditFields = {
    'Id',
    'CreatedDate',
    'CreatedById',
    'LastModifiedDate',
    'LastModifiedById',
    'SystemModstamp',
    'LastViewedDate',
    'LastReferencedDate',
    'IsDeleted',
    'MasterRecordId',
    'PhotoUrl',
  };
  const valueTypes = {
    'boolean',
    'picklist',
    'multipicklist',
    'string',
    'reference',
    'date',
    'datetime',
    'time',
    'currency',
    'double',
    'int',
    'long',
    'percent',
    'email',
    'phone',
    'url',
    'textarea',
  };
  return !auditFields.contains(field['name']) &&
      field['deprecatedAndHidden'] != true &&
      field['encrypted'] != true &&
      valueTypes.contains(field['type']);
}

String notificationValue(dynamic value, String? type) {
  if (value == null || value == '') return 'Cleared';
  if (value == true) return 'Yes';
  if (value == false) return 'No';
  if (type == 'percent') return '$value%';
  if (type == 'multipicklist') return value.toString().split(';').join(', ');
  if (type == 'datetime') {
    final date = DateTime.tryParse(value.toString());
    if (date != null) {
      final local = date.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${local.year}-${two(local.month)}-${two(local.day)} '
          '${two(local.hour)}:${two(local.minute)}';
    }
  }
  // Keep long descriptions readable on the lock screen, with full data in record.
  final text = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length > 180 ? '${text.substring(0, 177)}…' : text;
}
