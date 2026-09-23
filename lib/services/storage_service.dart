import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static Future<void> Function()? beforeLogout;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: 'refresh_token', value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  static Future<bool> isProjectBudgetReviewed(String projectId) async =>
      await _storage.read(key: 'budget_reviewed_$projectId') == 'true';

  static Future<void> markProjectBudgetReviewed(String projectId) async {
    await _storage.write(key: 'budget_reviewed_$projectId', value: 'true');
  }

  static Future<void> saveVendorTaskDraft(
    String assignmentId,
    Map<String, dynamic> draft,
  ) async {
    await _storage.write(
      key: 'vendor_task_draft_$assignmentId',
      value: jsonEncode(draft),
    );
  }

  static Future<Map<String, dynamic>?> getVendorTaskDraft(
    String assignmentId,
  ) async {
    final value = await _storage.read(key: 'vendor_task_draft_$assignmentId');
    if (value == null) return null;
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  static Future<void> deleteVendorTaskDraft(String assignmentId) async {
    await _storage.delete(key: 'vendor_task_draft_$assignmentId');
  }

  static Future<String?> readNotificationState(String key) =>
      _storage.read(key: key);

  static Future<void> writeNotificationState(String key, String value) =>
      _storage.write(key: key, value: value);

  static Future<void> logout() async {
    await beforeLogout?.call();
    await _storage.deleteAll();
  }
}
