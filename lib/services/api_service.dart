import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/salesforce_config.dart';
import 'storage_service.dart';
import 'dart:io';

class ApiService {
  static const String instanceUrl =
      "https://sprintpark--dev4.sandbox.my.salesforce.com";

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

  /// Fetch Single Lead Details
 /// Fetch Single Lead Details
static Future<Map<String, dynamic>> getLead(String leadId) async {
  final token = await StorageService.getAccessToken();

 final query = '''
SELECT
Id,
Name,
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

  /// Approve Lead
static Future<bool> approveLead(String leadId) async {
  final token = await StorageService.getAccessToken();

  final response = await http.patch(
    Uri.parse(
      "$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId",
    ),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "Approval_Status__c": "Approved",
    }),
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
    Uri.parse(
      "$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId",
    ),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "Supervisor_User__c": supervisorId,
    }),
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
  final token = await StorageService.getAccessToken();

  final response = await http.patch(
    Uri.parse(
      "$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId",
    ),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "Appointment_Confirmation_Type__c": appointmentType,
      "Appointment_Date__c": appointmentDate,
      "Appointment_Time_Slots__c": appointmentSlot,
    }),
  );

  print(response.statusCode);
  print(response.body);

  return response.statusCode == 204;
}


//Site visit Report

static Future<Map<String, dynamic>?> getSiteVisitReport(
    String leadId) async {
  final token = await StorageService.getAccessToken();

  final query = '''
SELECT
Id,
Name,
Lead__c,
Supervisor_User__c,
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

    response = await http.post(
      Uri.parse(
        "$instanceUrl/services/data/v64.0/sobjects/Site_Visit_Report__c",
      ),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
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

static Future<bool> finalSubmitSiteVisit({
  required String reportId,
}) async {
  final token = await StorageService.getAccessToken();

  final response = await http.patch(
    Uri.parse(
        "$instanceUrl/services/data/v64.0/sobjects/Site_Visit_Report__c/$reportId"),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "Is_Final_Submitted__c": true,
      "Site_Visit_Report_Status__c": "Approved",
    }),
  );

  return response.statusCode == 204;
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
    Uri.parse(
      "$instanceUrl/services/data/v64.0/sobjects/ContentVersion",
    ),
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

  final contentVersionId =
      jsonDecode(response.body)["id"];

  return await linkBlueprintToReport(
      reportId, contentVersionId);
}
static Future<bool> linkBlueprintToReport(
    String reportId,
    String contentVersionId) async {

  final token = await StorageService.getAccessToken();

  final query = '''
SELECT ContentDocumentId
FROM ContentVersion
WHERE Id='$contentVersionId'
''';

  final url =
      "$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}";

  final res = await http.get(
    Uri.parse(url),
    headers: {
      "Authorization": "Bearer $token",
    },
  );

  if (res.statusCode != 200) {
    return false;
  }

  final documentId =
      jsonDecode(res.body)["records"][0]["ContentDocumentId"];

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
      "Wizard_Step__c": 2
    }),
  );

  return update.statusCode == 204;
}
static Future<bool> hasBlueprint(
    String reportId) async {

  final token = await StorageService.getAccessToken();

  final query = '''
SELECT Id
FROM ContentDocumentLink
WHERE LinkedEntityId='$reportId'
LIMIT 1
''';

  final url =
      "$instanceUrl/services/data/v64.0/query?q=${Uri.encodeComponent(query)}";

  final response = await http.get(
    Uri.parse(url),
    headers: {
      "Authorization": "Bearer $token",
    },
  );

  if (response.statusCode != 200) {
    return false;
  }

  final records =
      jsonDecode(response.body)["records"];

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
    Uri.parse(
      "$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId",
    ),
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
    Uri.parse(
      "$instanceUrl/services/data/v64.0/sobjects/Lead/$leadId",
    ),
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