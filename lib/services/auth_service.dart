import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/salesforce_config.dart';
import 'storage_service.dart';

class AuthService {
  static Future<bool> login() async {
    try {
      final response = await http.post(
        Uri.parse(SalesforceConfig.tokenEndpoint),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "grant_type": "client_credentials",
          "client_id": SalesforceConfig.clientId,
          "client_secret": SalesforceConfig.clientSecret,
        },
      );

      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await StorageService.saveAccessToken(
          data["access_token"],
        );

        print("LOGIN SUCCESS");

        return true;
      }

      print(response.body);
      return false;
    } catch (e) {
      print(e);
      return false;
    }
  }
}