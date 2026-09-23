import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../config/notification_config.dart';
import '../models/email_recipients.dart';
import '../models/notification_fields.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'push_backend.dart';

/// Foreground change detection. Remote push delivery needs a server event feed.
class NotificationService extends ChangeNotifier with WidgetsBindingObserver {
  NotificationService({
    Future<List<Map<String, dynamic>>> Function(String, String?)? fetchChanges,
    Future<Map<String, dynamic>> Function()? getUser,
    Future<String?> Function()? getToken,
    Future<List<Map<String, dynamic>>> Function(String)? fetchEmails,
    Future<String?> Function(String)? readState,
    Future<void> Function(String, String)? writeState,
    this.pollInterval = const Duration(seconds: 15),
  }) : _fetchChanges = fetchChanges ?? ApiService.getNotificationChanges,
       _getUser = getUser ?? ApiService.getCurrentUser,
       _fetchEmails = fetchEmails ?? ApiService.getNotificationEmails,
       _getToken = getToken ?? StorageService.getAccessToken,
       _readState = readState ?? StorageService.readNotificationState,
       _writeState = writeState ?? StorageService.writeNotificationState;

  final Future<List<Map<String, dynamic>>> Function(String, String?)
  _fetchChanges;
  final Future<Map<String, dynamic>> Function() _getUser;
  final Future<List<Map<String, dynamic>>> Function(String) _fetchEmails;
  Map<String, String> _emailRecipients = Map.from(
    NotificationConfig.recipients,
  );
  Map<String, String> get emailRecipients => Map.unmodifiable(_emailRecipients);
  String? _emailHistorySince = DateTime.now()
      .toUtc()
      .subtract(const Duration(days: 30))
      .toIso8601String();
  String? emailHistoryMessage;

  Future<void> configureEmailRecipients({
    required String supervisor,
    required String manager,
  }) async {
    if (_busy) {
      throw StateError('Please wait for the current refresh to finish.');
    }
    if (_storageKey == null) await refresh();
    if (_storageKey == null) {
      throw StateError('Sign in and refresh before saving email settings.');
    }
    final next = EmailRecipients.groups(
      supervisor: supervisor,
      manager: manager,
    );
    _emailRecipients = next;
    _snapshots.remove('Email');
    _emailHistorySince = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    await _save();
    notifyListeners();
    await refresh();
  }

  Future<void> loadEmailHistory({bool allHistory = false}) async {
    if (_busy) return;
    if (emailRecipients.isEmpty) {
      throw StateError('Add the Manager or Supervisor email address first.');
    }
    _emailHistorySince = allHistory
        ? '1970-01-01T00:00:00.000Z'
        : DateTime.now()
              .toUtc()
              .subtract(const Duration(days: 30))
              .toIso8601String();
    // Keep global event tombstones so dismissed emails do not reappear.
    _snapshots.remove('Email');
    await _save();
    await refresh();
  }

  final Future<String?> Function() _getToken;
  final Future<String?> Function(String) _readState;
  final Future<void> Function(String, String) _writeState;
  static final instance = NotificationService();
  static const sources = [
    'Lead',
    'Opportunity',
    'Project',
    'Vendor Assignment',
    'Proforma Invoice',
  ];
  final List<Map<String, dynamic>> items = [];
  final Map<String, dynamic> _snapshots = {};
  final Map<String, String> _cursors = {};
  final Map<String, String> errors = {};
  Timer? _timer;
  final Duration pollInterval;
  String? _storageKey;
  bool _started = false;
  bool _busy = false;
  bool soundEnabled = true;
  Future<void> Function(Map<String, dynamic>, bool)? onSystemNotification;
  Future<void> Function(String)? onSystemClear;
  Future<void> Function()? onSystemClearAll;
  Future<void> Function(bool)? onSoundChanged;
  Future<Map<String, dynamic>> Function(String?)? fetchRemote;
  final Set<String> _seenEvents = {};
  final Set<String> _presentedEvents = {};
  final Map<String, Map<String, dynamic>> _confirmedFields = {};
  final List<({Map<String, dynamic> event, bool popup})> _pendingRemote = [];

  void enqueueRemote(Map<String, dynamic> event, {required bool popup}) {
    _pendingRemote.add((event: event, popup: popup));
  }

  /// Call only after Salesforce confirms a write. Does not wait for polling.
  Future<void> recordConfirmedAction({
    required String source,
    required String recordId,
    required String title,
    required String body,
    required Map<String, dynamic> fields,
  }) async {
    final now = DateTime.now().toUtc();
    final event = <String, dynamic>{
      'id': 'action:$source:$recordId:${now.microsecondsSinceEpoch}',
      'source': source,
      'recordId': recordId,
      'title': title,
      'body': body,
      'time': now.toIso8601String(),
      'read': false,
    };
    _confirmedFields.putIfAbsent('$source:$recordId', () => {}).addAll(fields);
    if (_storageKey == null) {
      enqueueRemote(event, popup: true);
      await refresh();
      return;
    }
    if (_insert(event)) {
      await _showAlerts([event]);
      await _save();
    }
  }

  void _drainRemote(List<Map<String, dynamic>> popups) {
    for (final pending in _pendingRemote) {
      final id = pending.event['id'] as String;
      _insert(pending.event);
      if (!pending.popup) {
        _presentedEvents.add(id); // Already displayed by the OS in background.
      } else if (!_presentedEvents.contains(id) &&
          items.any((v) => v['id'] == id)) {
        _presentedEvents.add(id);
        popups.add(pending.event);
      }
    }
    _pendingRemote.clear();
  }

  bool _insert(Map<String, dynamic> event) {
    if (_seenEvents.contains(event['id']) ||
        items.any((v) => v['id'] == event['id'])) {
      return false;
    }
    _seenEvents.add(event['id'] as String);
    items.insert(0, event);
    return true;
  }

  Future<void> _writes = Future.value();
  int get unreadCount => items.where((item) => item['read'] != true).length;
  bool get busy => _busy;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // Arm before network I/O. Startup can precede the first lifecycle callback.
    _updateTimer(WidgetsBinding.instance.lifecycleState);
    await refresh();
  }

  void _updateTimer(AppLifecycleState? state) {
    _timer?.cancel();
    _timer = null;
    if (_started &&
        (state == null ||
            state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive)) {
      _timer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updateTimer(state);
    if (_started && state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    _started = false;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      if (await _getToken() == null) {
        items.clear();
        _snapshots.clear();
        _cursors.clear();
        _storageKey = null;
        _emailRecipients = Map.from(NotificationConfig.recipients);
        _emailHistorySince = DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 30))
            .toIso8601String();
        emailHistoryMessage = null;
        _seenEvents.clear();
        _presentedEvents.clear();
        _pendingRemote.clear();
        _confirmedFields.clear();
        return;
      }
      if (_storageKey == null) {
        final user = await _getUser().timeout(const Duration(seconds: 20));
        final org = user['organization_id'];
        final id = user['user_id'];
        if (org == null || id == null) {
          throw StateError('Missing user identity');
        }
        final key = 'notifications_v1_${org}_$id';
        final saved = await _readState(key);
        if (saved != null) {
          final state = jsonDecode(saved) as Map<String, dynamic>;
          final restoredItems = (state['items'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          final restoredSnapshots = Map<String, dynamic>.from(
            state['snapshots'] as Map,
          );
          final restoredCursors = Map<String, String>.from(
            state['cursors'] as Map,
          );
          items
            ..clear()
            ..addAll(restoredItems);
          _snapshots
            ..clear()
            ..addAll(restoredSnapshots);
          _cursors
            ..clear()
            ..addAll(restoredCursors);
          soundEnabled = state['sound'] != false;
          if (state['emailRecipients'] != null) {
            _emailRecipients = Map<String, String>.from(
              state['emailRecipients'] as Map,
            );
          }
          if (state.containsKey('emailHistorySince')) {
            _emailHistorySince = state['emailHistorySince'] as String?;
          }
          _seenEvents.addAll(
            (state['seenEvents'] as List? ?? []).cast<String>(),
          );
          _seenEvents.addAll(items.map((v) => v['id'] as String));
          _presentedEvents.addAll(
            (state['presentedEvents'] as List? ?? []).cast<String>(),
          );
          for (final entry
              in (state['confirmedFields'] as Map? ?? {}).entries) {
            _confirmedFields.putIfAbsent(
              entry.key as String,
              () => Map<String, dynamic>.from(entry.value as Map),
            );
          }
        }
        _storageKey = key;
      }
      errors.remove('Connection');
      final popups = <Map<String, dynamic>>[];
      _drainRemote(popups);
      await _showAlerts(popups);
      popups.clear();
      var remoteLoaded = false;
      if (fetchRemote != null) {
        try {
          final feed = await fetchRemote!(_cursors['Push']);
          final events = (feed['events'] as List).map((raw) {
            final event = parsePushEvent(Map<String, dynamic>.from(raw as Map));
            if (event == null) throw StateError('Invalid notification event');
            return event;
          }).toList();
          // Consume live foreground events before catch-up so they show once.
          _drainRemote(popups);
          for (final event in events) {
            _insert(event);
          }
          _cursors['Push'] = feed['cursor'] as String;
          remoteLoaded = true;
          errors.remove('Push inbox');
        } catch (_) {
          errors['Push inbox'] =
              'Push inbox sync unavailable. Checking Salesforce directly.';
        }
      }
      // Independent objects must not each add another timeout to alert latency.
      await Future.wait(
        (remoteLoaded ? <String>[] : sources).map((source) async {
          try {
            // Overlap protects against equal timestamps and updates during paging.
            final watermark = DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 2))
                .toIso8601String();
            final batch = await _fetchChanges(
              source,
              _cursors[source],
            ).timeout(const Duration(seconds: 45));
            final previous = Map<String, dynamic>.from(
              _snapshots[source] as Map? ?? {},
            );
            final initialized = _cursors.containsKey(source);
            final sourceAlerts = <Map<String, dynamic>>[];
            for (final record in batch) {
              final id = record['Id'] as String;
              final old = previous[id] as Map?;
              final comparison = old == null
                  ? null
                  : Map<String, dynamic>.from(old);
              final acknowledged = _confirmedFields['$source:$id'];
              var matchedAction = false;
              if (acknowledged != null) {
                for (final field in acknowledged.keys.toList()) {
                  if (record[field] == acknowledged[field]) {
                    comparison?[field] = record[field];
                    acknowledged.remove(field);
                    matchedAction = true;
                  }
                }
                if (acknowledged.isEmpty) {
                  _confirmedFields.remove('$source:$id');
                }
              }
              if (initialized &&
                  !(old == null && matchedAction) &&
                  (old == null ||
                      old['LastModifiedDate'] != record['LastModifiedDate'])) {
                final event = notificationForChange(source, record, comparison);
                // Missing detail is not evidence that the update is irrelevant.
                // Suppress only the change already shown for a confirmed action.
                if ((event['hasDetails'] == true || !matchedAction) &&
                    _insert(event)) {
                  sourceAlerts.add(event);
                }
              }
              previous[id] = record;
            }
            _snapshots[source] = previous;
            _cursors[source] = watermark;
            errors.remove(source);
            if (batch.any((record) => record['_limitedDetails'] == true)) {
              errors[source] =
                  '$source alerts are active, but Salesforce did not allow some change details to be read.';
            }
            // A slow Project or Email query must not hold up a ready Lead alert.
            await _showAlerts(sourceAlerts);
            await _save();
          } catch (_) {
            errors[source] =
                'Unable to check $source updates. Check connection and Salesforce access, then retry.';
          }
        }),
      );
      if (emailRecipients.isNotEmpty) {
        try {
          final watermark = DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 2))
              .toIso8601String();
          final history = _emailHistorySince != null;
          final since = _emailHistorySince ?? _cursors['Email'];
          var matchingEmails = 0;
          if (since != null) {
            final emails = await _fetchEmails(
              since,
            ).timeout(const Duration(seconds: 45));
            final seen = Map<String, dynamic>.from(
              _snapshots['Email'] as Map? ?? {},
            );
            for (final email in emails) {
              final id = email['Id'] as String;
              if (seen.containsKey(id)) continue;
              final event = notificationForEmail(email, emailRecipients);
              if (event != null) {
                matchingEmails++;
                final relatedId = email['RelatedToId'];
                for (final source in sources) {
                  final related =
                      (_snapshots[source] as Map?)?[relatedId] as Map?;
                  if (related != null) {
                    event['body'] =
                        '${event['body']}\nRelated $source: ${related['Name']}';
                    break;
                  }
                }
                if (_insert(event) && !history) popups.add(event);
                seen[id] = true;
              }
            }
            _snapshots['Email'] = seen;
          }
          if (history) {
            _emailHistorySince = null;
            emailHistoryMessage = matchingEmails == 0
                ? 'No matching emails were found in Salesforce for this period. Automated emails must be logged there to appear here.'
                : '$matchingEmails matching emails found. The inbox keeps the latest 500 updates; previously cleared emails stay cleared.';
          }
          _cursors['Email'] = since == null
              ? DateTime.now().toUtc().toIso8601String()
              : (DateTime.parse(watermark).isBefore(DateTime.parse(since))
                    ? since
                    : watermark);
          errors.remove('Email');
        } catch (_) {
          errors['Email'] =
              'Unable to check emails. Verify Salesforce email logging and access.';
        }
      }
      _drainRemote(popups);
      items.sort(
        (a, b) => (b['time'] as String).compareTo(a['time'] as String),
      );
      if (items.length > 500) items.removeRange(500, items.length);
      _presentedEvents.addAll(popups.map((event) => event['id'] as String));
      await _save();
      await _showAlerts(popups);
    } catch (_) {
      errors['Connection'] =
          'Unable to load notifications. Check connection and sign in again if needed.';
    } finally {
      _busy = false;
      notifyListeners();
      if (_pendingRemote.isNotEmpty && _storageKey != null) {
        scheduleMicrotask(refresh);
      }
    }
  }

  Future<void> _showAlerts(List<Map<String, dynamic>> popups) async {
    _presentedEvents.addAll(popups.map((event) => event['id'] as String));
    notifyListeners();
    if (onSystemNotification != null) {
      for (final event in popups) {
        try {
          await onSystemNotification!(event, soundEnabled);
        } catch (_) {
          errors['Popups'] =
              'System notification could not be displayed. Check notification permissions.';
        }
      }
    } else if (popups.isNotEmpty &&
        soundEnabled &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      try {
        await const MethodChannel(
          'arelia/notification_sound',
        ).invokeMethod<void>('play');
      } on MissingPluginException {
        await SystemSound.play(SystemSoundType.alert);
      } on PlatformException {
        // Sound failure must not discard a received notification.
      }
    }
  }

  Future<void> markRead() async {
    for (final item in items) {
      item['read'] = true;
    }
    notifyListeners();
    await _save();
  }

  Future<void> clear(String id) async {
    items.removeWhere((item) => item['id'] == id);
    notifyListeners();
    await _save();
    await onSystemClear?.call(id);
  }

  Future<void> clearAll() async {
    items.clear();
    notifyListeners();
    await _save();
    await onSystemClearAll?.call();
  }

  Future<void> setSound(bool value) async {
    soundEnabled = value;
    notifyListeners();
    await _save();
    await onSoundChanged?.call(value);
  }

  Future<void> _save() {
    final key = _storageKey;
    if (key == null) return Future.value();
    final data = jsonEncode({
      'items': items,
      'snapshots': _snapshots,
      'cursors': _cursors,
      'sound': soundEnabled,
      'emailRecipients': _emailRecipients,
      'emailHistorySince': _emailHistorySince,
      'seenEvents': _seenEvents.toList(),
      'presentedEvents': _presentedEvents.toList(),
      'confirmedFields': _confirmedFields,
    });
    _writes = _writes
        .then((_) async {
          await _writeState(key, data);
          errors.remove('Storage');
        })
        .catchError((Object _) {
          errors['Storage'] =
              'Notifications could not be saved on this device.';
          notifyListeners();
        });
    return _writes;
  }
}

@visibleForTesting
Map<String, dynamic> notificationForChange(
  String source,
  Map<String, dynamic> record,
  Map? old,
) {
  final labels = Map<String, dynamic>.from(record['_labels'] as Map? ?? {});
  final changes = <String>[];
  final types = record['_types'] as Map? ?? {};
  final display = record['_displayValues'] as Map? ?? {};
  if (old == null) {
    // A record first seen after the baseline has no previous values to compare.
    for (final entry in labels.entries) {
      final value = record[entry.key];
      if (value == null || value == false || value == '') continue;
      final shown = types[entry.key] == 'reference'
          ? display[entry.key] ?? 'Linked'
          : notificationValue(value, types[entry.key] as String?);
      changes.add('Current ${entry.value}: $shown');
    }
  }
  if (old != null) {
    for (final entry in labels.entries) {
      // Newly tracked fields need a baseline, not a fabricated transition.
      if (old.containsKey(entry.key) && old[entry.key] != record[entry.key]) {
        final value = record[entry.key];
        final label = entry.value.toString();
        if (types[entry.key] == 'reference') {
          final role = label.replaceAll(
            RegExp(r'\s+User$', caseSensitive: false),
            '',
          );
          final person = display[entry.key];
          final assignment = RegExp(
            r'supervisor|manager|owner|assign|vendor',
            caseSensitive: false,
          ).hasMatch(label);
          changes.add(
            value == null
                ? '$role ${assignment ? 'assignment removed' : 'link removed'}'
                : '$role ${assignment ? (old[entry.key] == null ? 'assigned' : 'reassigned') : (old[entry.key] == null ? 'linked' : 'changed')}${person == null ? '' : ': $person'}',
          );
          continue;
        }
        if (source == 'Proforma Invoice' &&
            label.toLowerCase().contains('client') &&
            label.toLowerCase().contains('status') &&
            value == 'Sent') {
          changes.add('Proforma Invoice marked as sent to Client');
          continue;
        }
        changes.add(
          '${entry.value}: ${notificationValue(value, types[entry.key] as String?)}',
        );
      }
    }
  }
  final name = record['Name'] ?? record['Id'];
  return {
    'id': '$source:${record['Id']}:${record['LastModifiedDate']}',
    'title': '$source updated · $name',
    'body': changes.isEmpty
        ? (old == null
              ? '$source added to tracking. Open the record to see its current details.'
              : 'Other $source details changed. Open the record to review them.')
        : changes.join('\n'),
    'hasDetails': changes.isNotEmpty,
    'time': record['LastModifiedDate'],
    'read': false,
    'source': source,
    'recordId': record['Id'],
  };
}

@visibleForTesting
Map<String, dynamic>? notificationForEmail(
  Map<String, dynamic> email,
  Map<String, String> recipients,
) {
  final addresses = '${email['ToAddress'] ?? ''};${email['CcAddress'] ?? ''}'
      .split(RegExp(r'[;,]'))
      .map((part) {
        final match = RegExp(r'<([^>]+)>').firstMatch(part);
        return (match?.group(1) ?? part).trim().toLowerCase();
      })
      .toSet();
  final roles = recipients.entries
      .where((entry) => addresses.contains(entry.key.toLowerCase()))
      .expand((entry) => entry.value.split(' and '))
      .toSet();
  if (roles.isEmpty) return null;
  final reply = email['ReplyToEmailMessageId'] != null;
  return {
    'id': 'Email:${email['Id']}',
    'title':
        '${reply ? 'Reply email' : 'Email'} ${email['Incoming'] == false ? 'sent to' : 'for'} ${roles.join(' and ')}',
    'body':
        '${email['Subject'] ?? '(No subject)'}\n'
        'From ${email['FromAddress'] ?? 'unknown sender'}'
        '${email['ToAddress'] == null ? '' : '\nTo: ${email['ToAddress']}'}'
        '${email['CcAddress'] == null || email['CcAddress'].toString().isEmpty ? '' : '\nCc: ${email['CcAddress']}'}'
        '\nPlease check your email inbox.',
    'time': email['MessageDate'] ?? email['CreatedDate'],
    'read': false,
    'source': 'Email',
    'recordId': email['RelatedToId'],
  };
}
