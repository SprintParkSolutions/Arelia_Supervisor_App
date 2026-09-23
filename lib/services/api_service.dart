import 'dart:convert';
import 'package:http/http.dart' as http;

import 'storage_service.dart';
import '../models/additional_budget_policy.dart';
import '../models/notification_fields.dart';
import 'dart:io';

class ApiService {
  static const String instanceUrl =
      "https://sprintpark--dev4.sandbox.my.salesforce.com";

  static Map<String, String>? _projectFieldCache;
  static Map<String, dynamic>? _expenseSheetMetadataCache;
  static Map<String, String>? _projectPaymentTermMetadataCache;
  static Map<String, dynamic>? _vendorAssignmentMetadataCache;
  static Map<String, String>? _vendorTaskFieldCache;
  static final Map<String, dynamic> _referenceNameCache = {};

  static Future<Map<String, dynamic>> _getVendorAssignmentMetadata(
    String? token,
  ) async {
    if (_vendorAssignmentMetadataCache != null) {
      return _vendorAssignmentMetadataCache!;
    }
    final projectDescribe = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Project__c/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (projectDescribe.statusCode != 200)
      throw Exception(projectDescribe.body);
    final relationships =
        jsonDecode(projectDescribe.body)['childRelationships']
            as List<dynamic>? ??
        const [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    Map<String, dynamic>? relationship;
    for (final raw in relationships) {
      final item = raw as Map<String, dynamic>;
      final signature =
          normalize(item['relationshipName']) + normalize(item['childSObject']);
      if (signature.contains('vendorassignment')) {
        relationship = item;
        break;
      }
    }
    if (relationship == null)
      throw Exception('Vendor Assignment object was not found.');
    final objectName = relationship['childSObject'].toString();
    final describe = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/$objectName/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (describe.statusCode != 200) throw Exception(describe.body);
    final payload = jsonDecode(describe.body) as Map<String, dynamic>;
    final fields = (payload['fields'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    Map<String, dynamic>? find(List<String> candidates) {
      for (final candidate in candidates) {
        for (final field in fields) {
          if (normalize(field['label']) == normalize(candidate) ||
              normalize(field['name']) == normalize(candidate))
            return field;
        }
      }
      return null;
    }

    final result = <String, dynamic>{
      'object': objectName,
      'label': payload['label'] ?? 'Vendor Assignment',
      'labelPlural': payload['labelPlural'] ?? 'Vendor Assignments',
      'projectLookup': relationship['field'].toString(),
      'fields': fields,
      'childRelationships': payload['childRelationships'] ?? const [],
      'status': find([
        'Status',
        'Vendor Status',
        'Vendor Work Status',
        'Assignment Status',
      ]),
      'abscond': find([
        'Abscond',
        'Absconded',
        'Vendor Abscond',
        'Vendor Absconded',
        'Is Absconded',
      ]),
      'vendor': find(['Vendor', 'Assigned Vendor']),
      'project': find(['Project']),
    };
    _vendorAssignmentMetadataCache = result;
    return result;
  }

  static Future<List<Map<String, dynamic>>> getVendorAssignments() async {
    final token = await StorageService.getAccessToken();
    final metadata = await _getVendorAssignmentMetadata(token);
    final fields = (metadata['fields'] as List<Map<String, dynamic>>);
    final preferred = <Map<String, dynamic>>[
      ...fields.where((field) => field['name'] == 'Name'),
      if (metadata['vendor'] != null)
        metadata['vendor'] as Map<String, dynamic>,
      if (metadata['project'] != null)
        metadata['project'] as Map<String, dynamic>,
      if (metadata['status'] != null)
        metadata['status'] as Map<String, dynamic>,
      ...fields.where(
        (field) => const ['date', 'datetime'].contains(field['type']),
      ),
    ];
    final unique = <String, Map<String, dynamic>>{};
    for (final field in preferred) {
      unique.putIfAbsent(field['name'].toString(), () => field);
    }
    final selected = unique.values.take(12).toList();
    final records = await _queryAllRecords(
      'SELECT Id,${selected.map((field) => field['name']).join(',')} '
      'FROM ${metadata['object']} ORDER BY LastModifiedDate DESC LIMIT 200',
    );
    return Future.wait(
      records.map((record) async {
        final values = <String, dynamic>{};
        for (final field in selected) {
          final apiName = field['name'].toString();
          values[apiName] = await _friendlyReferenceValue(
            token,
            field,
            record[apiName],
          );
        }
        return {
          'id': record['Id'],
          'name': record['Name'],
          'status': metadata['status'] == null
              ? null
              : record[(metadata['status'] as Map)['name']],
          'vendor': metadata['vendor'] == null
              ? null
              : await _friendlyReferenceValue(
                  token,
                  metadata['vendor'] as Map<String, dynamic>,
                  record[(metadata['vendor'] as Map)['name']],
                ),
          'project': metadata['project'] == null
              ? null
              : await _friendlyReferenceValue(
                  token,
                  metadata['project'] as Map<String, dynamic>,
                  record[(metadata['project'] as Map)['name']],
                ),
          'values': values,
        };
      }),
    );
  }

  static Future<dynamic> _friendlyReferenceValue(
    String? token,
    Map<String, dynamic> field,
    dynamic value,
  ) async {
    if (value == null || field['type'] != 'reference') return value;
    final cacheKey = '${field['referenceTo']}.$value';
    if (_referenceNameCache.containsKey(cacheKey)) {
      return _referenceNameCache[cacheKey];
    }
    for (final target in field['referenceTo'] as List<dynamic>? ?? const []) {
      try {
        final records = await _queryAllRecords(
          'SELECT Name FROM $target WHERE Id=\'$value\' LIMIT 1',
        );
        if (records.isNotEmpty) {
          final resolved = records.first['Name'] ?? value;
          _referenceNameCache[cacheKey] = resolved;
          return resolved;
        }
      } catch (_) {}
    }
    return value;
  }

  static Future<Map<String, dynamic>> getVendorAssignmentDetails(
    String id,
  ) async {
    final token = await StorageService.getAccessToken();
    final metadata = await _getVendorAssignmentMetadata(token);
    final fields = (metadata['fields'] as List<Map<String, dynamic>>)
        .where(
          (field) =>
              !const {'address', 'location', 'base64'}.contains(field['type']),
        )
        .toList();
    final values = await _queryRecordFields(
      objectName: metadata['object'].toString(),
      recordId: id,
      fieldNames: fields.map((field) => field['name'].toString()).toList(),
    );
    final details = <Map<String, dynamic>>[];
    for (final field in fields) {
      final apiName = field['name'].toString();
      details.add({
        'label': field['label'] ?? apiName,
        'apiName': apiName,
        'type': field['type'],
        'value': await _friendlyReferenceValue(token, field, values[apiName]),
      });
    }
    return {
      'id': id,
      'name': values['Name'],
      'status': metadata['status'] == null
          ? null
          : values[(metadata['status'] as Map)['name']],
      'fields': details,
      'relatedLists': await _getVendorAssignmentRelatedLists(
        token,
        metadata,
        id,
      ),
    };
  }

  static Future<List<Map<String, dynamic>>> _getVendorAssignmentRelatedLists(
    String? token,
    Map<String, dynamic> metadata,
    String id,
  ) async {
    final loaders = <Future<Map<String, dynamic>>>[];
    final seen = <String>{};
    for (final raw
        in metadata['childRelationships'] as List<dynamic>? ?? const []) {
      final relationship = raw as Map<String, dynamic>;
      final name = relationship['relationshipName']?.toString();
      final objectName = relationship['childSObject']?.toString();
      final lookup = relationship['field']?.toString();
      if (name == null ||
          objectName == null ||
          lookup == null ||
          name.toLowerCase().contains('share') ||
          name.toLowerCase().contains('feed') ||
          !seen.add('$objectName.$lookup'))
        continue;
      try {
        loaders.add(
          _loadProjectRelatedList(
            token: token,
            projectId: id,
            objectName: objectName,
            lookupField: lookup,
            relationshipName: name,
          ),
        );
      } catch (_) {}
      if (loaders.length >= 12) break;
    }
    final results = await Future.wait(
      loaders.map((loader) async {
        try {
          return await loader;
        } catch (_) {
          return <String, dynamic>{};
        }
      }),
    );
    return results.where((item) => item.isNotEmpty).toList();
  }

  static Future<void> updateVendorAssignmentStatus({
    required String assignmentId,
    required bool abscond,
  }) async {
    final token = await StorageService.getAccessToken();
    final metadata = await _getVendorAssignmentMetadata(token);
    final status = metadata['status'] as Map<String, dynamic>?;
    final abscondField = metadata['abscond'] as Map<String, dynamic>?;
    if ((!abscond && (status == null || status['updateable'] != true)) ||
        (abscond &&
            (status == null || status['updateable'] != true) &&
            (abscondField == null || abscondField['updateable'] != true))) {
      throw Exception(
        'Updateable Salesforce field for this Vendor Assignment action was not found.',
      );
    }
    final choices = (status?['picklistValues'] as List<dynamic>? ?? const [])
        .where((item) => (item as Map)['active'] == true)
        .map((item) => (item as Map)['value'].toString())
        .toList();
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final desired = abscond
        ? choices
              .where((value) => normalize(value).contains('abscond'))
              .firstOrNull
        : choices.where((value) {
            final item = normalize(value);
            return item.contains('inprogress') || item.contains('started');
          }).firstOrNull;
    if (desired == null &&
        (!abscond ||
            abscondField == null ||
            abscondField['updateable'] != true)) {
      throw Exception(
        abscond
            ? 'Abscond status value was not found in Salesforce.'
            : 'Started/In Progress status value was not found in Salesforce.',
      );
    }
    final updates = <String, dynamic>{
      if (desired != null) status!['name'].toString(): desired,
      if (abscond &&
          abscondField != null &&
          abscondField['updateable'] == true &&
          abscondField['type'] == 'boolean')
        abscondField['name'].toString(): true,
    };
    final response = await http.patch(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/${metadata['object']}/$assignmentId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      // Updating the org's own workflow fields lets its record-triggered Flow,
      // notifications, and replacement handling run normally.
      body: jsonEncode(updates),
    );
    if (response.statusCode != 204) throw Exception(response.body);
  }

  static Future<List<Map<String, dynamic>>> getVendorAssignmentTasks(
    String assignmentId,
  ) async {
    final token = await StorageService.getAccessToken();
    final custom = await _getVendorTaskFields(token);
    final selected = <String>{
      'Id',
      'Subject',
      'Status',
      'Priority',
      'ActivityDate',
      'Description',
      'Owner.Name',
      'CreatedDate',
      ...custom.values,
    };
    final records = await _queryAllRecords(
      'SELECT ${selected.join(',')} '
      "FROM Task WHERE WhatId='$assignmentId' ORDER BY CreatedDate DESC LIMIT 100",
    );
    return records.map((raw) {
      final record = Map<String, dynamic>.from(raw as Map);
      record['_startDate'] = custom['startDate'] == null
          ? null
          : record[custom['startDate']];
      record['_endDate'] = custom['endDate'] == null
          ? record['ActivityDate']
          : record[custom['endDate']];
      record['_assignedPercentage'] = custom['assignedPercentage'] == null
          ? null
          : record[custom['assignedPercentage']];
      return record;
    }).toList();
  }

  static Future<Map<String, String>> _getVendorTaskFields(String? token) async {
    if (_vendorTaskFieldCache != null) return _vendorTaskFieldCache!;
    final response = await http.get(
      Uri.parse('$instanceUrl/services/data/v64.0/sobjects/Task/describe'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final fields =
        jsonDecode(response.body)['fields'] as List<dynamic>? ?? const [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    String? find(List<String> labels) {
      for (final label in labels) {
        for (final raw in fields) {
          final field = raw as Map<String, dynamic>;
          if (field['updateable'] == true &&
              (normalize(field['label']) == normalize(label) ||
                  normalize(field['name']) == normalize(label))) {
            return field['name']?.toString();
          }
        }
      }
      return null;
    }

    final result = <String, String>{};
    final start = find(['Task Start Date', 'Start Date', 'Work Start Date']);
    final end = find(['Task End Date', 'End Date', 'Work End Date']);
    final assignedPercentage = find([
      'Assigned Percentage',
      'Assignment Percentage',
    ]);
    if (start != null) result['startDate'] = start;
    if (end != null && end != 'ActivityDate') result['endDate'] = end;
    if (assignedPercentage != null) {
      result['assignedPercentage'] = assignedPercentage;
    }
    _vendorTaskFieldCache = result;
    return result;
  }

  static Future<String> saveVendorAssignmentTask({
    required String assignmentId,
    String? taskId,
    required String subject,
    required String status,
    required String priority,
    String? startDate,
    String? dueDate,
    num? assignedPercentage,
    String? description,
    List<File> files = const [],
  }) async {
    if (subject.trim().isEmpty) throw Exception('Task subject is required.');
    final token = await StorageService.getAccessToken();
    final custom = await _getVendorTaskFields(token);
    final body = <String, dynamic>{
      'Subject': subject.trim(),
      'Status': status,
      'Priority': priority,
      'ActivityDate': (dueDate?.trim().isNotEmpty ?? false) ? dueDate : null,
      if (custom['startDate'] != null)
        custom['startDate']!: startDate?.trim().isEmpty == true
            ? null
            : startDate,
      if (custom['assignedPercentage'] != null)
        custom['assignedPercentage']!: assignedPercentage,
      'Description': description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      if (taskId == null) 'WhatId': assignmentId,
    };
    final response = taskId == null
        ? await http.post(
            Uri.parse('$instanceUrl/services/data/v64.0/sobjects/Task'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
        : await http.patch(
            Uri.parse('$instanceUrl/services/data/v64.0/sobjects/Task/$taskId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
    if (response.statusCode != (taskId == null ? 201 : 204)) {
      throw Exception(response.body);
    }
    final savedId = taskId ?? jsonDecode(response.body)['id']?.toString();
    if (savedId == null)
      throw Exception('Salesforce did not return the Task ID.');
    for (final file in files) {
      await _uploadAndLinkSalesforceFile(
        token: token,
        linkedEntityId: savedId,
        file: file,
      );
    }
    return savedId;
  }

  /// Fetches every Project record and maps the org-specific custom fields to
  /// stable keys consumed by the mobile UI.
  static Future<List<dynamic>> getProjects() async {
    final token = await StorageService.getAccessToken();
    final fields = await _getProjectFields(token);
    final selected = <String>{
      'Id',
      'Name',
      'Owner.Name',
      'CreatedDate',
      'LastModifiedDate',
      ...fields.values,
    };
    final records = await _queryAllRecords(
      'SELECT ${selected.join(',')} FROM Project__c '
      'ORDER BY LastModifiedDate DESC',
    );
    return records.map((record) {
      final mapped = Map<String, dynamic>.from(record as Map);
      for (final entry in fields.entries) {
        mapped['_${entry.key}'] = mapped[entry.value];
      }
      return mapped;
    }).toList();
  }

  static Future<Map<String, dynamic>> getProject(String projectId) async {
    final token = await StorageService.getAccessToken();
    final fields = await _getProjectFields(token);
    final selected = <String>{
      'Id',
      'Name',
      'Owner.Name',
      'CreatedDate',
      'LastModifiedDate',
      ...fields.values,
    };
    final records = await _queryAllRecords(
      'SELECT ${selected.join(',')} FROM Project__c '
      "WHERE Id='$projectId' LIMIT 1",
    );
    if (records.isNotEmpty) {
      final mapped = Map<String, dynamic>.from(records.first as Map);
      for (final entry in fields.entries) {
        mapped['_${entry.key}'] = mapped[entry.value];
      }
      // The roll-up/count field can lag behind or be absent in some orgs.
      // Actual Vendor Assignment children are the authoritative signal used
      // by the Project pathway.
      try {
        final vendorMetadata = await _getVendorAssignmentMetadata(token);
        final assignments = await _queryAllRecords(
          'SELECT Id FROM ${vendorMetadata['object']} '
          "WHERE ${vendorMetadata['projectLookup']}='$projectId' LIMIT 200",
        );
        if (assignments.isNotEmpty) {
          mapped['_totalVendors'] = assignments.length;
        }
      } catch (_) {
        // Keep the Project field value if related records are inaccessible.
      }
      return mapped;
    }
    throw Exception('Project not found.');
  }

  /// Returns the Project Detail fields that Salesforce marks as updateable,
  /// together with their current values and picklist choices.
  static Future<List<Map<String, dynamic>>> getEditableProjectDetails(
    String projectId,
  ) async {
    final token = await StorageService.getAccessToken();
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Project__c/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final described =
        jsonDecode(response.body)['fields'] as List<dynamic>? ?? const [];
    final byName = <String, Map<String, dynamic>>{
      for (final raw in described)
        (raw as Map<String, dynamic>)['name'].toString(): raw,
    };
    const unsupported = {'address', 'location', 'base64'};
    final editableMetadata =
        byName.entries
            .where(
              (entry) =>
                  entry.value['updateable'] == true &&
                  entry.value['calculated'] != true &&
                  !unsupported.contains(entry.value['type']),
            )
            .toList()
          ..sort((a, b) {
            if (a.key == 'Name') return -1;
            if (b.key == 'Name') return 1;
            return '${a.value['label']}'.compareTo('${b.value['label']}');
          });
    final selected = editableMetadata
        .map((entry) => entry.value['name'].toString())
        .toSet();
    if (selected.isEmpty) return const [];
    final values = await _queryRecordFields(
      objectName: 'Project__c',
      recordId: projectId,
      fieldNames: selected.toList(),
    );
    final editable = <Map<String, dynamic>>[];
    for (final entry in editableMetadata) {
      final metadata = entry.value;
      final apiName = metadata['name'].toString();
      editable.add({
        'key': entry.key,
        'apiName': apiName,
        'label': metadata['label'] ?? apiName,
        'type': metadata['type'],
        'required':
            metadata['nillable'] != true &&
            metadata['defaultedOnCreate'] != true,
        'value': values[apiName],
        'picklistValues':
            (metadata['picklistValues'] as List<dynamic>? ?? const [])
                .where((item) => (item as Map)['active'] == true)
                .map((item) => (item as Map)['value']?.toString())
                .whereType<String>()
                .toList(),
      });
    }
    return editable;
  }

  /// Every readable Project field, including friendly lookup record names.
  static Future<List<Map<String, dynamic>>> getAllProjectDetails(
    String projectId,
  ) async {
    final token = await StorageService.getAccessToken();
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Project__c/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final fields =
        (jsonDecode(response.body)['fields'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .where(
              (field) =>
                  field['deprecatedAndHidden'] != true &&
                  !const {
                    'address',
                    'location',
                    'base64',
                  }.contains(field['type']),
            )
            .toList();
    final values = await _queryRecordFields(
      objectName: 'Project__c',
      recordId: projectId,
      fieldNames: fields.map((field) => field['name'].toString()).toList(),
    );
    final result = <Map<String, dynamic>>[];
    for (final field in fields) {
      final apiName = field['name'].toString();
      dynamic value = values[apiName];
      if (field['type'] == 'reference' && value != null) {
        final targets = (field['referenceTo'] as List<dynamic>? ?? const [])
            .map((item) => item.toString());
        for (final target in targets) {
          try {
            final records = await _queryAllRecords(
              'SELECT Name FROM $target WHERE Id=\'$value\' LIMIT 1',
            );
            if (records.isNotEmpty && records.first['Name'] != null) {
              value = records.first['Name'];
              break;
            }
          } catch (_) {}
        }
      }
      result.add({
        'apiName': apiName,
        'label': field['label'] ?? apiName,
        'type': field['type'],
        'value': value,
        'updateable': field['updateable'] == true,
      });
    }
    result.sort((a, b) => '${a['label']}'.compareTo('${b['label']}'));
    return result;
  }

  /// Loads the important related lists configured beneath Project__c.
  static Future<List<Map<String, dynamic>>> getProjectRelatedLists(
    String projectId,
  ) async {
    final token = await StorageService.getAccessToken();
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Project__c/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final relationships =
        jsonDecode(response.body)['childRelationships'] as List<dynamic>? ??
        const [];
    const wanted = [
      'vendorassignment',
      'paymentterm',
      'projecthistory',
      'case',
      'projectexpensesheet',
      'milestonecompletion',
      'client',
    ];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    final selected = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final raw in relationships) {
      final relationship = raw as Map<String, dynamic>;
      final signature =
          normalize(relationship['relationshipName']) +
          normalize(relationship['childSObject']);
      if (!wanted.any(signature.contains)) continue;
      final objectName = relationship['childSObject']?.toString();
      final lookup = relationship['field']?.toString();
      if (objectName == null ||
          lookup == null ||
          !seen.add('$objectName.$lookup')) {
        continue;
      }
      try {
        selected.add(
          await _loadProjectRelatedList(
            token: token,
            projectId: projectId,
            objectName: objectName,
            lookupField: lookup,
            relationshipName: relationship['relationshipName']?.toString(),
          ),
        );
      } catch (_) {
        // One inaccessible relationship must not hide every related list.
      }
    }
    selected.sort((a, b) => '${a['label']}'.compareTo('${b['label']}'));
    return selected;
  }

  static Future<Map<String, dynamic>> _loadProjectRelatedList({
    required String? token,
    required String projectId,
    required String objectName,
    required String lookupField,
    String? relationshipName,
  }) async {
    if (objectName.endsWith('History')) {
      final records = await _queryAllRecords(
        'SELECT Id,Field,OldValue,NewValue,CreatedDate,CreatedBy.Name '
        "FROM $objectName WHERE $lookupField='$projectId' "
        'ORDER BY CreatedDate DESC LIMIT 50',
      );
      return {
        'label': 'Project History',
        'object': objectName,
        'fields': ['Date', 'Field', 'User', 'Original Value', 'New Value'],
        'records': records
            .map(
              (record) => [
                record['CreatedDate'],
                record['Field'],
                (record['CreatedBy'] as Map?)?['Name'],
                record['OldValue'],
                record['NewValue'],
              ],
            )
            .toList(),
      };
    }
    final describe = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/$objectName/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (describe.statusCode != 200) throw Exception(describe.body);
    final payload = jsonDecode(describe.body) as Map<String, dynamic>;
    final fields = (payload['fields'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where(
          (field) =>
              field['deprecatedAndHidden'] != true &&
              !const {
                'address',
                'location',
                'base64',
              }.contains(field['type']) &&
              field['name'] != lookupField,
        )
        .toList();
    fields.sort((a, b) {
      const priority = {'Name': 0, 'Status': 1, 'CreatedDate': 2};
      return (priority[a['name']] ?? 3).compareTo(priority[b['name']] ?? 3);
    });
    final visible = fields.take(20).toList();
    final names = visible.map((field) => field['name'].toString()).toList();
    final queryFields = names.isEmpty ? ['Id'] : names;
    final records = await _queryAllRecords(
      'SELECT ${queryFields.join(',')} FROM $objectName '
      "WHERE $lookupField='$projectId' ORDER BY CreatedDate DESC LIMIT 50",
    );
    return {
      'label': payload['labelPlural'] ?? relationshipName ?? objectName,
      'object': objectName,
      'fields': visible
          .map((field) => field['label'] ?? field['name'])
          .toList(),
      'records': records
          .map((record) => names.map((name) => record[name]).toList())
          .toList(),
    };
  }

  static Future<Map<String, dynamic>> _queryRecordFields({
    required String objectName,
    required String recordId,
    required List<String> fieldNames,
  }) async {
    final result = <String, dynamic>{};
    for (var start = 0; start < fieldNames.length; start += 80) {
      final end = (start + 80).clamp(0, fieldNames.length);
      final chunk = fieldNames.sublist(start, end);
      final records = await _queryAllRecords(
        'SELECT ${chunk.join(',')} FROM $objectName '
        "WHERE Id='$recordId' LIMIT 1",
      );
      if (records.isEmpty) throw Exception('Record not found.');
      result.addAll(Map<String, dynamic>.from(records.first as Map));
    }
    return result;
  }

  static Future<void> updateProjectDetails({
    required String projectId,
    required Map<String, dynamic> values,
  }) async {
    final editable = await getEditableProjectDetails(projectId);
    final allowed = {
      for (final field in editable)
        field['key'].toString(): field['apiName'].toString(),
    };
    final body = <String, dynamic>{};
    for (final entry in values.entries) {
      final apiName = allowed[entry.key];
      if (apiName != null) body[apiName] = entry.value;
    }
    if (body.isEmpty) throw Exception('No editable Project fields were found.');
    final token = await StorageService.getAccessToken();
    final response = await http.patch(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Project__c/$projectId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 204) throw Exception(response.body);
  }

  /// Starts a project using the same Salesforce record update as the org UI.
  static Future<void> startProject(String projectId) async {
    final token = await StorageService.getAccessToken();
    final fields = await _getProjectFields(token);
    final statusField = fields['status'];
    final startDateField = fields['startDate'];
    if (statusField == null) {
      throw Exception('Project Status field was not found in Salesforce.');
    }

    // Match the Salesforce Start Project action: the first installment must
    // have been received before the project can move to In Progress.
    final paymentTerms = await getProjectPaymentTerms(projectId);
    if (paymentTerms.isEmpty || paymentTerms.first['paid'] != true) {
      throw Exception(
        'The first Payment Term installment must be marked "Payment Received" before starting the project.',
      );
    }
    final response = await http.patch(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Project__c/$projectId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        statusField: 'In Progress',
        if (startDateField != null)
          startDateField: DateTime.now().toIso8601String().split('T').first,
      }),
    );
    if (response.statusCode != 204) {
      throw Exception(response.body);
    }
  }

  /// Loads the Payment Term child records shown on a Project record.
  static Future<List<Map<String, dynamic>>> getProjectPaymentTerms(
    String projectId,
  ) async {
    final token = await StorageService.getAccessToken();
    final metadata = await _getProjectPaymentTermMetadata(token);
    final objectName = metadata['object']!;
    final lookup = metadata['lookup']!;
    final percentage = metadata['percentage'];
    final dueDate = metadata['dueDate'];
    final paid = metadata['paid'];
    final selected = <String>{'Id', 'Name'};
    if (percentage != null) selected.add(percentage);
    if (dueDate != null) selected.add(dueDate);
    if (paid != null) selected.add(paid);
    final records = await _queryAllRecords(
      'SELECT ${selected.join(',')} FROM $objectName '
      "WHERE $lookup='$projectId' ORDER BY CreatedDate ASC",
    );
    return records
        .map(
          (record) => <String, dynamic>{
            'id': record['Id'],
            'term': record['Name'],
            'percentage': percentage == null ? null : record[percentage],
            'dueDate': dueDate == null ? null : record[dueDate],
            'paid': paid != null && record[paid] == true,
          },
        )
        .toList();
  }

  /// Updates editable fields on existing Project Payment Terms. Standard
  /// Salesforce REST DML is used so validation rules, flows and triggers run.
  static Future<void> updateProjectPaymentTermStatuses({
    required String projectId,
    required List<Map<String, dynamic>> terms,
  }) async {
    final token = await StorageService.getAccessToken();
    final metadata = await _getProjectPaymentTermMetadata(token);
    final objectName = metadata['object']!;
    final paidField = metadata['paid'];
    final percentageField = metadata['percentage'];
    final dueDateField = metadata['dueDate'];

    // Resolve the project's records again to prevent an ID from another
    // project being updated by a stale or modified client payload.
    final current = await getProjectPaymentTerms(projectId);
    final allowedIds = current.map((term) => term['id']?.toString()).toSet();
    for (final term in terms) {
      final id = term['id']?.toString();
      if (id == null || !allowedIds.contains(id)) {
        throw Exception('A Payment Term no longer belongs to this project.');
      }
      final response = await http.patch(
        Uri.parse('$instanceUrl/services/data/v64.0/sobjects/$objectName/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'Name': term['term']?.toString().trim(),
          if (percentageField != null) percentageField: term['percentage'],
          if (dueDateField != null) dueDateField: term['dueDate'],
          if (paidField != null) paidField: term['paid'] == true,
        }),
      );
      if (response.statusCode != 204) throw Exception(response.body);
    }
  }

  static Future<Map<String, String>> _getProjectPaymentTermMetadata(
    String? token,
  ) async {
    if (_projectPaymentTermMetadataCache != null) {
      return _projectPaymentTermMetadataCache!;
    }
    final projectDescribe = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Project__c/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (projectDescribe.statusCode != 200) {
      throw Exception(projectDescribe.body);
    }
    final relationships =
        jsonDecode(projectDescribe.body)['childRelationships']
            as List<dynamic>? ??
        const [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    Map<String, dynamic>? relationship;
    for (final raw in relationships) {
      final item = raw as Map<String, dynamic>;
      if (normalize(item['childSObject']).contains('paymentterm') ||
          normalize(item['relationshipName']).contains('paymentterm')) {
        relationship = item;
        break;
      }
    }
    if (relationship == null) {
      throw Exception('Project Payment Terms relationship was not found.');
    }
    final objectName = relationship['childSObject'].toString();
    final describe = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/$objectName/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (describe.statusCode != 200) throw Exception(describe.body);
    final fields =
        jsonDecode(describe.body)['fields'] as List<dynamic>? ?? const [];
    String? find(List<String> candidates, {bool mustBeUpdateable = false}) {
      final targets = candidates.map(normalize).toSet();
      for (final raw in fields) {
        final field = raw as Map<String, dynamic>;
        if (mustBeUpdateable && field['updateable'] != true) continue;
        if (targets.contains(normalize(field['label'])) ||
            targets.contains(normalize(field['name']))) {
          return field['name']?.toString();
        }
      }
      return null;
    }

    final result = <String, String>{
      'object': objectName,
      'lookup': relationship['field'].toString(),
    };
    final percentage = find([
      'Percentage',
      'Percent',
      'Payment Percentage',
    ], mustBeUpdateable: true);
    final dueDate = find([
      'Due Date',
      'Payment Due Date',
    ], mustBeUpdateable: true);
    final paid = find([
      'Paid',
      'Is Paid',
      'Payment Received',
    ], mustBeUpdateable: true);
    if (percentage != null) result['percentage'] = percentage;
    if (dueDate != null) result['dueDate'] = dueDate;
    if (paid != null) result['paid'] = paid;
    _projectPaymentTermMetadataCache = result;
    return result;
  }

  static Future<Map<String, String>> _getProjectFields(
    String? token, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _projectFieldCache != null) {
      return _projectFieldCache!;
    }
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Project__c/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final described =
        jsonDecode(response.body)['fields'] as List<dynamic>? ?? const [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    String? find(List<String> candidates) {
      // Preserve candidate priority. Several Project fields have similar names
      // (for example, approved Additional Budget versus the new Amount
      // Requested); picking the first field in describe order is not safe.
      for (final candidate in candidates) {
        final target = normalize(candidate);
        for (final raw in described) {
          final field = raw as Map<String, dynamic>;
          if (target == normalize(field['label']) ||
              target == normalize(field['name'])) {
            return field['name']?.toString();
          }
        }
      }
      return null;
    }

    final resolved = <String, String>{};
    void add(String key, List<String> labels) {
      final value = find(labels);
      if (value != null) resolved[key] = value;
    }

    add('status', ['Status', 'Project Status']);
    add('code', ['Project Code', 'Code']);
    add('startDate', ['Project Start Date', 'Start Date']);
    add('duration', ['Estimated Project Duration', 'Project Duration']);
    add('endDate', ['Estimated End Date', 'Project End Date']);
    add('completionDate', [
      'Actual Project Completion Date',
      'Actual Completion Date',
    ]);
    add('timelineStatus', ['Project Timeline Status', 'Timeline Status']);
    add('totalVendors', [
      'Total Vendor Assigned',
      'Total Vendors Assigned',
      'Assigned Vendor Count',
      'Vendor Assignment Count',
    ]);
    add('additionalBudget', [
      'Additional Amount Requested',
      'Additional Amount',
      'Additional Budget Requested',
      'Additional Budget',
    ]);
    add('additionalBudgetReason', [
      'Additional Amount Request Reason',
      'Additional Budget Reason',
      'Reason for Additional Budget',
      'Additional Budget Request Reason',
      'Additional Amount Reason',
      'Reason',
    ]);
    add('additionalBudgetHistory', ['Additional Budget History']);
    add('additionalBudgetRejectionReason', [
      'Additional Amount Rejection Reason',
      'Additional Budget Rejection Reason',
    ]);
    add('additionalRequestStatus', [
      'Additional Request Status',
      'Additional Budget Request Status',
      'Additional Budget Approval Status',
      'Additional Budget Submitted for Manager Approval',
    ]);
    add('finalApprovalBudget', [
      'Project Final Approval Budget',
      'Final Approval Budget',
    ]);
    add('companyShare', ['Company Share of the Project', 'Company Share']);
    add('remainingBudget', ['Remaining Project Budget', 'Remaining Budget']);
    add('vendorBudgetAllocation', [
      'Budget allocation for vendors',
      'Budget Allocation for Vendors',
      'Total Vendors Amount',
    ]);
    add('totalApprovedExpenses', ['Total Approved Expenses']);
    add('projectCompletionStatus', [
      'Project Completion Status',
      'Completion Status',
    ]);
    add('supervisorProfitPercentage', ['Supervisor Profit Percentage']);
    add('totalProfit', ['Total Profit']);
    add('totalProfitPercentage', ['Total Profit Percentage']);
    add('finalRemainingBudget', ['Final Remaining Budget']);
    _projectFieldCache = resolved;
    return resolved;
  }

  /// Re-read Salesforce rather than trusting the details page's cached values.
  /// This runs before file upload and again after uploads before submission.
  static Future<void> checkProjectAdditionalBudgetSubmission(
    String projectId,
  ) async {
    final token = await StorageService.getAccessToken();
    final fields = await _getProjectFields(token);
    if (fields['additionalRequestStatus'] == null ||
        fields['additionalBudget'] == null ||
        fields['additionalBudgetReason'] == null) {
      throw Exception(
        'Unable to verify the additional budget request fields in Salesforce.',
      );
    }
    final keys = [
      'additionalRequestStatus',
      'additionalBudget',
      'additionalBudgetReason',
      'additionalBudgetHistory',
      'additionalBudgetRejectionReason',
    ];
    final selected = {
      'Id',
      ...keys.map((key) => fields[key]).whereType<String>(),
    };
    final records = await _queryAllRecords(
      'SELECT ${selected.join(',')} FROM Project__c '
      "WHERE Id='$projectId' LIMIT 1",
    );
    if (records.isEmpty) throw Exception('Project not found.');
    final project = <String, dynamic>{
      for (final key in keys) '_$key': records.first[fields[key]],
    };
    if (AdditionalBudgetPolicy.isPendingRequest(project)) {
      throw Exception(AdditionalBudgetPolicy.pendingMessage);
    }
  }

  static final Set<String> _additionalBudgetSubmissions = {};

  static Future<void> submitProjectAdditionalBudget({
    required String projectId,
    required num amount,
    required String reason,
    required List<File> files,
  }) async {
    if (!_additionalBudgetSubmissions.add(projectId)) {
      throw Exception(
        'An additional budget submission is already in progress.',
      );
    }
    try {
      await _submitProjectAdditionalBudget(
        projectId: projectId,
        amount: amount,
        reason: reason,
        files: files,
      );
    } finally {
      _additionalBudgetSubmissions.remove(projectId);
    }
  }

  /// Submits the same Project field transition used by the Salesforce
  /// Additional Budget quick action. Files are linked before the Project
  /// update so its trigger/handler can include them in downstream processing.
  static Future<void> _submitProjectAdditionalBudget({
    required String projectId,
    required num amount,
    required String reason,
    required List<File> files,
  }) async {
    if (amount <= 0) {
      throw Exception('Additional Budget must be greater than zero.');
    }
    if (reason.trim().isEmpty) throw Exception('Reason is required.');

    final token = await StorageService.getAccessToken();
    var fields = await _getProjectFields(token);
    if (fields['additionalBudget'] == null ||
        fields['additionalBudgetReason'] == null) {
      fields = await _getProjectFields(token, forceRefresh: true);
    }
    final budgetField = fields['additionalBudget'];
    final reasonField = fields['additionalBudgetReason'];
    if (budgetField == null || reasonField == null) {
      throw Exception(
        'Additional Budget or Additional Budget Reason field was not found '
        'on the Salesforce Project object.',
      );
    }

    await checkProjectAdditionalBudgetSubmission(projectId);

    for (final file in files) {
      await _publishProjectAdditionalBudgetFile(
        token: token,
        projectId: projectId,
        file: file,
      );
    }

    final approvalSubmission = await _getProjectAdditionalBudgetSubmission(
      token,
    );
    await checkProjectAdditionalBudgetSubmission(projectId);
    final response = await http.patch(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Project__c/$projectId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        budgetField: amount,
        reasonField: reason.trim(),
        if (approvalSubmission != null)
          approvalSubmission['name'].toString(): approvalSubmission['value'],
      }),
    );
    if (response.statusCode != 204) {
      var message = response.body;
      try {
        final errors = jsonDecode(response.body);
        if (errors is List && errors.isNotEmpty) {
          message = errors.first['message']?.toString() ?? message;
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  static Future<Map<String, dynamic>?> _getProjectAdditionalBudgetSubmission(
    String? token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Project__c/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final fields =
        jsonDecode(response.body)['fields'] as List<dynamic>? ?? const [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    const candidates = [
      'additionalbudgetsubmittedformanagerapproval',
      'submitadditionalbudgetformanagerapproval',
      'additionalbudgetmanagerapproval',
      'additionalbudgetapprovalstatus',
      'additionalbudgetrequeststatus',
      'additionalrequeststatus',
    ];
    for (final candidate in candidates) {
      final raw = fields.cast<Map<String, dynamic>>().where((field) {
        return field['updateable'] == true &&
            (normalize(field['label']) == candidate ||
                normalize(field['name']) == candidate);
      }).firstOrNull;
      if (raw == null) continue;
      final field = raw;
      if (field['type'] == 'boolean') {
        return {'name': field['name'], 'value': true};
      }
      if (field['type'] != 'picklist') continue;
      final values = (field['picklistValues'] as List<dynamic>? ?? const [])
          .where((item) => (item as Map)['active'] == true)
          .map((item) => (item as Map)['value'])
          .toList();
      dynamic matchingValue;
      for (final value in values) {
        final text = normalize(value);
        if (text.contains('manager') &&
            (text.contains('submit') ||
                text.contains('pending') ||
                text.contains('approval'))) {
          matchingValue = value;
          break;
        }
      }
      matchingValue ??= values.where((value) {
        final text = normalize(value);
        return text.contains('submit') ||
            text.contains('pending') ||
            text.contains('request');
      }).firstOrNull;
      if (matchingValue != null) {
        return {'name': field['name'], 'value': matchingValue};
      }
    }
    // Support org-specific labels while still requiring a clearly related
    // Additional Budget approval/status field.
    for (final raw in fields.cast<Map<String, dynamic>>()) {
      if (raw['updateable'] != true) continue;
      final signature = '${normalize(raw['label'])}${normalize(raw['name'])}';
      if (!signature.contains('additional') ||
          !signature.contains('budget') ||
          !(signature.contains('approval') ||
              signature.contains('submit') ||
              signature.contains('status'))) {
        continue;
      }
      if (raw['type'] == 'boolean') {
        return {'name': raw['name'], 'value': true};
      }
      if (raw['type'] != 'picklist') continue;
      final values = (raw['picklistValues'] as List<dynamic>? ?? const [])
          .where((item) => (item as Map)['active'] == true)
          .map((item) => (item as Map)['value'])
          .toList();
      final value = values.where((item) {
        final text = normalize(item);
        return text.contains('submit') ||
            text.contains('pending') ||
            text.contains('request') ||
            (text.contains('manager') && text.contains('approval'));
      }).firstOrNull;
      if (value != null) return {'name': raw['name'], 'value': value};
    }
    return null;
  }

  /// Publishes the document directly to the Project in the ContentVersion
  /// insert. This matches lightning-file-upload and makes the
  /// ContentDocumentLink available before the Project trigger sends email.
  static Future<void> _publishProjectAdditionalBudgetFile({
    required String? token,
    required String projectId,
    required File file,
  }) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final response = await http.post(
      Uri.parse('$instanceUrl/services/data/v64.0/sobjects/ContentVersion'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'Title': fileName,
        'PathOnClient': fileName,
        'VersionData': base64Encode(await file.readAsBytes()),
        'FirstPublishLocationId': projectId,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to upload $fileName: ${response.body}');
    }
    final versionId = jsonDecode(response.body)['id']?.toString();
    if (versionId == null) {
      throw Exception('Salesforce did not return an ID for $fileName.');
    }

    final versions = await _queryAllRecords(
      'SELECT ContentDocumentId FROM ContentVersion '
      "WHERE Id='$versionId' LIMIT 1",
    );
    final documentId = versions.isEmpty
        ? null
        : (versions.first as Map)['ContentDocumentId']?.toString();
    if (documentId == null) {
      throw Exception('Salesforce did not publish $fileName.');
    }
    final links = await _queryAllRecords(
      'SELECT Id FROM ContentDocumentLink '
      "WHERE ContentDocumentId='$documentId' "
      "AND LinkedEntityId='$projectId' LIMIT 1",
    );
    if (links.isEmpty) {
      throw Exception(
        '$fileName was uploaded but was not linked to the Project. The budget '
        'request was not submitted.',
      );
    }
  }

  /// Loads every expense sheet belonging to a project, including its material
  /// rows, other-expense rows and Salesforce Files. Object and field API names
  /// are resolved from describe metadata because they differ between orgs.
  static Future<List<Map<String, dynamic>>> getProjectExpenseSheets(
    String projectId,
  ) async {
    final token = await StorageService.getAccessToken();
    final metadata = await _getExpenseSheetMetadata(token);
    final parent = metadata['parent'] as Map<String, dynamic>;
    final selected = <String>{
      'Id',
      'Name',
      'CreatedDate',
      'LastModifiedDate',
      'CreatedBy.Name',
      if (parent['date'] != null) parent['date'] as String,
      if (parent['total'] != null) parent['total'] as String,
      if (parent['status'] != null) parent['status'] as String,
    };
    final records = await _queryAllRecords(
      'SELECT ${selected.join(',')} FROM ${parent['object']} '
      "WHERE ${parent['lookup']}='$projectId' ORDER BY CreatedDate DESC",
    );
    return Future.wait(
      records.map((raw) async {
        final record = Map<String, dynamic>.from(raw as Map);
        final sheetId = record['Id'].toString();
        final children = await Future.wait([
          _getExpenseLines(sheetId, metadata['materials']),
          _getExpenseLines(sheetId, metadata['others']),
          _getLinkedFiles(sheetId),
        ]);
        return <String, dynamic>{
          'id': sheetId,
          'name': record['Name'],
          'date': parent['date'] == null
              ? record['CreatedDate']
              : record[parent['date']],
          'total': parent['total'] == null ? null : record[parent['total']],
          'status': parent['status'] == null ? null : record[parent['status']],
          'createdBy': (record['CreatedBy'] as Map?)?['Name'],
          'createdDate': record['CreatedDate'],
          'materials': children[0],
          'otherExpenses': children[1],
          'files': children[2],
        };
      }),
    );
  }

  /// Creates an expense sheet through standard Salesforce REST DML. Existing
  /// triggers therefore run exactly as they do for the Salesforce quick action.
  static Future<Map<String, dynamic>> saveProjectExpenseSheet({
    required String projectId,
    required List<Map<String, dynamic>> materials,
    required List<Map<String, dynamic>> otherExpenses,
    required List<File> files,
    required bool submitForApproval,
  }) async {
    final validMaterials = materials.where((row) {
      return (row['item']?.toString().trim().isNotEmpty ?? false) ||
          (row['description']?.toString().trim().isNotEmpty ?? false) ||
          (row['brand']?.toString().trim().isNotEmpty ?? false) ||
          (num.tryParse('${row['quantity']}') ?? 0) != 0 ||
          (num.tryParse('${row['rate']}') ?? 0) != 0;
    }).toList();
    final validOthers = otherExpenses.where((row) {
      return row.values.any(
        (value) => value?.toString().trim().isNotEmpty == true,
      );
    }).toList();
    if (validMaterials.isEmpty && validOthers.isEmpty) {
      throw Exception('Add at least one material or other expense.');
    }
    for (final row in validMaterials) {
      final quantity = num.tryParse('${row['quantity']}') ?? 0;
      final rate = num.tryParse('${row['rate']}') ?? 0;
      if ((row['item']?.toString().trim() ?? '').isEmpty ||
          quantity <= 0 ||
          rate < 0) {
        throw Exception(
          'Every material requires an item name, quantity above zero and a valid rate.',
        );
      }
    }
    for (final row in validOthers) {
      if ((row['description']?.toString().trim() ?? '').isEmpty ||
          (num.tryParse('${row['amount']}') ?? 0) <= 0) {
        throw Exception(
          'Every other expense requires a description and amount above zero.',
        );
      }
    }

    final token = await StorageService.getAccessToken();
    var metadata = await _getExpenseSheetMetadata(token);
    bool hasWritableMaterialItem(Map<String, dynamic> value) {
      final materials = value['materials'];
      return materials is Map &&
          materials['item'] != null &&
          materials['itemCreateable'] == true;
    }

    if ((validMaterials.isNotEmpty && !hasWritableMaterialItem(metadata)) ||
        (validOthers.isNotEmpty && metadata['others'] == null)) {
      metadata = await _getExpenseSheetMetadata(token, forceRefresh: true);
    }
    if (validMaterials.isNotEmpty && !hasWritableMaterialItem(metadata)) {
      throw Exception(
        'The writable Salesforce Item Name field for expense materials could '
        'not be resolved. The expense sheet was not submitted.',
      );
    }
    if (validOthers.isNotEmpty && metadata['others'] == null) {
      throw Exception(
        'The Salesforce other-expense line-item relationship could not be '
        'resolved. The expense sheet was not submitted.',
      );
    }
    final parent = metadata['parent'] as Map<String, dynamic>;
    final total =
        validMaterials.fold<double>(
          0,
          (sum, row) =>
              sum +
              (num.tryParse('${row['quantity']}') ?? 0) *
                  (num.tryParse('${row['rate']}') ?? 0),
        ) +
        validOthers.fold<double>(
          0,
          (sum, row) => sum + (num.tryParse('${row['amount']}') ?? 0),
        );
    final createBody = <String, dynamic>{
      parent['lookup']: projectId,
      if (parent['date'] != null && parent['dateCreateable'] == true)
        parent['date']: DateTime.now().toIso8601String().split('T').first,
      if (parent['total'] != null && parent['totalCreateable'] == true)
        parent['total']: total,
      if (parent['description'] != null &&
          parent['descriptionCreateable'] == true)
        parent['description']: _expenseSheetDescription(
          validMaterials,
          validOthers,
        ),
      if (parent['status'] != null &&
          parent['statusCreateable'] == true &&
          parent['draftValue'] != null)
        parent['status']: parent['draftValue'],
    };
    final create = await http.post(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/${parent['object']}',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(createBody),
    );
    if (create.statusCode != 201) throw Exception(create.body);
    final sheetId = jsonDecode(create.body)['id']?.toString();
    if (sheetId == null) {
      throw Exception('Salesforce did not return the Expense Sheet ID.');
    }

    try {
      for (final row in validMaterials) {
        await _createExpenseLine(token, sheetId, metadata['materials'], row);
      }
      for (final row in validOthers) {
        await _createExpenseLine(token, sheetId, metadata['others'], row);
      }

      // The after-update trigger builds the email and PDF from the child rows.
      // Verify that every row is queryable before changing the parent status;
      // otherwise Salesforce would generate an incomplete report.
      final persistedLines = await Future.wait([
        _getExpenseLines(sheetId, metadata['materials']),
        _getExpenseLines(sheetId, metadata['others']),
      ]);
      if (persistedLines[0].length != validMaterials.length ||
          persistedLines[1].length != validOthers.length) {
        throw Exception(
          'Salesforce did not persist every expense line. Nothing was '
          'submitted; please verify the expense line-item relationship.',
        );
      }
      final hasBlankMaterialItem = persistedLines[0].any(
        (row) => (row['item']?.toString().trim() ?? '').isEmpty,
      );
      if (hasBlankMaterialItem) {
        throw Exception(
          'A material Item Name was not saved in Salesforce. The expense '
          'sheet was not submitted.',
        );
      }
      for (final file in files) {
        await _uploadAndLinkSalesforceFile(
          token: token,
          linkedEntityId: sheetId,
          file: file,
        );
      }

      if (submitForApproval) {
        final status = parent['status'];
        final submitValue = parent['submitValue'];
        if (status == null || submitValue == null) {
          throw Exception(
            'Expense Sheet submission status field or its approval value was '
            'not found in Salesforce.',
          );
        }
        final submit = await http.patch(
          Uri.parse(
            '$instanceUrl/services/data/v64.0/sobjects/${parent['object']}/$sheetId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({status: submitValue}),
        );
        if (submit.statusCode != 204) throw Exception(submit.body);
      }
    } catch (error) {
      // Never leave the empty Draft parent that Salesforce creates before a
      // failed line/file submission. This record was created by this request.
      await http.delete(
        Uri.parse(
          '$instanceUrl/services/data/v64.0/sobjects/${parent['object']}/$sheetId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      rethrow;
    }
    return {'id': sheetId, 'total': total};
  }

  static Future<List<Map<String, dynamic>>> _getExpenseLines(
    String sheetId,
    dynamic rawMetadata,
  ) async {
    if (rawMetadata == null) return const [];
    final metadata = rawMetadata as Map<String, dynamic>;
    final fields = <String>{
      'Id',
      'Name',
      for (final key in [
        'item',
        'description',
        'brand',
        'quantity',
        'rate',
        'amount',
      ])
        if (metadata[key] != null) metadata[key] as String,
      if (metadata['typeField'] != null) metadata['typeField'] as String,
    };
    final typeFilter =
        metadata['typeField'] != null && metadata['typeValue'] != null
        ? " AND ${metadata['typeField']}='${_escapeSoqlLiteral(metadata['typeValue'].toString())}'"
        : '';
    final records = await _queryAllRecords(
      'SELECT ${fields.join(',')} FROM ${metadata['object']} '
      "WHERE ${metadata['lookup']}='$sheetId'$typeFilter ORDER BY CreatedDate ASC",
    );
    return records.map((raw) {
      final row = raw as Map<String, dynamic>;
      dynamic value(String key) => metadata[key] == null
          ? (key == 'item' || key == 'description' ? row['Name'] : null)
          : row[metadata[key]];
      return <String, dynamic>{
        'id': row['Id'],
        'item': value('item'),
        'description': value('description'),
        'brand': value('brand'),
        'quantity': value('quantity'),
        'rate': value('rate'),
        'amount': value('amount'),
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _getLinkedFiles(
    String linkedId,
  ) async {
    try {
      final records = await _queryAllRecords(
        'SELECT ContentDocumentId,ContentDocument.Title,'
        'ContentDocument.FileExtension,ContentDocument.ContentSize '
        "FROM ContentDocumentLink WHERE LinkedEntityId='$linkedId'",
      );
      return records.map((raw) {
        final record = raw as Map<String, dynamic>;
        final document = record['ContentDocument'] as Map? ?? const {};
        return <String, dynamic>{
          'id': record['ContentDocumentId'],
          'name': document['Title'],
          'extension': document['FileExtension'],
          'size': document['ContentSize'],
        };
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _createExpenseLine(
    String? token,
    String sheetId,
    dynamic rawMetadata,
    Map<String, dynamic> row,
  ) async {
    if (rawMetadata == null) {
      throw Exception('Expense Sheet line-item relationship was not found.');
    }
    final metadata = rawMetadata as Map<String, dynamic>;
    final body = <String, dynamic>{metadata['lookup']: sheetId};
    if (metadata['typeField'] != null && metadata['typeValue'] != null) {
      body[metadata['typeField']] = metadata['typeValue'];
    }
    for (final key in [
      'item',
      'description',
      'brand',
      'quantity',
      'rate',
      'amount',
    ]) {
      final field = metadata[key];
      if (field == null ||
          metadata['${key}Createable'] != true ||
          row[key] == null ||
          row[key].toString().isEmpty) {
        continue;
      }
      body[field] = ['quantity', 'rate', 'amount'].contains(key)
          ? num.tryParse(row[key].toString())
          : row[key].toString().trim();
    }
    if (metadata['amount'] != null &&
        metadata['amountCreateable'] == true &&
        body[metadata['amount']] == null &&
        row['quantity'] != null &&
        row['rate'] != null) {
      body[metadata['amount']] =
          (num.tryParse('${row['quantity']}') ?? 0) *
          (num.tryParse('${row['rate']}') ?? 0);
    }
    final response = await http.post(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/${metadata['object']}',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) throw Exception(response.body);
  }

  static String _escapeSoqlLiteral(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

  static String _expenseSheetDescription(
    List<Map<String, dynamic>> materials,
    List<Map<String, dynamic>> otherExpenses,
  ) {
    final lines = <String>[];
    if (materials.isNotEmpty) {
      lines.add('Materials Purchased:');
      for (var index = 0; index < materials.length; index++) {
        final row = materials[index];
        final quantity = num.tryParse('${row['quantity']}') ?? 0;
        final rate = num.tryParse('${row['rate']}') ?? 0;
        final amount = quantity * rate;
        final details = <String>[
          '${index + 1}. ${row['item']?.toString().trim() ?? ''}',
          if (row['description']?.toString().trim().isNotEmpty == true)
            row['description'].toString().trim(),
          if (row['brand']?.toString().trim().isNotEmpty == true)
            'Brand: ${row['brand'].toString().trim()}',
          'Qty: $quantity',
          'Rate: $rate',
          'Amount: $amount',
        ];
        lines.add(details.join(' | '));
      }
    }
    if (otherExpenses.isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add('Other Expenses:');
      for (var index = 0; index < otherExpenses.length; index++) {
        final row = otherExpenses[index];
        lines.add(
          '${index + 1}. ${row['description']?.toString().trim() ?? ''} | '
          'Amount: ${num.tryParse('${row['amount']}') ?? 0}',
        );
      }
    }
    // Salesforce long-text fields support at least 32,768 characters, while
    // some orgs configure Description with a smaller limit. Keep a generous
    // safety margin and preserve the beginning of the itemized summary.
    final value = lines.join('\n');
    return value.length <= 30000 ? value : value.substring(0, 30000);
  }

  static Future<Map<String, dynamic>> _getExpenseSheetMetadata(
    String? token, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _expenseSheetMetadataCache != null) {
      return _expenseSheetMetadataCache!;
    }
    Map<String, dynamic> decode(http.Response response) {
      if (response.statusCode != 200) throw Exception(response.body);
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    final projectDescribe = decode(
      await http.get(
        Uri.parse(
          '$instanceUrl/services/data/v64.0/sobjects/Project__c/describe',
        ),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final projectChildren =
        projectDescribe['childRelationships'] as List<dynamic>? ?? const [];
    Map<String, dynamic>? parentRelationship;
    var bestScore = -1;
    for (final raw in projectChildren) {
      final relationship = raw as Map<String, dynamic>;
      final name = normalize(relationship['childSObject']);
      var score = 0;
      if (name.contains('expense')) score += 3;
      if (name.contains('sheet')) score += 4;
      if (name.contains('project')) score += 1;
      if (name.contains('line') || name.contains('material')) score -= 2;
      if (score > bestScore) {
        bestScore = score;
        parentRelationship = relationship;
      }
    }
    if (parentRelationship == null || bestScore < 4) {
      throw Exception(
        'Project Expense Sheet relationship was not found in Salesforce.',
      );
    }
    final parentObject = parentRelationship['childSObject'].toString();
    final parentDescribe = decode(
      await http.get(
        Uri.parse(
          '$instanceUrl/services/data/v64.0/sobjects/$parentObject/describe',
        ),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final parentFields = parentDescribe['fields'] as List<dynamic>? ?? const [];
    String? findField(List<String> candidates, List<dynamic> fields) {
      final targets = candidates.map(normalize).toSet();
      for (final raw in fields) {
        final field = raw as Map<String, dynamic>;
        if (targets.contains(normalize(field['label'])) ||
            targets.contains(normalize(field['name']))) {
          return field['name']?.toString();
        }
      }
      return null;
    }

    bool isCreateable(String? name, List<dynamic> fields) {
      if (name == null) return false;
      return fields.cast<Map<String, dynamic>>().any(
        (field) => field['name'] == name && field['createable'] == true,
      );
    }

    final date = findField([
      'Expense Date',
      'Sheet Date',
      'Expense Sheet Date',
      'Date',
    ], parentFields);
    final total = findField([
      'Grand Total Payable',
      'Grand Total',
      'Total Expense',
      'Total Amount',
    ], parentFields);
    final description = findField([
      'Description',
      'Expense Description',
      'Expense Sheet Description',
      'Notes',
    ], parentFields);
    final status = findField([
      'Status',
      'Expense Sheet Status',
      'Approval Status',
      'Expense Status',
    ], parentFields);
    dynamic draftValue;
    dynamic submitValue;
    if (status != null) {
      final field = parentFields.cast<Map<String, dynamic>>().firstWhere(
        (item) => item['name'] == status,
      );
      if (field['type'] == 'boolean') {
        draftValue = false;
        submitValue = true;
      } else {
        final values = field['picklistValues'] as List<dynamic>? ?? const [];
        for (final raw in values) {
          final value = raw as Map<String, dynamic>;
          if (value['active'] != true) continue;
          final text = normalize(value['value']);
          if (text.contains('draft')) draftValue = value['value'];
          if ((text.contains('submit') && text.contains('approval')) ||
              text == 'submitted' ||
              text == 'pendingapproval' ||
              text == 'sentformanagerapproval') {
            submitValue = value['value'];
          }
        }
      }
    }

    String? findChildField(
      List<String> candidates,
      List<dynamic> fields, {
      bool createableOnly = false,
    }) {
      bool eligible(Map<String, dynamic> field) =>
          !createableOnly || field['createable'] == true;

      // Respect candidate priority. Salesforce describe order is not stable,
      // and its standard auto-number Name field must not win over Item Name.
      for (final candidate in candidates) {
        final target = normalize(candidate);
        for (final raw in fields) {
          final field = raw as Map<String, dynamic>;
          if (!eligible(field)) continue;
          if (normalize(field['label']) == target ||
              normalize(field['name']) == target) {
            return field['name']?.toString();
          }
        }
      }
      for (final candidate in candidates) {
        final target = normalize(candidate);
        if (target.length <= 3) continue;
        for (final raw in fields) {
          final field = raw as Map<String, dynamic>;
          if (!eligible(field)) continue;
          final label = normalize(field['label']);
          final name = normalize(field['name']);
          if (label.contains(target) || name.contains(target)) {
            return field['name']?.toString();
          }
        }
      }
      return null;
    }

    Future<Map<String, dynamic>?> childMetadata(bool material) async {
      final children =
          parentDescribe['childRelationships'] as List<dynamic>? ?? const [];
      Map<String, dynamic>? best;
      var bestScore = -100;
      for (final raw in children) {
        final relationship = raw as Map<String, dynamic>;
        final object = relationship['childSObject']?.toString() ?? '';
        if (!object.endsWith('__c')) continue;
        final response = await http.get(
          Uri.parse(
            '$instanceUrl/services/data/v64.0/sobjects/$object/describe',
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode != 200) continue;
        final described = jsonDecode(response.body) as Map<String, dynamic>;
        final fields = described['fields'] as List<dynamic>? ?? const [];
        final signature = normalize(
          '${relationship['childSObject']} ${relationship['relationshipName']} '
          '${described['label']} ${described['labelPlural']}',
        );
        var score = 0;
        final item = findChildField(
          [
            'Purchased Item Name',
            'Item Name',
            'Material Name',
            'Product Name',
            'Product',
            'Material',
            'Particular',
            'Item',
          ],
          fields,
          createableOnly: true,
        );
        final description = findChildField([
          'Material Description',
          'Expense Description',
          'Item Description',
          'Details',
          'Description',
        ], fields);
        final brand = findChildField(['Brand Name', 'Brand'], fields);
        final quantity = findChildField([
          'Purchased Quantity',
          'Quantity Purchased',
          'Quantity',
          'Qty',
        ], fields);
        final rate = findChildField([
          'Unit Rate',
          'Material Rate',
          'Unit Price',
          'Unit Cost',
          'Cost Per Unit',
          'Price',
          'Rate',
        ], fields);
        final amount = findChildField([
          'Expense Amount',
          'Line Total',
          'Total Amount',
          'Line Amount',
          'Amount',
        ], fields);
        String? typeField;
        dynamic typeValue;
        var typeMatchScore = 0;
        for (final fieldRaw in fields) {
          final field = fieldRaw as Map<String, dynamic>;
          final fieldName = normalize(field['name']);
          final fieldLabel = normalize(field['label']);
          final fieldSignature = normalize(
            '${field['name']} ${field['label']}',
          );
          final isCategoryField =
              fieldSignature.contains('expensetype') ||
              fieldSignature.contains('linetype') ||
              fieldSignature.contains('itemtype') ||
              fieldSignature.contains('expensecategory') ||
              fieldSignature.contains('linecategory') ||
              fieldSignature.contains('itemcategory') ||
              fieldLabel == 'type' ||
              fieldLabel == 'category' ||
              fieldName == 'typec' ||
              fieldName == 'categoryc';
          if (!isCategoryField) continue;
          final values = field['picklistValues'] as List<dynamic>? ?? const [];
          for (final valueRaw in values) {
            final value = valueRaw as Map<String, dynamic>;
            if (value['active'] != true) continue;
            final normalizedValue = normalize(value['value']);
            final matches = material
                ? normalizedValue.contains('material') ||
                      normalizedValue.contains('purchase')
                : normalizedValue.contains('other') ||
                      normalizedValue.contains('additional') ||
                      normalizedValue.contains('misc');
            if (!matches) continue;
            final matchScore =
                normalizedValue.contains(material ? 'material' : 'other')
                ? 8
                : 6;
            if (matchScore > typeMatchScore) {
              typeMatchScore = matchScore;
              typeField = field['name']?.toString();
              typeValue = value['value'];
            }
          }
        }
        // A relationship returned by the parent's describe is authoritative.
        // Do not discard it merely because Salesforce reports the lookup as
        // non-createable. Lightning quick actions commonly save through Apex
        // (system context), while REST describe reflects the mobile user's
        // field-level security. Keeping it here both supports relationships
        // whose createability metadata is inconsistent and, when FLS really
        // blocks the write, surfaces Salesforce's useful DML error instead of
        // the misleading "relationship was not found" message.
        final lookup = relationship['field']?.toString();
        if (lookup == null || lookup.isEmpty) continue;

        if (material) {
          if (signature.contains('material')) score += 6;
          if (signature.contains('purchase')) score += 3;
          if (signature.contains('expenseitem')) score += 4;
          if (signature.contains('expenseline')) score += 4;
          if (signature.contains('expensedetail')) score += 3;
          if (item != null) score += 3;
          if (quantity != null) score += 5;
          if (rate != null) score += 5;
          if (description != null) score += 1;
        } else {
          if (signature.contains('otherexpense')) score += 10;
          if (signature.contains('additionalexpense')) score += 8;
          if (signature.contains('miscellaneousexpense')) score += 8;
          if (description != null) score += 5;
          if (amount != null) score += 5;
          if (quantity != null || rate != null) score -= 7;
          if (signature.contains('material')) score -= 10;
        }
        score += typeMatchScore;
        if (score <= bestScore) continue;
        bestScore = score;
        best = <String, dynamic>{
          'object': object,
          'lookup': lookup,
          'typeField': typeField,
          'typeValue': typeValue,
          'typeFieldCreateable': isCreateable(typeField, fields),
          'item': item,
          'itemCreateable': isCreateable(item, fields),
          'description': description,
          'descriptionCreateable': isCreateable(description, fields),
          'brand': brand,
          'brandCreateable': isCreateable(brand, fields),
          'quantity': quantity,
          'quantityCreateable': isCreateable(quantity, fields),
          'rate': rate,
          'rateCreateable': isCreateable(rate, fields),
          'amount': amount,
          'amountCreateable': isCreateable(amount, fields),
        };
      }
      // A child relationship with the expected fields is sufficient even when
      // the org uses generic API names rather than "Material"/"Expense".
      final minimumScore = material ? 5 : 5;
      return bestScore >= minimumScore ? best : null;
    }

    final materials = await childMetadata(true);
    final others = await childMetadata(false);
    if (materials != null &&
        others != null &&
        materials['object'] == others['object'] &&
        materials['lookup'] == others['lookup'] &&
        (materials['typeField'] == null ||
            others['typeField'] == null ||
            materials['typeField'] != others['typeField'] ||
            materials['typeValue'] == others['typeValue'])) {
      throw Exception(
        'Salesforce uses one Expense Sheet line-item relationship, but its '
        'Material/Other Expense category field could not be identified.',
      );
    }
    final metadata = <String, dynamic>{
      'parent': <String, dynamic>{
        'object': parentObject,
        'lookup': parentRelationship['field'].toString(),
        'date': date,
        'dateCreateable': isCreateable(date, parentFields),
        'total': total,
        'totalCreateable': isCreateable(total, parentFields),
        'description': description,
        'descriptionCreateable': isCreateable(description, parentFields),
        'status': status,
        'statusCreateable': isCreateable(status, parentFields),
        'draftValue': draftValue,
        'submitValue': submitValue,
      },
      'materials': materials,
      'others': others,
    };
    _expenseSheetMetadataCache = metadata;
    return metadata;
  }

  static final Map<String, Map<String, String>> _notificationFields = {};
  static final Map<String, Map<String, String>> _notificationRelationships = {};
  static final Map<String, Map<String, String>> _notificationTypes = {};

  /// Retrieves changed records and their current stage/status values. Initial
  /// calls establish a silent baseline; subsequent calls use a durable cursor.
  static Future<List<Map<String, dynamic>>> getNotificationChanges(
    String source,
    String? since, {
    bool basicFieldsOnly = false,
  }) async {
    final token = await StorageService.getAccessToken();
    final object = switch (source) {
      'Lead' => 'Lead',
      'Opportunity' => 'Opportunity',
      'Project' => 'Project__c',
      'Proforma Invoice' => 'Proforma_Invoice__c',
      'Vendor Assignment' =>
        (await _getVendorAssignmentMetadata(token))['object'] as String,
      _ => throw ArgumentError.value(source),
    };
    var labels = _notificationFields[object];
    if (basicFieldsOnly) labels = <String, String>{};
    if (labels == null) {
      final response = await http
          .get(
            Uri.parse(
              '$instanceUrl/services/data/v64.0/sobjects/$object/describe',
            ),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200)
        throw Exception('Cannot describe $source');
      final fields = jsonDecode(response.body)['fields'] as List;
      labels = <String, String>{};
      final relationships = <String, String>{};
      final types = <String, String>{};
      for (final raw in fields) {
        final field = raw as Map;
        final label = field['label'].toString();
        if (isNotificationField(field)) {
          final name = field['name'] as String;
          labels[name] = label;
          types[name] = field['type'] as String;
          final targets = field['referenceTo'] as List? ?? [];
          if (field['type'] == 'reference' &&
              field['relationshipName'] != null &&
              targets.isNotEmpty &&
              targets.every(
                (target) => const [
                  'User',
                  'Group',
                  'Contact',
                  'Account',
                  'Lead',
                  'Opportunity',
                ].contains(target),
              )) {
            relationships[name] = field['relationshipName'] as String;
          }
        }
      }
      _notificationFields[object] = labels;
      _notificationRelationships[object] = relationships;
      _notificationTypes[object] = types;
    }
    final relationships = basicFieldsOnly
        ? <String, String>{}
        : _notificationRelationships[object] ?? <String, String>{};
    final selected = {
      'Name',
      ...labels.keys,
      ...relationships.values.map((name) => '$name.Name'),
    }.toList();
    final filter = since == null
        ? ''
        : ' WHERE LastModifiedDate >= ${DateTime.parse(since).toUtc().toIso8601String()}';
    final merged = <String, Map<String, dynamic>>{};
    // Split wide objects so adding business fields cannot exceed URL limits.
    for (var offset = 0; offset < selected.length; offset += 80) {
      final fields = {
        'Id',
        'Name',
        'LastModifiedDate',
        ...selected.skip(offset).take(80),
      };
      var url =
          '$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent('SELECT ${fields.join(',')} FROM $object$filter ORDER BY LastModifiedDate ASC')}';
      final chunk = <String, Map<String, dynamic>>{};
      while (true) {
        final response = await http
            .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          // A rejected optional field must not disable all alerts for an object.
          // Do not mask authentication, network or rate-limit failures.
          if (!basicFieldsOnly && response.statusCode == 400) {
            final details = jsonDecode(response.body);
            if (details is List &&
                details.any(
                  (error) =>
                      error is Map && error['errorCode'] == 'INVALID_FIELD',
                )) {
              return getNotificationChanges(
                source,
                since,
                basicFieldsOnly: true,
              );
            }
          }
          throw Exception('Cannot check $source (${response.statusCode})');
        }
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        for (final raw in payload['records'] as List) {
          final record = Map<String, dynamic>.from(raw as Map)
            ..remove('attributes');
          chunk[record['Id'] as String] = record;
        }
        if (payload['done'] == true) break;
        final next = payload['nextRecordsUrl'] as String?;
        if (next == null || !next.startsWith('/services/data/')) {
          throw StateError('Invalid query page');
        }
        url = '$instanceUrl$next';
      }
      if (offset == 0) {
        merged.addAll(chunk);
      } else {
        // Retry on the next poll rather than mix different record versions.
        if (chunk.length != merged.length ||
            chunk.keys.any(
              (id) =>
                  !merged.containsKey(id) ||
                  merged[id]!['LastModifiedDate'] !=
                      chunk[id]!['LastModifiedDate'],
            )) {
          throw StateError('Records changed during notification query; retry');
        }
        for (final entry in chunk.entries) {
          merged[entry.key]!.addAll(entry.value);
        }
      }
    }
    for (final record in merged.values) {
      record['_labels'] = labels;
      record['_limitedDetails'] = basicFieldsOnly;
      record['_types'] = _notificationTypes[object];
      record['_displayValues'] = {
        for (final entry in relationships.entries)
          entry.key: (record[entry.value] as Map?)?['Name'],
      };
    }
    return merged.values.toList();
  }

  /// Email bodies are deliberately excluded. Salesforce must store incoming
  /// mail and thread links for recipient/reply alerts to be available.
  static Future<List<Map<String, dynamic>>> getNotificationEmails(
    String since,
  ) async {
    final token = await StorageService.getAccessToken();
    final query =
        'SELECT Id,Subject,FromAddress,ToAddress,CcAddress,Incoming,'
        'ReplyToEmailMessageId,RelatedToId,MessageDate,CreatedDate,LastModifiedDate '
        'FROM EmailMessage WHERE LastModifiedDate >= ${DateTime.parse(since).toUtc().toIso8601String()} '
        "AND (Incoming = true OR Status = '3') ORDER BY LastModifiedDate ASC";
    var url =
        '$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}';
    final records = <Map<String, dynamic>>[];
    while (true) {
      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw Exception('Cannot check email');
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      records.addAll(
        (payload['records'] as List).map(
          (raw) => Map<String, dynamic>.from(raw as Map),
        ),
      );
      if (payload['done'] == true) break;
      final next = payload['nextRecordsUrl'] as String?;
      if (next == null || !next.startsWith('/services/data/')) {
        throw StateError('Invalid query page');
      }
      url = '$instanceUrl$next';
    }
    return records;
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final token = await StorageService.getAccessToken();

    final response = await http.get(
      Uri.parse("$instanceUrl/services/oauth2/userinfo"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body);
    }
  }

  static Future<List<dynamic>> getAccounts() async {
    final token = await StorageService.getAccessToken();

    final response = await http.get(
      Uri.parse(
        "$instanceUrl/services/data/v64.0/query?q=SELECT+Id,Name+FROM+Account",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["records"];
    } else {
      throw Exception(response.body);
    }
  }

  /// Fetch all Leads
  /// Fetch all Leads
  static Future<List<dynamic>> getLeads() async {
    final token = await StorageService.getAccessToken();

    final query = '''
SELECT
Id,
Name,
FirstName,
LastName,
Company,
Status,
Phone,
Email,
Owner.Name,
CreatedDate
FROM Lead
ORDER BY CreatedDate DESC
''';

    final url =
        "$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["records"];
    } else {
      throw Exception(response.body);
    }
  }

  /// Fetches every Opportunity page returned by Salesforce.
  static Future<List<dynamic>> getOpportunities() async {
    const query = '''
SELECT
Id,
Name,
StageName,
Amount,
CloseDate,
Probability,
Type,
LeadSource,
Project_Request_Quotation_Type__c,
NextStep,
Account.Name,
Owner.Name,
CreatedDate,
LastModifiedDate
FROM Opportunity
WHERE Project_Request_Quotation_Type__c != null
ORDER BY LastModifiedDate DESC
''';
    return _queryAllRecords(query);
  }

  /// Fetches one Opportunity with all fields displayed by the app.
  static Future<Map<String, dynamic>> getOpportunity(
    String opportunityId,
  ) async {
    final token = await StorageService.getAccessToken();
    final query =
        '''
SELECT
Id,
Name,
StageName,
Amount,
CloseDate,
Probability,
Type,
LeadSource,
Project_Request_Quotation_Type__c,
NextStep,
Description,
ForecastCategoryName,
IsClosed,
IsWon,
Account.Name,
Owner.Name,
CreatedBy.Name,
CreatedDate,
LastModifiedDate
FROM Opportunity
WHERE Id='$opportunityId'
LIMIT 1
''';
    final url =
        "$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final records = jsonDecode(response.body)['records'] as List<dynamic>;
    if (records.isEmpty) throw Exception('Opportunity not found.');
    final opportunity = Map<String, dynamic>.from(records.first as Map);

    // Architect field API names can differ between Salesforce orgs. Resolve
    // them from field labels without allowing a custom-field mismatch to block
    // the complete Opportunity detail screen.
    try {
      final architectFields = await _getArchitectOpportunityFields(token);
      if (architectFields.length == 3) {
        final fieldNames = architectFields.values.join(',');
        final architectQuery =
            'SELECT $fieldNames FROM Opportunity '
            "WHERE Id='$opportunityId' LIMIT 1";
        final architectUrl =
            "$instanceUrl/services/data/v64.0/query?q="
            '${Uri.encodeComponent(architectQuery)}';
        final architectResponse = await http.get(
          Uri.parse(architectUrl),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        );
        if (architectResponse.statusCode == 200) {
          final architectRecords =
              jsonDecode(architectResponse.body)['records'] as List<dynamic>;
          if (architectRecords.isNotEmpty) {
            final values = architectRecords.first as Map<String, dynamic>;
            opportunity['Architect_Name__c'] = values[architectFields['name']];
            opportunity['Architect_Email__c'] =
                values[architectFields['email']];
            opportunity['Architect_Contact_Number__c'] =
                values[architectFields['phone']];
          }
        }
      }
    } catch (_) {
      // The standard Opportunity data is still valid and must remain visible.
    }
    return opportunity;
  }

  /// Returns the same field sections configured on the Salesforce Full/View
  /// record layout. Lookup fields use their display values instead of IDs.
  static Future<List<Map<String, dynamic>>> getRecordDetailSections({
    required String recordId,
    required String objectApiName,
  }) async {
    final token = await StorageService.getAccessToken();
    final uri = Uri.parse(
      '$instanceUrl/services/data/v64.0/ui-api/record-ui/$recordId',
    ).replace(queryParameters: {'layoutTypes': 'Full', 'modes': 'View'});
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) throw Exception(response.body);

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final records = payload['records'] as Map<String, dynamic>? ?? const {};
    final record = records[recordId] as Map<String, dynamic>?;
    final recordFields = record?['fields'] as Map<String, dynamic>? ?? const {};
    final objectInfos =
        payload['objectInfos'] as Map<String, dynamic>? ?? const {};
    final objectInfo = objectInfos[objectApiName] as Map<String, dynamic>?;
    final fieldInfos =
        objectInfo?['fields'] as Map<String, dynamic>? ?? const {};
    final layouts = payload['layouts'] as Map<String, dynamic>? ?? const {};
    final objectLayouts =
        layouts[objectApiName] as Map<String, dynamic>? ?? const {};
    if (objectLayouts.isEmpty) return const [];
    final layout = objectLayouts.values.first as Map<String, dynamic>;
    final full = layout['Full'] as Map<String, dynamic>? ?? layout;
    final view = full['View'] as Map<String, dynamic>? ?? full;
    final rawSections = view['sections'] as List<dynamic>? ?? const [];
    final sections = <Map<String, dynamic>>[];
    final unresolvedReferences = <Map<String, dynamic>>[];
    final salesforceId = RegExp(r'^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$');

    for (final rawSection in rawSections) {
      final section = rawSection as Map<String, dynamic>;
      final title = section['heading']?.toString().trim() ?? '';
      if (title.isEmpty) continue;
      final fields = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final rawRow
          in section['layoutRows'] as List<dynamic>? ?? const []) {
        final row = rawRow as Map<String, dynamic>;
        for (final rawItem
            in row['layoutItems'] as List<dynamic>? ?? const []) {
          final item = rawItem as Map<String, dynamic>;
          for (final rawComponent
              in item['layoutComponents'] as List<dynamic>? ?? const []) {
            final component = rawComponent as Map<String, dynamic>;
            final apiName = component['apiName']?.toString();
            if (apiName == null || apiName.isEmpty || !seen.add(apiName)) {
              continue;
            }
            final rawValue = recordFields[apiName] as Map<String, dynamic>?;
            final info = fieldInfos[apiName] as Map<String, dynamic>?;
            final label = info?['label']?.toString() ?? apiName;
            final normalizedApi = apiName.toLowerCase().replaceAll(
              RegExp(r'[^a-z0-9]'),
              '',
            );
            final normalizedLabel = label.toLowerCase().replaceAll(
              RegExp(r'[^a-z0-9]'),
              '',
            );
            if (normalizedApi == 'id' ||
                normalizedApi.endsWith('id') ||
                normalizedLabel == 'id' ||
                normalizedLabel.endsWith('id')) {
              continue;
            }
            dynamic value = rawValue?['displayValue'] ?? rawValue?['value'];
            if (value is bool) value = value ? 'Yes' : 'No';
            if (value is Map) value = value['displayValue'] ?? value['value'];
            final text = _decodeHtmlEntities(value?.toString().trim() ?? '');
            if (text.isEmpty || text == recordId) continue;
            final dataType = info?['dataType']?.toString() ?? '';
            final output = <String, dynamic>{
              'apiName': apiName,
              'label': label,
              'value': text,
              'dataType': dataType,
            };
            fields.add(output);
            if (dataType.toLowerCase() == 'reference' &&
                salesforceId.hasMatch(text)) {
              final references =
                  info?['referenceToInfos'] as List<dynamic>? ?? const [];
              final reference = references.isEmpty
                  ? null
                  : references.first as Map<String, dynamic>;
              final nameFields =
                  reference?['nameFields'] as List<dynamic>? ?? const ['Name'];
              unresolvedReferences.add({
                'field': output,
                'recordId': text,
                'object': reference?['apiName']?.toString(),
                'nameField': nameFields.isEmpty
                    ? 'Name'
                    : nameFields.first.toString(),
              });
            } else if (salesforceId.hasMatch(text)) {
              output['_hide'] = true;
            }
          }
        }
      }
      if (fields.isNotEmpty) sections.add({'title': title, 'fields': fields});
    }

    await Future.wait(
      unresolvedReferences.map((reference) async {
        final field = reference['field'] as Map<String, dynamic>;
        final targetObject = reference['object']?.toString();
        final targetId = reference['recordId']?.toString();
        final nameField = reference['nameField']?.toString() ?? 'Name';
        if (targetObject == null || targetId == null) {
          field['_hide'] = true;
          return;
        }
        try {
          final lookupUri = Uri.parse(
            '$instanceUrl/services/data/v64.0/ui-api/records/$targetId',
          ).replace(queryParameters: {'fields': '$targetObject.$nameField'});
          final lookupResponse = await http.get(
            lookupUri,
            headers: {'Authorization': 'Bearer $token'},
          );
          if (lookupResponse.statusCode != 200) {
            field['_hide'] = true;
            return;
          }
          final lookup =
              jsonDecode(lookupResponse.body) as Map<String, dynamic>;
          final lookupFields =
              lookup['fields'] as Map<String, dynamic>? ?? const {};
          final nameValue = lookupFields[nameField] as Map<String, dynamic>?;
          final displayName = nameValue?['displayValue'] ?? nameValue?['value'];
          final name = _decodeHtmlEntities(
            displayName?.toString().trim() ?? '',
          );
          if (name.isEmpty || salesforceId.hasMatch(name)) {
            field['_hide'] = true;
          } else {
            field['value'] = name;
          }
        } catch (_) {
          field['_hide'] = true;
        }
      }),
    );
    for (final section in sections) {
      final fields = section['fields'] as List<dynamic>;
      fields.removeWhere((raw) => (raw as Map)['_hide'] == true);
    }
    sections.removeWhere(
      (section) => (section['fields'] as List<dynamic>).isEmpty,
    );
    return sections;
  }

  static String _decodeHtmlEntities(String value) {
    if (!value.contains('&')) return value;
    const named = {
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
      '#39': "'",
      'nbsp': ' ',
    };
    return value.replaceAllMapped(
      RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'),
      (match) {
        final entity = match.group(1)!;
        final replacement = named[entity.toLowerCase()];
        if (replacement != null) return replacement;
        int? codePoint;
        if (entity.startsWith('#x') || entity.startsWith('#X')) {
          codePoint = int.tryParse(entity.substring(2), radix: 16);
        } else if (entity.startsWith('#')) {
          codePoint = int.tryParse(entity.substring(1));
        }
        if (codePoint == null || codePoint < 0 || codePoint > 0x10FFFF) {
          return match.group(0)!;
        }
        return String.fromCharCode(codePoint);
      },
    );
  }

  /// Updates the Opportunity fields used by the Architect Information action.
  /// Salesforce's Opportunity after-update trigger runs automatically for this
  /// REST update and performs the existing architect email automation.
  static Future<void> updateOpportunityArchitectInformation({
    required String opportunityId,
    required String architectName,
    required String architectEmail,
    required String architectContactNumber,
  }) async {
    final token = await StorageService.getAccessToken();
    final fields = await _getArchitectOpportunityFields(token);
    if (fields.length != 3) {
      throw Exception(
        'Architect Name, Architect Email, or Architect Contact Number field '
        'could not be found in Salesforce.',
      );
    }
    final response = await http.patch(
      Uri.parse(
        "$instanceUrl/services/data/v64.0/sobjects/Opportunity/$opportunityId",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        fields['name']!: architectName.trim(),
        fields['email']!: architectEmail.trim(),
        fields['phone']!: architectContactNumber.trim(),
      }),
    );
    if (response.statusCode != 204) {
      throw Exception(response.body);
    }
  }

  static Future<Map<String, String>> _getArchitectOpportunityFields(
    String? token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Opportunity/describe',
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );
    if (response.statusCode != 200) throw Exception(response.body);

    final describedFields =
        jsonDecode(response.body)['fields'] as List<dynamic>? ?? const [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    String? findField(Set<String> acceptedLabels, String semantic) {
      for (final field in describedFields) {
        final data = field as Map<String, dynamic>;
        final label = normalize(data['label']);
        final name = normalize(data['name']);
        if (acceptedLabels.contains(label) || acceptedLabels.contains(name)) {
          return data['name']?.toString();
        }
      }
      for (final field in describedFields) {
        final data = field as Map<String, dynamic>;
        final label = normalize(data['label']);
        if (label.contains('architect') && label.contains(semantic)) {
          return data['name']?.toString();
        }
      }
      return null;
    }

    final name = findField({'architectname', 'architectnamec'}, 'name');
    final email = findField({'architectemail', 'architectemailc'}, 'email');
    final phone = findField({
      'architectcontactnumber',
      'architectcontactnumberc',
      'architectphonenumber',
      'architectphone',
    }, 'contact');
    final resolved = <String, String>{};
    if (name != null) {
      resolved['name'] = name;
    }
    if (email != null) {
      resolved['email'] = email;
    }
    if (phone != null) {
      resolved['phone'] = phone;
    }
    return resolved;
  }

  static Future<List<Map<String, dynamic>>> getArchitectureDesignSubmissions(
    String opportunityId,
  ) async {
    final token = await StorageService.getAccessToken();
    final fields = await _getArchitectureDesignFields(token);
    final opportunityField = fields['opportunity'];
    if (opportunityField == null) {
      throw Exception(
        'Opportunity lookup was not found on Architecture Design.',
      );
    }

    final selected = <String>{
      'Id',
      'Name',
      'CreatedDate',
      'LastModifiedDate',
      ...fields.values,
    }.join(',');
    final query =
        'SELECT $selected FROM Architecture_Design__c '
        "WHERE $opportunityField='$opportunityId' "
        'ORDER BY CreatedDate DESC';
    final records = await _queryAllRecords(query);
    final submissions = records
        .map((record) => Map<String, dynamic>.from(record as Map))
        .toList();
    if (submissions.isEmpty) return submissions;

    final ids = submissions.map((item) => "'${item['Id']}'").join(',');
    final fileQuery =
        '''
SELECT
LinkedEntityId,
ContentDocumentId,
ContentDocument.Title,
ContentDocument.FileType,
ContentDocument.ContentSize,
ContentDocument.CreatedDate
FROM ContentDocumentLink
WHERE LinkedEntityId IN ($ids)
ORDER BY ContentDocument.CreatedDate DESC
''';
    final links = await _queryAllRecords(fileQuery);
    for (final submission in submissions) {
      submission['_status'] = fields['status'] == null
          ? null
          : submission[fields['status']];
      submission['_sentDate'] = fields['sentDate'] == null
          ? null
          : submission[fields['sentDate']];
      submission['_clientComments'] = fields['clientComments'] == null
          ? null
          : submission[fields['clientComments']];
      submission['_managerApproval'] = fields['managerApproval'] == null
          ? null
          : submission[fields['managerApproval']];
      submission['_managerComments'] = fields['managerComments'] == null
          ? null
          : submission[fields['managerComments']];
      submission['_budget'] = fields['budget'] == null
          ? null
          : submission[fields['budget']];
      submission['_files'] = links
          .where((link) => link['LinkedEntityId'] == submission['Id'])
          .map((link) => Map<String, dynamic>.from(link as Map))
          .toList();
    }
    return submissions;
  }

  static Future<void> uploadArchitectureDesign({
    required String opportunityId,
    required num amount,
    required List<File> files,
  }) async {
    if (files.isEmpty) throw Exception('Select at least one design file.');
    if (amount <= 0) throw Exception('Enter a valid architecture amount.');
    final token = await StorageService.getAccessToken();
    final fields = await _getArchitectureDesignFields(token);
    final opportunityField = fields['opportunity'];
    final statusField = fields['status'];
    if (opportunityField == null || statusField == null) {
      throw Exception(
        'Required Opportunity or Status field was not found on Architecture '
        'Design.',
      );
    }

    final createResponse = await http.post(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Architecture_Design__c',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        opportunityField: opportunityId,
        if (fields['budget'] != null) fields['budget']!: amount,
      }),
    );
    if (createResponse.statusCode != 201) {
      throw Exception(createResponse.body);
    }
    final designId = jsonDecode(createResponse.body)['id']?.toString();
    if (designId == null) {
      throw Exception('Salesforce did not return the Architecture Design ID.');
    }

    for (final file in files) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final bytes = await file.readAsBytes();
      final uploadResponse = await http.post(
        Uri.parse('$instanceUrl/services/data/v64.0/sobjects/ContentVersion'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'Title': fileName,
          'PathOnClient': fileName,
          'VersionData': base64Encode(bytes),
        }),
      );
      if (uploadResponse.statusCode != 201) {
        throw Exception('Failed to upload $fileName: ${uploadResponse.body}');
      }
      final contentVersionId = jsonDecode(
        uploadResponse.body,
      )['id']?.toString();
      if (contentVersionId == null) {
        throw Exception('Salesforce did not return an ID for $fileName.');
      }

      final documentQuery =
          'SELECT ContentDocumentId FROM ContentVersion '
          "WHERE Id='$contentVersionId' LIMIT 1";
      final documentResponse = await http.get(
        Uri.parse(
          '$instanceUrl/services/data/v64.0/query?q='
          '${Uri.encodeComponent(documentQuery)}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (documentResponse.statusCode != 200) {
        throw Exception(documentResponse.body);
      }
      final documentRecords =
          jsonDecode(documentResponse.body)['records'] as List<dynamic>? ??
          const [];
      final contentDocumentId = documentRecords.isEmpty
          ? null
          : (documentRecords.first as Map<String, dynamic>)['ContentDocumentId']
                ?.toString();
      if (contentDocumentId == null) {
        throw Exception('Salesforce did not publish $fileName.');
      }

      // The public approval page runs as the Experience Cloud site guest user.
      // An explicit AllUsers link matches the Salesforce quick-action upload
      // and lets the review component access the submitted design files.
      final linkResponse = await http.post(
        Uri.parse(
          '$instanceUrl/services/data/v64.0/sobjects/ContentDocumentLink',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ContentDocumentId': contentDocumentId,
          'LinkedEntityId': designId,
          'ShareType': 'V',
          'Visibility': 'AllUsers',
        }),
      );
      if (linkResponse.statusCode != 201) {
        throw Exception('Failed to publish $fileName: ${linkResponse.body}');
      }
    }

    final updateBody = <String, dynamic>{statusField: 'Sent'};
    final sentDateField = fields['sentDate'];
    if (sentDateField != null) {
      final now = DateTime.now();
      updateBody[sentDateField] =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
    }
    // Match the Salesforce quick-action order. The Opportunity flags must be
    // committed before ArchitectureDesignNotificationHandler processes the
    // transition to Sent, because the handler uses that Opportunity context
    // when generating the client Review & Submit Decision link.
    final updateResponse = await http.post(
      Uri.parse('$instanceUrl/services/data/v64.0/composite'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'allOrNone': true,
        'compositeRequest': [
          {
            'method': 'PATCH',
            'url': '/services/data/v64.0/sobjects/Opportunity/$opportunityId',
            'referenceId': 'opportunityApprovalState',
            'body': {
              'Architecture_Manager_Approval__c': false,
              'Architecture_Client_Approval_Sent__c': true,
            },
          },
          {
            'method': 'PATCH',
            'url':
                '/services/data/v64.0/sobjects/'
                'Architecture_Design__c/$designId',
            'referenceId': 'sendArchitectureDesign',
            'body': updateBody,
          },
        ],
      }),
    );
    if (updateResponse.statusCode != 200) {
      throw Exception(updateResponse.body);
    }
    final compositeResponses =
        jsonDecode(updateResponse.body)['compositeResponse']
            as List<dynamic>? ??
        const [];
    final failed = compositeResponses.where((entry) {
      final statusCode =
          (entry as Map<String, dynamic>)['httpStatusCode'] as int?;
      return statusCode == null || statusCode < 200 || statusCode >= 300;
    }).toList();
    if (failed.isNotEmpty) {
      throw Exception(jsonEncode(failed));
    }
  }

  static Future<Map<String, String>> _getArchitectureDesignFields(
    String? token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/'
        'Architecture_Design__c/describe',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final described =
        jsonDecode(response.body)['fields'] as List<dynamic>? ?? const [];
    String normalized(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    String? byLabel(List<String> labels) {
      final targets = labels.map(normalized).toSet();
      for (final raw in described) {
        final field = raw as Map<String, dynamic>;
        if (targets.contains(normalized(field['label'])) ||
            targets.contains(normalized(field['name']))) {
          return field['name']?.toString();
        }
      }
      return null;
    }

    String? opportunityLookup;
    for (final raw in described) {
      final field = raw as Map<String, dynamic>;
      final references = field['referenceTo'] as List<dynamic>? ?? const [];
      if (references.contains('Opportunity')) {
        opportunityLookup = field['name']?.toString();
        break;
      }
    }
    final resolved = <String, String>{};
    if (opportunityLookup != null) resolved['opportunity'] = opportunityLookup;
    final candidates = <String, List<String>>{
      'status': ['Status', 'Architecture Design Status'],
      'sentDate': ['Sent Date', 'Architecture Design Sent Date'],
      'clientComments': ['Client Comments', 'Customer Comments'],
      'managerApproval': ['Manager Approval', 'Manager Approved'],
      'managerComments': ['Manager Comments', 'Manager Comment'],
      'budget': ['Budget', 'Architecture Budget', 'Design Budget'],
    };
    for (final entry in candidates.entries) {
      final match = byLabel(entry.value);
      if (match != null) resolved[entry.key] = match;
    }
    return resolved;
  }

  static Future<List<Map<String, dynamic>>> getProformaInvoiceSubmissions(
    String opportunityId,
  ) async {
    final token = await StorageService.getAccessToken();
    final fields = await _getProformaInvoiceFields(token);
    final opportunityField = fields['opportunity'];
    if (opportunityField == null) {
      throw Exception('Opportunity lookup was not found on Proforma Invoice.');
    }
    final selected = <String>{
      'Id',
      'Name',
      'CreatedDate',
      'LastModifiedDate',
      ...fields.values.where((field) => field != 'Name'),
    }.join(',');
    final query =
        'SELECT $selected FROM Proforma_Invoice__c '
        "WHERE $opportunityField='$opportunityId' "
        'ORDER BY CreatedDate DESC';
    final records = await _queryAllRecords(query);
    final submissions = records
        .map((record) => Map<String, dynamic>.from(record as Map))
        .toList();
    if (submissions.isEmpty) return submissions;

    final ids = submissions.map((item) => "'${item['Id']}'").join(',');
    final links = await _queryAllRecords('''
SELECT
LinkedEntityId,
ContentDocumentId,
ContentDocument.Title,
ContentDocument.FileType,
ContentDocument.ContentSize,
ContentDocument.CreatedDate
FROM ContentDocumentLink
WHERE LinkedEntityId IN ($ids)
ORDER BY ContentDocument.CreatedDate DESC
''');
    for (final submission in submissions) {
      dynamic fieldValue(String key) {
        final apiName = fields[key];
        return apiName == null ? null : submission[apiName];
      }

      submission['_clientStatus'] = fieldValue('clientStatus');
      submission['_clientComments'] = fieldValue('clientComments');
      submission['_managerApproval'] = fieldValue('managerApproval');
      submission['_managerComments'] = fieldValue('managerComments');
      submission['_sentDate'] = fieldValue('sentDate');
      submission['_files'] = links
          .where((link) => link['LinkedEntityId'] == submission['Id'])
          .map((link) => Map<String, dynamic>.from(link as Map))
          .toList();
    }
    return submissions;
  }

  static Future<void> uploadProformaInvoice({
    required String opportunityId,
    required List<File> files,
  }) async {
    if (files.isEmpty) throw Exception('Select at least one invoice file.');
    final token = await StorageService.getAccessToken();
    final fields = await _getProformaInvoiceFields(token);
    final opportunityField = fields['opportunity'];
    final clientStatusField = fields['clientStatus'];
    if (opportunityField == null || clientStatusField == null) {
      throw Exception(
        'Opportunity lookup or Client Status was not found on Proforma Invoice.',
      );
    }
    final firstFileName = files.first.path.split(Platform.pathSeparator).last;
    final createBody = <String, dynamic>{opportunityField: opportunityId};
    if (fields['writeName'] == 'Name') createBody['Name'] = firstFileName;
    final managerField = fields['managerApproval'];
    if (managerField != null) createBody[managerField] = false;

    final createResponse = await http.post(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Proforma_Invoice__c',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(createBody),
    );
    if (createResponse.statusCode != 201) {
      throw Exception(createResponse.body);
    }
    final invoiceId = jsonDecode(createResponse.body)['id']?.toString();
    if (invoiceId == null) {
      throw Exception('Salesforce did not return the Proforma Invoice ID.');
    }
    for (final file in files) {
      await _uploadAndLinkSalesforceFile(
        token: token,
        linkedEntityId: invoiceId,
        file: file,
      );
    }

    // Match the Salesforce quick action: the record is inserted first, every
    // file is linked, and only then does Client Status transition to Sent. The
    // org's existing after-update automation uses this transition to email the
    // client, while Manager_Approval__c remains false until manager review.
    final sendResponse = await http.patch(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/'
        'Proforma_Invoice__c/$invoiceId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({clientStatusField: 'Sent'}),
    );
    if (sendResponse.statusCode != 204) {
      throw Exception(
        'Invoice files were uploaded, but Salesforce could not send the '
        'invoice: ${sendResponse.body}',
      );
    }
  }

  static Future<void> _uploadAndLinkSalesforceFile({
    required String? token,
    required String linkedEntityId,
    required File file,
  }) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final response = await http.post(
      Uri.parse('$instanceUrl/services/data/v64.0/sobjects/ContentVersion'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'Title': fileName,
        'PathOnClient': fileName,
        'VersionData': base64Encode(await file.readAsBytes()),
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to upload $fileName: ${response.body}');
    }
    final versionId = jsonDecode(response.body)['id']?.toString();
    final records = versionId == null
        ? <dynamic>[]
        : await _queryAllRecords(
            'SELECT ContentDocumentId FROM ContentVersion '
            "WHERE Id='$versionId' LIMIT 1",
          );
    final documentId = records.isEmpty
        ? null
        : (records.first as Map)['ContentDocumentId']?.toString();
    if (documentId == null) throw Exception('Unable to publish $fileName.');
    final linkResponse = await http.post(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/ContentDocumentLink',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'ContentDocumentId': documentId,
        'LinkedEntityId': linkedEntityId,
        'ShareType': 'V',
        'Visibility': 'AllUsers',
      }),
    );
    if (linkResponse.statusCode != 201) {
      throw Exception('Failed to link $fileName: ${linkResponse.body}');
    }
  }

  static Future<Map<String, String>> _getProformaInvoiceFields(
    String? token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Proforma_Invoice__c/describe',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final described =
        jsonDecode(response.body)['fields'] as List<dynamic>? ?? const [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    String? find(List<String> labels) {
      final targets = labels.map(normalize).toSet();
      for (final raw in described) {
        final field = raw as Map<String, dynamic>;
        if (targets.contains(normalize(field['label'])) ||
            targets.contains(normalize(field['name']))) {
          return field['name']?.toString();
        }
      }
      return null;
    }

    final resolved = <String, String>{};
    for (final raw in described) {
      final field = raw as Map<String, dynamic>;
      final references = field['referenceTo'] as List<dynamic>? ?? const [];
      if (references.contains('Opportunity')) {
        resolved['opportunity'] = field['name'].toString();
      }
      if (field['name'] == 'Name' && field['createable'] == true) {
        resolved['writeName'] = 'Name';
      }
    }
    final candidates = <String, List<String>>{
      'clientStatus': ['Client Status', 'Client Approval Status', 'Status'],
      'clientComments': ['Client Comments', 'Customer Comments'],
      'managerApproval': ['Manager Approval', 'Manager Approved'],
      'managerComments': ['Manager Comments', 'Manager Comment'],
      'sentDate': ['Sent Date', 'Invoice Sent Date'],
    };
    for (final entry in candidates.entries) {
      final value = find(entry.value);
      if (value != null) resolved[entry.key] = value;
    }
    return resolved;
  }

  static Future<Map<String, dynamic>> getBudgetReview(
    String opportunityId,
  ) async {
    final token = await StorageService.getAccessToken();
    final opportunityFields = await _getBudgetOpportunityFields(token);
    final queryFields = <String>{'Id', 'Name', ...opportunityFields.values};
    final query =
        'SELECT ${queryFields.join(',')} FROM Opportunity '
        "WHERE Id='$opportunityId' LIMIT 1";
    final records = await _queryAllRecords(query);
    if (records.isEmpty) throw Exception('Opportunity not found.');
    final record = Map<String, dynamic>.from(records.first as Map);
    dynamic value(String key) {
      final field = opportunityFields[key];
      return field == null ? null : record[field];
    }

    final result = <String, dynamic>{
      'opportunityId': opportunityId,
      'opportunityName': record['Name'],
      'customerBudget': value('customerBudget'),
      'supervisorBudget': value('supervisorBudget'),
      'duration': value('duration'),
      'durationOptions': await _getActivePicklistValues(
        token: token,
        objectName: 'Opportunity',
        fieldName: opportunityFields['duration'],
      ),
      'finalBudget': value('finalBudget') ?? value('supervisorBudget'),
      'budgetReviewStatus': value('budgetReviewStatus'),
      'clientApprovalSent': value('clientApprovalSent'),
      'clientApproval': value('clientApproval'),
      'managerApproval': value('managerApproval'),
      '_fieldNames': opportunityFields,
      'architectureDesigns': <Map<String, dynamic>>[],
      'paymentTerms': <Map<String, dynamic>>[],
    };

    try {
      final architectureFields = await _getArchitectureDesignFields(token);
      final lookup = architectureFields['opportunity'];
      final budget = architectureFields['budget'];
      if (lookup != null) {
        final fields = <String>{'Id', 'Name', if (budget != null) budget};
        final designs = await _queryAllRecords(
          'SELECT ${fields.join(',')} FROM Architecture_Design__c '
          "WHERE $lookup='$opportunityId' ORDER BY CreatedDate DESC",
        );
        result['architectureDesigns'] = designs
            .map(
              (item) => {
                'id': item['Id'],
                'name': item['Name'],
                'budget': budget == null ? null : item[budget],
              },
            )
            .toList();
      }
    } catch (_) {}

    try {
      result['paymentTerms'] = await _getOpportunityPaymentTerms(
        token,
        opportunityId,
      );
    } catch (_) {}
    return result;
  }

  static Future<List<String>> _getActivePicklistValues({
    required String? token,
    required String objectName,
    required String? fieldName,
  }) async {
    if (fieldName == null) return const [];
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/$objectName/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final fields =
        jsonDecode(response.body)['fields'] as List<dynamic>? ?? const [];
    final field = fields
        .cast<Map<String, dynamic>>()
        .where((item) => item['name'] == fieldName)
        .firstOrNull;
    if (field == null ||
        !const {'picklist', 'multipicklist'}.contains(field['type'])) {
      return const [];
    }
    return (field['picklistValues'] as List<dynamic>? ?? const [])
        .where((item) => (item as Map)['active'] == true)
        .map((item) => (item as Map)['value']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }

  static Future<Map<String, dynamic>> saveBudgetReview({
    required String opportunityId,
    required String supervisorBudget,
    required String duration,
  }) async {
    final token = await StorageService.getAccessToken();
    final fields = await _getBudgetOpportunityFields(token);
    final budgetField = fields['supervisorBudget'];
    final durationField = fields['duration'];
    if (budgetField == null || durationField == null) {
      throw Exception(
        'Supervisor Estimated Budget or Duration field was not found.',
      );
    }
    final parsedBudget = num.tryParse(
      supervisorBudget.replaceAll(RegExp(r'[^0-9.-]'), ''),
    );
    if (parsedBudget == null || parsedBudget < 0) {
      throw Exception('Enter a valid supervisor budget.');
    }
    final response = await http.patch(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Opportunity/$opportunityId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        budgetField: parsedBudget,
        durationField: duration.trim(),
      }),
    );
    if (response.statusCode != 204) throw Exception(response.body);
    return getBudgetReview(opportunityId);
  }

  static Future<Map<String, dynamic>> sendBudgetReviewForClientApproval(
    String opportunityId,
  ) async {
    final token = await StorageService.getAccessToken();
    final fields = await _getBudgetOpportunityFields(token);
    final statusField = fields['budgetReviewStatus'];
    final approvalSentField = fields['clientApprovalSent'];
    if (statusField == null && approvalSentField == null) {
      throw Exception(
        'Budget Review Status field was not found in Salesforce.',
      );
    }
    final response = await http.patch(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Opportunity/$opportunityId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (statusField != null) statusField: 'Sent for Client Approval',
        if (statusField == null && approvalSentField != null)
          approvalSentField: true,
      }),
    );
    if (response.statusCode != 204) throw Exception(response.body);
    return getBudgetReview(opportunityId);
  }

  static Future<Map<String, String>> _getBudgetOpportunityFields(
    String? token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Opportunity/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final fields = jsonDecode(response.body)['fields'] as List<dynamic>? ?? [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    String? find(List<String> candidates) {
      final targets = candidates.map(normalize).toSet();
      for (final raw in fields) {
        final field = raw as Map<String, dynamic>;
        if (targets.contains(normalize(field['label'])) ||
            targets.contains(normalize(field['name']))) {
          return field['name']?.toString();
        }
      }
      return null;
    }

    final candidates = <String, List<String>>{
      'customerBudget': ['Customer Budget', 'Client Budget'],
      'supervisorBudget': ['Supervisor Estimated Budget', 'Supervisor Budget'],
      'duration': [
        'Project Estimated Completion Months',
        'Estimated Completion Months',
        'Duration',
      ],
      'finalBudget': ['Final Budget', 'Final Estimated Budget'],
      'budgetReviewStatus': ['Budget Review Status'],
      'clientApprovalSent': [
        'Budget Review Client Approval Sent',
        'Budget Client Approval Sent',
      ],
      'clientApproval': [
        'Budget Review Client Approval',
        'Budget Client Approval',
      ],
      'managerApproval': [
        'Budget Review Manager Approval',
        'Budget Manager Approval',
      ],
    };
    final resolved = <String, String>{};
    for (final entry in candidates.entries) {
      final field = find(entry.value);
      if (field != null) resolved[entry.key] = field;
    }
    return resolved;
  }

  static Future<List<Map<String, dynamic>>> _getOpportunityPaymentTerms(
    String? token,
    String opportunityId,
  ) async {
    final metadata = await _getPaymentTermMetadata(token);
    final objectName = metadata['object']!;
    final lookupField = metadata['lookup']!;
    final term = metadata['term'];
    final percentage = metadata['percentage'];
    final amount = metadata['amount'];
    final dueDate = metadata['dueDate'];
    final paid = metadata['paid'];
    final selected = <String>{
      'Id',
      'Name',
      if (term != null) term,
      if (percentage != null) percentage,
      if (amount != null) amount,
      if (dueDate != null) dueDate,
      if (paid != null) paid,
    };
    final records = await _queryAllRecords(
      'SELECT ${selected.join(',')} FROM $objectName '
      "WHERE $lookupField='$opportunityId' ORDER BY CreatedDate ASC",
    );
    return records
        .map(
          (item) => {
            'id': item['Id'],
            'term': term == null ? item['Name'] : item[term],
            'percentage': percentage == null ? null : item[percentage],
            'amount': amount == null ? null : item[amount],
            'dueDate': dueDate == null ? null : item[dueDate],
            'paid': paid == null ? false : item[paid] == true,
          },
        )
        .toList();
  }

  static Future<Map<String, dynamic>> getPaymentTerms(
    String opportunityId,
  ) async {
    final token = await StorageService.getAccessToken();
    final metadata = await _getPaymentTermMetadata(token);
    final terms = await _getOpportunityPaymentTerms(token, opportunityId);
    final submission = await _getPaymentTermSubmissionField(token);
    final managerApprovalField = await _getPaymentTermManagerApprovalField(
      token,
    );
    final clientApprovalField = await _getPaymentTermClientApprovalField(token);
    dynamic approval;
    dynamic managerApproval;
    dynamic clientApproval;
    if (submission != null ||
        managerApprovalField != null ||
        clientApprovalField != null) {
      final selected = <String>{
        if (submission != null) submission['name'].toString(),
        if (managerApprovalField != null) managerApprovalField,
        if (clientApprovalField != null) clientApprovalField,
      };
      final records = await _queryAllRecords(
        'SELECT ${selected.join(',')} FROM Opportunity '
        "WHERE Id='$opportunityId' LIMIT 1",
      );
      if (records.isNotEmpty) {
        if (submission != null) approval = records.first[submission['name']];
        if (managerApprovalField != null) {
          managerApproval = records.first[managerApprovalField];
        }
        if (clientApprovalField != null) {
          clientApproval = records.first[clientApprovalField];
        }
      }
    }
    return {
      'terms': terms,
      'approval': approval,
      'managerApproval': managerApproval,
      'clientApproval': clientApproval,
      'approvalFieldType': submission?['type'],
      '_object': metadata['object'],
    };
  }

  static Future<Map<String, dynamic>> savePaymentTerms({
    required String opportunityId,
    required List<Map<String, dynamic>> terms,
    bool submitForManagerApproval = false,
  }) async {
    if (terms.isEmpty) throw Exception('Add at least one payment installment.');
    final total = terms.fold<double>(
      0,
      (sum, item) => sum + (num.tryParse('${item['percentage']}') ?? 0),
    );
    if ((total - 100).abs() > 0.001) {
      throw Exception('Payment percentages must total exactly 100%.');
    }
    for (final item in terms) {
      if ((item['term']?.toString().trim() ?? '').isEmpty ||
          (item['dueDate']?.toString().trim() ?? '').isEmpty) {
        throw Exception('Every installment requires a name and due date.');
      }
    }

    final token = await StorageService.getAccessToken();
    final metadata = await _getPaymentTermMetadata(token);
    final objectName = metadata['object']!;
    final lookup = metadata['lookup']!;
    final termField = metadata['term'];
    final percentageField = metadata['percentage'];
    final amountField = metadata['amount'];
    final dueDateField = metadata['dueDate'];
    final paidField = metadata['paid'];
    if (termField == null || percentageField == null || dueDateField == null) {
      throw Exception('Required Payment Term fields were not found.');
    }

    num? agreementBudget;
    if (amountField != null) {
      final opportunityFields = await _getBudgetOpportunityFields(token);
      final budgetFields = <String>{
        if (opportunityFields['finalBudget'] != null)
          opportunityFields['finalBudget']!,
        if (opportunityFields['supervisorBudget'] != null)
          opportunityFields['supervisorBudget']!,
      };
      if (budgetFields.isNotEmpty) {
        final budgetRecords = await _queryAllRecords(
          'SELECT ${budgetFields.join(',')} FROM Opportunity '
          "WHERE Id='$opportunityId' LIMIT 1",
        );
        if (budgetRecords.isNotEmpty) {
          final record = budgetRecords.first;
          agreementBudget =
              num.tryParse(
                '${opportunityFields['finalBudget'] == null ? null : record[opportunityFields['finalBudget']]}',
              ) ??
              num.tryParse(
                '${opportunityFields['supervisorBudget'] == null ? null : record[opportunityFields['supervisorBudget']]}',
              );
        }
      }
      if (agreementBudget == null) {
        throw Exception(
          'Final Budget is required before saving Payment Terms.',
        );
      }
    }

    final existing = await _getOpportunityPaymentTerms(token, opportunityId);
    final retainedIds = terms
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .toSet();
    for (final old in existing) {
      final id = old['id']?.toString();
      if (id != null && !retainedIds.contains(id)) {
        final response = await http.delete(
          Uri.parse(
            '$instanceUrl/services/data/v64.0/sobjects/$objectName/$id',
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode != 204) throw Exception(response.body);
      }
    }

    for (final item in terms) {
      final termLabel = item['term'].toString().trim();
      final percentageValue = num.parse(item['percentage'].toString());
      final body = <String, dynamic>{
        lookup: opportunityId,
        termField: termLabel,
        // PaymentTermController performs the same copy before its upsert. The
        // mobile app saves through REST, so it must keep Name in sync itself;
        // client-agreement generation reads Payment_Term__c.Name.
        if (termField != 'Name') 'Name': termLabel,
        percentageField: percentageValue,
        if (amountField != null)
          amountField: agreementBudget! * percentageValue / 100,
        dueDateField: item['dueDate'].toString(),
        if (paidField != null) paidField: item['paid'] == true,
      };
      final id = item['id']?.toString();
      final response = id == null
          ? await http.post(
              Uri.parse(
                '$instanceUrl/services/data/v64.0/sobjects/$objectName',
              ),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
          : await http.patch(
              Uri.parse(
                '$instanceUrl/services/data/v64.0/sobjects/$objectName/$id',
              ),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            );
      if (response.statusCode != (id == null ? 201 : 204)) {
        throw Exception(response.body);
      }
      if (id == null && termField != 'Name') {
        final createdId = jsonDecode(response.body)['id']?.toString();
        if (createdId == null) {
          throw Exception('Salesforce did not return the Payment Term ID.');
        }
        // Run once more after insert so an ID/default assigned during record
        // creation cannot remain in Name. Agreements read this field.
        final labelResponse = await http.patch(
          Uri.parse(
            '$instanceUrl/services/data/v64.0/sobjects/$objectName/$createdId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'Name': termLabel, termField: termLabel}),
        );
        if (labelResponse.statusCode != 204) {
          throw Exception(
            'Payment Term was created but its label could not be synchronized: '
            '${labelResponse.body}',
          );
        }
      }
    }

    if (submitForManagerApproval) {
      final submission = await _getPaymentTermSubmissionField(token);
      if (submission == null) {
        throw Exception(
          'Payment Terms manager-approval field was not found in Salesforce.',
        );
      }
      final dynamic value = submission['submitValue'];
      final response = await http.patch(
        Uri.parse(
          '$instanceUrl/services/data/v64.0/sobjects/Opportunity/$opportunityId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({submission['name']: value}),
      );
      if (response.statusCode != 204) throw Exception(response.body);
    }
    return getPaymentTerms(opportunityId);
  }

  static Future<Map<String, String>> _getPaymentTermMetadata(
    String? token,
  ) async {
    final opportunityDescribe = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Opportunity/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (opportunityDescribe.statusCode != 200) {
      throw Exception(opportunityDescribe.body);
    }
    final relationships =
        jsonDecode(opportunityDescribe.body)['childRelationships']
            as List<dynamic>? ??
        [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    Map<String, dynamic>? relationship;
    for (final raw in relationships) {
      final item = raw as Map<String, dynamic>;
      if (normalize(item['childSObject']).contains('paymentterm')) {
        relationship = item;
        break;
      }
    }
    if (relationship == null) {
      throw Exception('Payment Terms relationship was not found.');
    }
    final objectName = relationship['childSObject'].toString();
    final lookupField = relationship['field'].toString();
    final describe = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/$objectName/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (describe.statusCode != 200) throw Exception(describe.body);
    final describedFields =
        jsonDecode(describe.body)['fields'] as List<dynamic>? ?? [];
    String? find(List<String> labels) {
      // Preserve candidate priority. Term_Label__c must win over similarly
      // named fields such as Term__c, regardless of describe response order.
      for (final label in labels) {
        final target = normalize(label);
        for (final raw in describedFields) {
          final field = raw as Map<String, dynamic>;
          final apiName = normalize(field['name']);
          if (target == normalize(field['label']) ||
              target == apiName ||
              '${target}c' == apiName) {
            return field['name']?.toString();
          }
        }
      }
      return null;
    }

    String? findWritable(List<String> labels) {
      for (final label in labels) {
        final target = normalize(label);
        for (final raw in describedFields) {
          final field = raw as Map<String, dynamic>;
          final apiName = normalize(field['name']);
          final matches =
              target == normalize(field['label']) ||
              target == apiName ||
              '${target}c' == apiName;
          if (matches &&
              (field['createable'] == true || field['updateable'] == true)) {
            return field['name']?.toString();
          }
        }
      }
      return null;
    }

    // In this org the installment label is stored in the standard Name field
    // (for example, "First Installment"), not in a separate Term field.
    // Prefer a dedicated field when present, otherwise use Name so records
    // loaded successfully can also be edited and saved.
    final term =
        find([
          'Term Label',
          'Term',
          'Payment Term',
          'Term Name',
          'Installment Name',
        ]) ??
        'Name';
    final percentage = find(['Percentage', 'Percent', 'Payment Percentage']);
    final amount = findWritable([
      'Amount',
      'Payment Amount',
      'Installment Amount',
    ]);
    final dueDate = find(['Due Date', 'Payment Due Date']);
    final paid = find(['Paid', 'Is Paid', 'Payment Received']);
    return {
      'object': objectName,
      'lookup': lookupField,
      'term': term,
      if (percentage != null) 'percentage': percentage,
      if (amount != null) 'amount': amount,
      if (dueDate != null) 'dueDate': dueDate,
      if (paid != null) 'paid': paid,
    };
  }

  static Future<Map<String, dynamic>?> _getPaymentTermSubmissionField(
    String? token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Opportunity/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final fields = jsonDecode(response.body)['fields'] as List<dynamic>? ?? [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    const preferred = {
      'paymenttermssubmittedformanagerapproval',
      'paymenttermssubmitted',
      'paymenttermsapprovalstatus',
      'paymenttermsstatus',
    };
    for (final raw in fields) {
      final field = raw as Map<String, dynamic>;
      if (!preferred.contains(normalize(field['label'])) &&
          !preferred.contains(normalize(field['name']))) {
        continue;
      }
      final type = field['type']?.toString();
      if (type == 'boolean') {
        return {'name': field['name'], 'type': type, 'submitValue': true};
      }
      if (type == 'picklist') {
        final values = field['picklistValues'] as List<dynamic>? ?? [];
        for (final rawValue in values) {
          final value = rawValue as Map<String, dynamic>;
          final normalized = normalize(value['value']);
          if (value['active'] == true &&
              normalized.contains('manager') &&
              (normalized.contains('submit') ||
                  normalized.contains('pending') ||
                  normalized.contains('approval'))) {
            return {
              'name': field['name'],
              'type': type,
              'submitValue': value['value'],
            };
          }
        }
      }
    }
    return null;
  }

  static Future<String?> _getPaymentTermClientApprovalField(
    String? token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Opportunity/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final fields = jsonDecode(response.body)['fields'] as List<dynamic>? ?? [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    const candidates = {
      'paymenttermsclientapproval',
      'paymenttermclientapproval',
      'paymenttermsclientapprovalstatus',
      'paymenttermsclientstatus',
    };
    for (final raw in fields) {
      final field = raw as Map<String, dynamic>;
      if (candidates.contains(normalize(field['label'])) ||
          candidates.contains(normalize(field['name']))) {
        return field['name']?.toString();
      }
    }
    return null;
  }

  static Future<String?> _getPaymentTermManagerApprovalField(
    String? token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Opportunity/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final fields = jsonDecode(response.body)['fields'] as List<dynamic>? ?? [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    const candidates = {
      'paymenttermsmanagerapproval',
      'paymenttermmanagerapproval',
      'paymenttermsmanagerapprovalstatus',
      'paymenttermsmanagerstatus',
    };
    for (final raw in fields) {
      final field = raw as Map<String, dynamic>;
      if (candidates.contains(normalize(field['label'])) ||
          candidates.contains(normalize(field['name']))) {
        return field['name']?.toString();
      }
    }
    return null;
  }

  /// Resolves the remaining Opportunity workflow stages from Salesforce.
  /// Field labels are used instead of fixed API names so this remains usable
  /// across sandboxes where custom-field API names differ.
  static Future<Map<String, bool>> getOpportunityWorkflowStages(
    String opportunityId,
  ) async {
    final token = await StorageService.getAccessToken();
    final response = await http.get(
      Uri.parse(
        '$instanceUrl/services/data/v64.0/sobjects/Opportunity/describe',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception(response.body);
    final description = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = description['fields'] as List<dynamic>? ?? const [];
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';

    List<String> findFields(List<String> candidates) {
      final targets = candidates.map(normalize).toSet();
      return fields
          .where((raw) {
            final field = raw as Map<String, dynamic>;
            return targets.contains(normalize(field['label'])) ||
                targets.contains(normalize(field['name']));
          })
          .map((raw) => (raw as Map<String, dynamic>)['name'].toString())
          .toList();
    }

    final stageFields = <String, List<String>>{
      'catalogueApproval': findFields([
        'Catalogue Approval',
        'Catalogue Approval Status',
        'Catalogue Client Approval',
        'Catalogue Approved',
      ]),
      'clientAgreement': findFields([
        'Client Agreement Signed',
        'Client Agreement Completed',
        'Client Agreement Status',
      ]),
      'tenderInvitation': findFields([
        'Tender Invitation Sent',
        'Tendor Invitation Sent',
        'Tender Invitation Status',
        'Tendor Invitation Status',
      ]),
      'vendorOpportunity': findFields([
        'Vendor Opportunity',
        'Vendor Opportunity Created',
        'Vendor Opportunity Status',
        'All Vendors Assigned',
      ]),
      'vendorAgreement': findFields([
        'All Vendors Agreement Completed',
        'All Vendor Agreements Completed',
        'Vendor Agreement Completed',
      ]),
      'revisitAppointment': findFields([
        'Re-Visit Schedule Appointment',
        'Revisit Schedule Appointment',
        'Re-Visit Appointment Status',
        'Revisit Appointment Status',
        'Re-Visit Appointment Confirmed',
        'Revisit Appointment Confirmed',
        'Re-Visit Date',
        'Revisit Date',
      ]),
      'siteVisitReport': findFields([
        'Site Visit Report Data',
        'Site Visit Report Submitted',
        'Site Visit Report Status',
        'Site Visit Report Created',
      ]),
      'convertToProject': findFields([
        'Converted To Project',
        'Project Created',
        'Project',
        'Project Status',
      ]),
    };
    final selected = <String>{
      'Id',
      for (final values in stageFields.values) ...values,
    };
    final records = await _queryAllRecords(
      'SELECT ${selected.join(',')} FROM Opportunity '
      "WHERE Id='$opportunityId' LIMIT 1",
    );
    if (records.isEmpty) throw Exception('Opportunity not found.');
    final record = records.first as Map<String, dynamic>;

    bool meaningful(dynamic value, {bool approval = false}) {
      if (value == true) return true;
      if (value == null || value == false) return false;
      final text = normalize(value);
      if (text.isEmpty ||
          text == 'no' ||
          text == 'false' ||
          text == 'new' ||
          text == 'pending' ||
          text == 'notsent' ||
          text == 'notstarted' ||
          text == 'notcreated') {
        return false;
      }
      if (approval) {
        return text.contains('approved') || text.contains('accepted');
      }
      return true;
    }

    bool completed(String key, {bool approval = false}) => stageFields[key]!
        .any((field) => meaningful(record[field], approval: approval));

    bool clientAgreementSigned() =>
        stageFields['clientAgreement']!.any((field) {
          final value = record[field];
          if (value == true) return true;
          final text = normalize(value);
          return text == 'signed' ||
              text == 'clientsigned' ||
              text == 'done' ||
              text == 'completed' ||
              text == 'executed' ||
              text == 'fullyexecuted';
        });

    final result = <String, bool>{
      'catalogueApproval': completed('catalogueApproval', approval: true),
      'clientAgreement': clientAgreementSigned(),
      'tenderInvitation': completed('tenderInvitation'),
      'vendorOpportunity': completed('vendorOpportunity'),
      'vendorAgreement': completed('vendorAgreement'),
      'revisitAppointment': completed('revisitAppointment'),
      'siteVisitReport': completed('siteVisitReport'),
      'convertToProject': completed('convertToProject'),
    };
    if (result['vendorOpportunity'] == true) {
      result['tenderInvitation'] = true;
    }

    // Some stages are represented only by related records. Use discovered
    // child relationships as a fallback when no matching Opportunity field
    // has marked the stage complete.
    final relationships =
        description['childRelationships'] as List<dynamic>? ?? const [];
    final relatedTargets = <String, List<String>>{
      'vendorOpportunity': ['vendoropportunity'],
      'siteVisitReport': ['sitevisitreport'],
      'convertToProject': ['project'],
    };
    for (final entry in relatedTargets.entries) {
      if (result[entry.key] == true) continue;
      for (final raw in relationships) {
        final relationship = raw as Map<String, dynamic>;
        final child = normalize(relationship['childSObject']);
        if (!entry.value.any(child.contains)) continue;
        final objectName = relationship['childSObject']?.toString();
        final lookup = relationship['field']?.toString();
        if (objectName == null || lookup == null) continue;
        try {
          final children = await _queryAllRecords(
            'SELECT Id FROM $objectName '
            "WHERE $lookup='$opportunityId' LIMIT 1",
          );
          if (children.isNotEmpty) {
            result[entry.key] = true;
            // Salesforce completes both stages when Vendor Opportunity
            // records are created.
            if (entry.key == 'vendorOpportunity') {
              result['tenderInvitation'] = true;
            }
          }
        } catch (_) {
          // An inaccessible related list must not block all stage tracking.
        }
        break;
      }
    }

    // A created Project is the authoritative completion signal for Convert
    // To Project, even when the Opportunity page-layout field is blank.
    if (result['convertToProject'] != true) {
      try {
        final projectDescribeResponse = await http.get(
          Uri.parse(
            '$instanceUrl/services/data/v64.0/sobjects/Project__c/describe',
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (projectDescribeResponse.statusCode == 200) {
          final projectFields =
              jsonDecode(projectDescribeResponse.body)['fields']
                  as List<dynamic>? ??
              const [];
          String? opportunityLookup;
          for (final raw in projectFields) {
            final field = raw as Map<String, dynamic>;
            final targets = (field['referenceTo'] as List<dynamic>? ?? const [])
                .map(normalize);
            if (field['type'] == 'reference' &&
                targets.contains('opportunity')) {
              opportunityLookup = field['name']?.toString();
              break;
            }
          }
          if (opportunityLookup != null) {
            final projects = await _queryAllRecords(
              'SELECT Id FROM Project__c '
              "WHERE $opportunityLookup='$opportunityId' LIMIT 1",
            );
            result['convertToProject'] = projects.isNotEmpty;
          }
        }
      } catch (_) {
        // Keep the field/relationship result if this fallback is inaccessible.
      }
    }
    return result;
  }

  static Future<List<dynamic>> _queryAllRecords(String query) async {
    final token = await StorageService.getAccessToken();
    var url =
        "$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}";
    final records = <dynamic>[];

    while (true) {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode != 200) throw Exception(response.body);
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      records.addAll(payload['records'] as List<dynamic>? ?? const []);
      if (payload['done'] == true || payload['nextRecordsUrl'] == null) break;
      url = '$instanceUrl${payload['nextRecordsUrl']}';
    }
    return records;
  }

  /// Fetch Single Lead Details
  /// Fetch Single Lead Details
  static Future<Map<String, dynamic>> getLead(String leadId) async {
    final token = await StorageService.getAccessToken();

    final query =
        '''
SELECT
Id,
Name,
IsConverted,
Company,
Phone,
Email,
Status,
Owner.Name,
Approval_Status__c,
Project_Request_Submitted__c,
Project_Description__c,
Customer_Budget__c,
Site_Location__c,
CreatedDate,

Supervisor_User__c,
Supervisor_User__r.Name,
Supervisor_User_Email__c,
Supervisor_User_Phone__c,

Appointment_Confirmation_Type__c,
Appointment_Sent_date__c,
Appointment_Date__c,
Appointment_Time_Slots__c,
Appointment_Completed__c,
Appointment_Status__c,
Appointment_Rescheduled_Time__c,
Time_Slots__c

FROM Lead
WHERE Id='$leadId'
''';

    final url =
        "$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["records"][0];
    } else {
      throw Exception(response.body);
    }
  }

  /// Updates editable Lead fields in Salesforce.
  static Future<void> updateLead({
    required String leadId,
    required Map<String, dynamic> fields,
  }) async {
    final token = await StorageService.getAccessToken();
    final response = await http.patch(
      Uri.parse("$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(fields),
    );

    if (response.statusCode != 204) {
      var message = response.body;
      try {
        final errors = jsonDecode(response.body);
        if (errors is List && errors.isNotEmpty) {
          message = errors.first['message']?.toString() ?? message;
        }
      } catch (_) {
        // Keep the original Salesforce response when it is not JSON.
      }
      throw Exception(message);
    }
  }

  /// Approve Lead
  static Future<bool> approveLead(String leadId) async {
    final token = await StorageService.getAccessToken();

    final response = await http.patch(
      Uri.parse("$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"Approval_Status__c": "Approved"}),
    );

    return response.statusCode == 204;
  }

  static Future<bool> rejectLead(String leadId) async {
    final token = await StorageService.getAccessToken();
    final response = await http.patch(
      Uri.parse('$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'Approval_Status__c': 'Rejected'}),
    );
    return response.statusCode == 204;
  }

  /// Fetch all Active Supervisors (Users)
  static Future<List<dynamic>> getSupervisors() async {
    final token = await StorageService.getAccessToken();

    final query = '''
SELECT
    Id,
    Name,
    Email,
    Phone,
    IsActive,
    UserRole.Name
FROM User
WHERE IsActive = true
AND UserRoleId != null
ORDER BY Name
''';

    final url =
        "$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["records"];
    } else {
      throw Exception(response.body);
    }
  }

  static Future<bool> assignSupervisor({
    required String leadId,
    required String supervisorId,
  }) async {
    final token = await StorageService.getAccessToken();

    final response = await http.patch(
      Uri.parse("$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"Supervisor_User__c": supervisorId}),
    );

    print(response.statusCode);
    print(response.body);

    return response.statusCode == 204;
  }

  static Future<bool> bookSiteVisit({
    required String leadId,
    required String appointmentType,
    required String appointmentDate,
    required String appointmentSlot,
  }) async {
    final appointmentDay = DateTime.tryParse(appointmentDate);
    final slotTimes = RegExp(
      r'(\d{1,2})\s*(AM|PM)',
      caseSensitive: false,
    ).allMatches(appointmentSlot).toList();
    if (appointmentDay == null || slotTimes.isEmpty) return false;
    final startMatch = slotTimes.first;
    var startHour = int.parse(startMatch.group(1)!);
    final period = startMatch.group(2)!.toUpperCase();
    if (startHour == 12) startHour = 0;
    if (period == 'PM') startHour += 12;
    final slotStart = DateTime(
      appointmentDay.year,
      appointmentDay.month,
      appointmentDay.day,
      startHour,
    );
    if (!slotStart.isAfter(DateTime.now())) return false;
    final token = await StorageService.getAccessToken();
    final appointmentUpdates = <String, dynamic>{
      "Appointment_Confirmation_Type__c": appointmentType,
      "Appointment_Completed__c": false,
      "Appointment_Status__c": "Pending",
      "Appointment_Date__c": appointmentDate,
      "Appointment_Time_Slots__c": appointmentSlot,
      // These are populated later only when the client chooses Reschedule
      // from the appointment email.
      "Appointment_Rescheduled_Time__c": null,
      "Time_Slots__c": null,
    };

    final response = await http.patch(
      Uri.parse("$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(appointmentUpdates),
    );

    print(response.statusCode);
    print(response.body);

    return response.statusCode == 204;
  }

  //Site visit Report

  static Future<Map<String, dynamic>?> getSiteVisitReport(String leadId) async {
    final token = await StorageService.getAccessToken();

    final query =
        '''
SELECT
Id,
Name,
Lead__c,
Supervisor_User__c,
Supervisor_User__r.Name,
Estimated_Completion_Months__c,
Estimated_Budget_Description__c,
Total_Estimated_Cost__c,
Client_Approval__c,
Rooms_Count__c,
Usable_Area_Sq_Ft__c,
Site_Area_Sq_Ft__c,
Site_Visit_Date__c,
Site_Visit_Time_Slot__c,
Site_Visit_Type__c,
Site_Address__c,
Description__c,
Management_Approval__c,
Layout_Blueprint_Uploaded__c,
Wizard_Step__c,
Is_Final_Submitted__c,
Site_Visit_Report_Status__c
FROM Site_Visit_Report__c
WHERE Lead__c='$leadId'
LIMIT 1
''';

    final url =
        "$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}";

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final records = jsonDecode(response.body)["records"];

      if (records.isEmpty) {
        return null;
      }

      return records.first;
    }

    throw Exception(response.body);
  }

  static Future<String?> saveSiteVisitDraft({
    String? reportId,
    required Map<String, dynamic> body,
  }) async {
    final token = await StorageService.getAccessToken();

    late http.Response response;

    if (reportId == null) {
      final createBody = Map<String, dynamic>.from(body);
      final leadId = body['Lead__c']?.toString();
      if (leadId != null && !createBody.containsKey('RecordTypeId')) {
        final recordTypeId = await _siteVisitRecordTypeForLead(leadId);
        if (recordTypeId != null) createBody['RecordTypeId'] = recordTypeId;
      }
      response = await http.post(
        Uri.parse(
          "$instanceUrl/services/data/v64.0/sobjects/Site_Visit_Report__c",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(createBody),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body)["id"];
      }
    } else {
      response = await http.patch(
        Uri.parse(
          "$instanceUrl/services/data/v64.0/sobjects/Site_Visit_Report__c/$reportId",
        ),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );
      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 204) {
        return reportId;
      }
    }

    return null;
  }

  static Future<String?> _siteVisitRecordTypeForLead(String leadId) async {
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    try {
      final leadRecords = await _queryAllRecords(
        'SELECT RecordType.DeveloperName,RecordType.Name FROM Lead '
        "WHERE Id='$leadId' LIMIT 1",
      );
      if (leadRecords.isEmpty) return null;
      final leadType = leadRecords.first['RecordType'] as Map?;
      final leadSignature = normalize(
        leadType?['DeveloperName'] ?? leadType?['Name'],
      );
      if (leadSignature.isEmpty) return null;
      final reportTypes = await _queryAllRecords(
        "SELECT Id,DeveloperName,Name FROM RecordType WHERE "
        "SObjectType='Site_Visit_Report__c' AND IsActive=true",
      );
      for (final type in reportTypes) {
        final signature = normalize(type['DeveloperName'] ?? type['Name']);
        if (signature == leadSignature ||
            (leadSignature.contains('manual') &&
                signature.contains('manual')) ||
            (leadSignature.contains('automatic') &&
                signature.contains('automatic'))) {
          return type['Id']?.toString();
        }
      }
    } catch (_) {
      // If the org has only a master record type, Salesforce applies it.
    }
    return null;
  }

  static Future<bool> finalSubmitSiteVisit({
    required String reportId,
    required String leadId,
  }) async {
    final token = await StorageService.getAccessToken();

    // Update the report submission and the Lead's Site Visit Status together.
    // allOrNone prevents Salesforce from leaving the two records out of sync.
    final response = await http.post(
      Uri.parse('$instanceUrl/services/data/v64.0/composite'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        'allOrNone': true,
        'compositeRequest': [
          {
            'method': 'PATCH',
            'url':
                '/services/data/v64.0/sobjects/Site_Visit_Report__c/$reportId',
            'referenceId': 'submitReport',
            'body': {
              'Is_Final_Submitted__c': true,
              'Wizard_Step__c': 3,
              'Management_Approval__c': false,
              'Negotiate__c': false,
              'Site_Visit_Report_Status__c': 'Approved',
            },
          },
          {
            'method': 'PATCH',
            'url': '/services/data/v64.0/sobjects/Lead/$leadId',
            'referenceId': 'updateLeadStatus',
            'body': {
              'Site_Visit_Status__c': 'Approved',
              'Site_Visit_Manager_Approval__c': false,
            },
          },
        ],
      }),
    );

    if (response.statusCode != 200) return false;
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final results = payload['compositeResponse'] as List<dynamic>? ?? const [];
    return results.length == 2 &&
        results.every((item) => (item as Map)['httpStatusCode'] == 204);
  }

  static Future<bool> uploadBlueprint({
    required String reportId,
    required File file,
  }) async {
    final token = await StorageService.getAccessToken();

    final bytes = await file.readAsBytes();

    final base64Data = base64Encode(bytes);

    final fileName = file.path.split('/').last;

    final response = await http.post(
      Uri.parse("$instanceUrl/services/data/v64.0/sobjects/ContentVersion"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "Title": fileName,
        "PathOnClient": fileName,
        "VersionData": base64Data,
      }),
    );

    if (response.statusCode != 201) {
      print(response.body);
      return false;
    }

    final contentVersionId = jsonDecode(response.body)["id"];

    return await linkBlueprintToReport(reportId, contentVersionId);
  }

  static Future<bool> linkBlueprintToReport(
    String reportId,
    String contentVersionId,
  ) async {
    final token = await StorageService.getAccessToken();

    final query =
        '''
SELECT ContentDocumentId
FROM ContentVersion
WHERE Id='$contentVersionId'
''';

    final url =
        "$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}";

    final res = await http.get(
      Uri.parse(url),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      return false;
    }

    final documentId = jsonDecode(res.body)["records"][0]["ContentDocumentId"];

    final linkResponse = await http.post(
      Uri.parse(
        "$instanceUrl/services/data/v64.0/sobjects/ContentDocumentLink",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "ContentDocumentId": documentId,
        "LinkedEntityId": reportId,
        "ShareType": "V",
        "Visibility": "AllUsers",
      }),
    );

    if (linkResponse.statusCode != 201) {
      print(linkResponse.body);
      return false;
    }

    final update = await http.patch(
      Uri.parse(
        "$instanceUrl/services/data/v64.0/sobjects/Site_Visit_Report__c/$reportId",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "Layout_Blueprint_Uploaded__c": true,
        "Wizard_Step__c": 2,
      }),
    );

    return update.statusCode == 204;
  }

  static Future<bool> hasBlueprint(String reportId) async {
    final token = await StorageService.getAccessToken();

    final query =
        '''
SELECT Id
FROM ContentDocumentLink
WHERE LinkedEntityId='$reportId'
LIMIT 1
''';

    final url =
        "$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}";

    final response = await http.get(
      Uri.parse(url),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) {
      return false;
    }

    final records = jsonDecode(response.body)["records"];

    return records.isNotEmpty;
  }

  static Future<bool> approveSiteVisitReport({
    required String reportId,
    required String leadId,
  }) async {
    final token = await StorageService.getAccessToken();

    // Update Site Visit Report
    final reportResponse = await http.patch(
      Uri.parse(
        "$instanceUrl/services/data/v64.0/sobjects/Site_Visit_Report__c/$reportId",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "Management_Approval__c": true,
        "Negotiate__c": false,
        "Negotation_Reason__c": null,
        "Site_Visit_Report_Status__c": "Approved",
      }),
    );

    if (reportResponse.statusCode != 204) {
      print(reportResponse.body);
      return false;
    }

    // Update Lead
    final leadResponse = await http.patch(
      Uri.parse("$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "Site_Visit_Manager_Approval__c": true,
        "Site_Visit_Status__c": "Approved",
      }),
    );

    print("Report Status: ${reportResponse.statusCode}");
    print("Report Body: ${reportResponse.body}");

    return leadResponse.statusCode == 204;
  }

  static Future<bool> requestSiteVisitChanges({
    required String reportId,
    required String leadId,
    required String reason,
  }) async {
    final token = await StorageService.getAccessToken();

    // Update Site Visit Report
    final reportResponse = await http.patch(
      Uri.parse(
        "$instanceUrl/services/data/v64.0/sobjects/Site_Visit_Report__c/$reportId",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "Management_Approval__c": false,
        "Negotiate__c": true,
        "Negotation_Reason__c": reason,
        "Site_Visit_Report_Status__c": "Negotiable",
      }),
    );

    if (reportResponse.statusCode != 204) {
      print(reportResponse.body);
      return false;
    }

    // Update Lead
    final leadResponse = await http.patch(
      Uri.parse("$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "Site_Visit_Manager_Approval__c": false,
        "Site_Visit_Status__c": "Negotiable",
      }),
    );

    print("Report Status: ${reportResponse.statusCode}");
    print("Report Body: ${reportResponse.body}");

    return leadResponse.statusCode == 204;
  }
}
