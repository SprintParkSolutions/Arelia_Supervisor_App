import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'site_visit/site_visit_step1.dart';
import 'site_visit_report_details_screen.dart';


class LeadDetailsScreen extends StatefulWidget {
  final String leadId;

  const LeadDetailsScreen({
    super.key,
    required this.leadId,
  });

  @override
  State<LeadDetailsScreen> createState() => _LeadDetailsScreenState();
}

class _LeadDetailsScreenState extends State<LeadDetailsScreen> {
  bool loading = true;
  Map<String, dynamic>? lead;
  List<dynamic> supervisors = [];

  String? selectedType;
String? selectedSlot;
DateTime? selectedDate;

final List<String> appointmentTypes = [
  "New",
  "Follow-up",
];

final List<String> timeSlots = [
  "9AM-10AM",
  "10AM-11AM",
  "11AM-12PM",
  "12PM-1PM",
  "1PM-2PM",
  "2PM-3PM",
  "3PM-4PM",
  "4PM-5PM",
  "5PM-6PM",
];

  @override
  void initState() {
    super.initState();
    loadLead();
  }

  Future<void> loadLead() async {
    try {
      final result = await ApiService.getLead(widget.leadId);

      setState(() {
        lead = result;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> assignSupervisor() async {
  try {
    supervisors = await ApiService.getSupervisors();

    final selectedUser = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Assign Supervisor"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: supervisors.length,
              itemBuilder: (context, index) {
                final user = supervisors[index];

                return ListTile(
  title: Text(user["Name"]),
  onTap: () {
    Navigator.pop(context, user);
  },
);
              },
            ),
          ),
        );
      },
    );

    if (selectedUser == null) return;

bool success = await ApiService.assignSupervisor(
  leadId: lead!["Id"],
  supervisorId: selectedUser["Id"],
);

   if (success) {

  await loadLead();

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      backgroundColor: Colors.green,
      content: Text("Supervisor Assigned Successfully"),
    ),
  );

} else {

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      backgroundColor: Colors.red,
      content: Text("Failed to assign Supervisor"),
    ),
  );

}

} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString())),
  );
}
}

void showBookSiteVisitDialog() {
  selectedType ??= appointmentTypes.first;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Book Site Visit"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Appointment Type
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: "Appointment Type",
                      border: OutlineInputBorder(),
                    ),
                    items: appointmentTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedType = value;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  // Date Picker
                  TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: selectedDate == null
                          ? "Appointment Date"
                          : "${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}",
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                      );

                      if (date != null) {
                        setStateDialog(() {
                          selectedDate = date;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 15),

                  // Time Slot
                  DropdownButtonFormField<String>(
                    value: selectedSlot,
                    decoration: const InputDecoration(
                      labelText: "Time Slot",
                      border: OutlineInputBorder(),
                    ),
                    items: timeSlots.map((slot) {
                      return DropdownMenuItem(
                        value: slot,
                        child: Text(slot),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedSlot = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            actions: [

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),

              ElevatedButton(
                onPressed: () async {

                  if (selectedDate == null || selectedSlot == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please fill all fields."),
                      ),
                    );
                    return;
                  }

                  final date =
                      "${selectedDate!.year.toString().padLeft(4, '0')}-"
                      "${selectedDate!.month.toString().padLeft(2, '0')}-"
                      "${selectedDate!.day.toString().padLeft(2, '0')}";

                  bool success = await ApiService.bookSiteVisit(
                    leadId: lead!["Id"],
                    appointmentType: selectedType!,
                    appointmentDate: date,
                    appointmentSlot: selectedSlot!,
                  );

                  if (success) {
                    Navigator.pop(context);

                    await loadLead();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.green,
                        content: Text("Site Visit Booked Successfully"),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.red,
                        content: Text("Failed to book Site Visit"),
                      ),
                    );
                  }
                },
                child: const Text("Book Site Visit"),
              ),
            ],
          );
        },
      );
    },
  );
}

  Widget detailRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? "-",
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lead Details"),
        backgroundColor: const Color(0xffD4AF37),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                detailRow("Lead Name", lead!["Name"]),

                detailRow("Company", lead!["Company"]),

                detailRow("Phone", lead!["Phone"]),

                detailRow("Email", lead!["Email"]),

                detailRow("Lead Status", lead!["Status"]),

                detailRow(
                  "Lead Owner",
                  lead!["Owner"]?["Name"],
                ),

                detailRow(
                  "Approval Status",
                  lead!["Approval_Status__c"],
                ),

                detailRow(
                  "Project Submitted",
                  lead!["Project_Request_Submitted__c"] == true
                      ? "Yes"
                      : "No",
                ),

                detailRow(
                  "Customer Budget",
                  lead!["Customer_Budget__c"],
                ),

                detailRow(
                  "Site Location",
                  lead!["Site_Location__c"],
                ),

                detailRow(
                  "Project Description",
                  lead!["Project_Description__c"],
                ),

                const Divider(height: 35),

detailRow(
  "Supervisor",
  lead!["Supervisor_User__r"]?["Name"] ?? "-",
),

detailRow(
  "Supervisor Email",
  lead!["Supervisor_User_Email__c"],
),

detailRow(
  "Supervisor Phone",
  lead!["Supervisor_User_Phone__c"],
),

const Divider(height: 35),

const Align(
  alignment: Alignment.centerLeft,
  child: Text(
    "Appointment Information",
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),
),

const SizedBox(height: 15),

detailRow(
  "Appointment Type",
  lead!["Appointment_Confirmation_Type__c"],
),

detailRow(
  "Appointment Status",
  lead!["Appointment_Status__c"],
),

detailRow(
  "Appointment Sent Date",
  lead!["Appointment_Sent_date__c"],
),

detailRow(
  "Appointment Confirmed Date",
  lead!["Appointment_Date__c"],
),

detailRow(
  "Appointment Time Slot",
  lead!["Appointment_Time_Slots__c"],
),

detailRow(
  "Appointment Confirmed",
  lead!["Appointment_Completed__c"] == true ? "Yes" : "No",
),

detailRow(
  "Rescheduled Date",
  lead!["Appointment_Rescheduled_Time__c"],
),

detailRow(
  "Rescheduled Time Slot",
  lead!["Time_Slots__c"],
),


const SizedBox(height: 30),

                SizedBox(
  width: double.infinity,
  height: 55,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green,
    ),
    onPressed: () async {

      final bool projectSubmitted =
          lead!["Project_Request_Submitted__c"] == true;

      final String approvalStatus =
          lead!["Approval_Status__c"]?.toString() ?? "";

      if (approvalStatus.toLowerCase() == "approved") {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              "This Lead is already approved.",
            ),
          ),
        );

        return;
      }

      if (!projectSubmitted) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Project Request has not been submitted. Lead cannot be approved.",
            ),
          ),
        );

        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      bool success = await ApiService.approveLead(
        lead!["Id"],
      );

      Navigator.pop(context);

      if (success) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              "Lead Approved Successfully.",
            ),
          ),
        );

        await loadLead();

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Failed to approve the Lead.",
            ),
          ),
        );

      }

    },
    child: const Text(
      "Approve Lead",
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
  ),
),

                const SizedBox(height: 15),

                SizedBox(
  width: double.infinity,
  height: 55,
  child: ElevatedButton(
    onPressed: () async {

      if ((lead!["Approval_Status__c"] ?? "") != "Approved") {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              "Please approve the Lead before assigning a Supervisor.",
            ),
          ),
        );

        return;
      }

      await assignSupervisor();
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
    ),
    child: const Text(
      "Assign Supervisor",
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
      ),
    ),
  ),
),
const SizedBox(height: 15),

SizedBox(
  width: double.infinity,
  height: 55,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.orange,
    ),
    onPressed: () {

      if (lead!["Supervisor_User__c"] == null) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Please assign a Supervisor before booking a Site Visit.",
            ),
          ),
        );

        return;
      }

      showBookSiteVisitDialog();

    },
    child: const Text(
      "Book Site Visit",
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),
const SizedBox(height: 15),

SizedBox(
  width: double.infinity,
  height: 55,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.deepPurple,
    ),
    onPressed: () {

      if (lead!["Supervisor_User__c"] == null) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please assign a Supervisor first.",
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SiteVisitStep1(
            leadId: lead!["Id"],
            supervisorId: lead!["Supervisor_User__c"],
          ),
        ),
      );

    },
    child: const Text(
      "Site Visit Report Data",
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),
const SizedBox(height: 15),

SizedBox(
  width: double.infinity,
  height: 55,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.teal,
    ),
    onPressed: () {

      if (lead!["Supervisor_User__c"] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Please assign a Supervisor first.",
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SiteVisitReportDetailsScreen(
            leadId: lead!["Id"],
          ),
        ),
      );
    },
    child: const Text(
      "Site Visit Report Details",
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),
const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      "Reject Lead",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}