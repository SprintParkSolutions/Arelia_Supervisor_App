import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SiteVisitReportDetailsScreen extends StatefulWidget {
  final String leadId;

  const SiteVisitReportDetailsScreen({
    super.key,
    required this.leadId,
  });

  @override
  State<SiteVisitReportDetailsScreen> createState() =>
      _SiteVisitReportDetailsScreenState();
}

class _SiteVisitReportDetailsScreenState
    extends State<SiteVisitReportDetailsScreen> {

  bool loading = true;

  Map<String, dynamic>? report;
  Map<String, dynamic>? lead;

  String approvalType = "approve";

  final TextEditingController reasonController =
    TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {

      report = await ApiService.getSiteVisitReport(widget.leadId);

      lead = await ApiService.getLead(widget.leadId);

      setState(() {
        loading = false;
      });

    } catch (e) {

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  void showManagerApprovalBottomSheet() {

  approvalType = "approve";
  reasonController.clear();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    builder: (context) {

      return StatefulBuilder(
        builder: (context, setBottomState) {

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                const Text(
                  "Manager Approval",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                RadioListTile<String>(
                  title: const Text("Approve"),
                  value: "approve",
                  groupValue: approvalType,
                  onChanged: (value) {
                    setBottomState(() {
                      approvalType = value!;
                    });
                  },
                ),

                RadioListTile<String>(
                  title: const Text("Request Changes"),
                  value: "review",
                  groupValue: approvalType,
                  onChanged: (value) {
                    setBottomState(() {
                      approvalType = value!;
                    });
                  },
                ),

                if (approvalType == "review")
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: reasonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: "Reason",
                        hintText: "Enter reason for requesting changes",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                const SizedBox(height: 25),

                Row(
                  children: [

                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text("Cancel"),
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () async {

                          if (approvalType == "review" &&
                              reasonController.text.trim().isEmpty) {

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please enter the reason.",
                                ),
                              ),
                            );

                            return;
                          }

                          Navigator.pop(context);

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          bool success;

                          if (approvalType == "approve") {

                            success =
                                await ApiService.approveSiteVisitReport(
                              reportId: report!["Id"],
                              leadId: lead!["Id"],
                            );

                          } else {

                            success =
                                await ApiService.requestSiteVisitChanges(
                              reportId: report!["Id"],
                              leadId: lead!["Id"],
                              reason: reasonController.text.trim(),
                            );

                          }

                          Navigator.pop(context);

                          if (success) {

                            await loadData();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green,
                                content: Text(
                                  approvalType == "approve"
                                      ? "Site Visit Approved Successfully"
                                      : "Changes Requested Successfully",
                                ),
                              ),
                            );

                          } else {

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.red,
                                content: Text(
                                  "Something went wrong.",
                                ),
                              ),
                            );

                          }

                        },
                        child: const Text(
                          "Submit",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )

                  ],
                ),

              ],
            ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          SizedBox(
            width: 170,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value?.toString() ?? "-",
              style: const TextStyle(
                fontSize: 15,
              ),
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

    if (report == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Site Visit Report Details"),
        ),
        body: const Center(
          child: Text("Site Visit Report not found"),
        ),
      );
    }

    return Scaffold(

      appBar: AppBar(
        backgroundColor: const Color(0xffD4AF37),
        title: const Text(
          "Site Visit Report Details",
        ),
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(16),

        child: Card(

          elevation: 3,

          child: Padding(

            padding: const EdgeInsets.all(16),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const Text(
                  "Site Visit Information",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Divider(),

                detailRow(
                  "Lead Name",
                  lead?["Name"],
                ),

                detailRow(
                  "Supervisor",
                  report!["Supervisor_User__r"]?["Name"],
                ),

                detailRow(
                  "Site Visit Date",
                  report!["Site_Visit_Date__c"],
                ),

                detailRow(
                  "Time Slot",
                  report!["Site_Visit_Time_Slot__c"],
                ),

                detailRow(
                  "Visit Type",
                  report!["Site_Visit_Type__c"],
                ),

                detailRow(
                  "Site Address",
                  report!["Site_Address__c"],
                ),

                detailRow(
                  "Description",
                  report!["Description__c"],
                ),

                detailRow(
                  "Estimated Completion",
                  report!["Estimated_Completion_Months__c"],
                ),

                detailRow(
                  "Estimated Budget",
                  report!["Estimated_Budget_Description__c"],
                ),

                detailRow(
                  "Total Estimated Cost",
                  report!["Total_Estimated_Cost__c"],
                ),

                detailRow(
                  "Site Area",
                  report!["Site_Area_Sq_Ft__c"],
                ),

                detailRow(
                  "Usable Area",
                  report!["Usable_Area_Sq_Ft__c"],
                ),

                detailRow(
                  "Rooms Count",
                  report!["Rooms_Count__c"],
                ),

                detailRow(
                  "Client Approval",
                  report!["Client_Approval__c"] == true
                      ? "Yes"
                      : "No",
                ),

                detailRow(
                  "Blueprint Uploaded",
                  report!["Layout_Blueprint_Uploaded__c"] == true
                      ? "Yes"
                      : "No",
                ),

                detailRow(
                  "Management Approval",
                  report!["Management_Approval__c"] == true
                      ? "Approved"
                      : "Pending",
                ),

                detailRow(
                  "Status",
                  report!["Site_Visit_Report_Status__c"],
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),

                    icon: const Icon(Icons.verified),

                    label: const Text(
                      "Manager Approval",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),

                   onPressed: () {
  showManagerApprovalBottomSheet();
},

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