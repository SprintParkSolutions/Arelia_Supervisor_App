import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'storage_service.dart';

/// Contract for the Salesforce recipient-scoped notification outbox.
/// Deploy the endpoints documented in docs/push-notifications.md before enabling.
class PushBackend {
  static const enabled = bool.fromEnvironment('PUSH_ENABLED');
  // Native Firebase configurations are installed for Android and iOS.
  // Receiving pushes is independent of the not-yet-deployed Salesforce backend.
  static const firebaseEnabled = bool.fromEnvironment(
    'FIREBASE_ENABLED',
    defaultValue: true,
  );
  static const testMode =
      kDebugMode &&
      firebaseEnabled &&
      bool.fromEnvironment('PUSH_TEST_MODE', defaultValue: true);
  static const path = '/services/apexrest/arelia-notifications/v1';

  static Future<Map<String, String>> _headers() async {
    final token = await StorageService.getAccessToken();
    if (token == null) throw StateError('Sign in to enable push notifications');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Future<void> register(
    String token,
    String platform,
    bool sound,
  ) async {
    final response = await http
        .put(
          Uri.parse('${ApiService.instanceUrl}$path/devices'),
          headers: await _headers(),
          body: jsonEncode({
            'token': token,
            'platform': platform,
            'sound': sound,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Push registration unavailable');
    }
  }

  static Future<void> unregister(String token) async {
    final response = await http
        .delete(
          Uri.parse('${ApiService.instanceUrl}$path/devices'),
          headers: await _headers(),
          body: jsonEncode({'token': token}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Push deregistration unavailable');
    }
  }

  static Future<Map<String, dynamic>> events(String? cursor) async {
    final events = <dynamic>[];
    var next = cursor;
    for (var page = 0; page < 100; page++) {
      final uri = Uri.parse(
        '${ApiService.instanceUrl}$path/events',
      ).replace(queryParameters: next == null ? {} : {'cursor': next});
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Push inbox unavailable');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      events.addAll(data['events'] as List);
      final cursor = data['cursor'] as String;
      if (data['hasMore'] != true) return {'events': events, 'cursor': cursor};
      if (cursor == next) throw StateError('Push cursor did not advance');
      next = cursor;
    }
    throw StateError('Too many notification pages');
  }
}

/// Stable across launches, unlike Object.hashCode. Also used by the sender.
int systemNotificationId(String eventId) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(eventId)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

Map<String, dynamic>? parsePushEvent(Map<String, dynamic> data) {
  for (final key in ['id', 'title', 'body', 'time', 'source']) {
    if (data[key] is! String || (data[key] as String).trim().isEmpty) {
      return null;
    }
  }
  if ((data['id'] as String).length > 512 ||
      DateTime.tryParse(data['time']) == null) {
    return null;
  }
  return {
    'id': data['id'],
    'title': data['title'],
    'body': data['body'],
    'time': DateTime.parse(data['time']).toUtc().toIso8601String(),
    'source': data['source'],
    'recordId': data['recordId'],
    'read': false,
  };
}
