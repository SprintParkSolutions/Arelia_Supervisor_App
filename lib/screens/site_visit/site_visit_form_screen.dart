import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class SiteVisitFormScreen extends StatefulWidget {
  final String leadId;
  final String supervisorId;

  const SiteVisitFormScreen({
    super.key,
    required this.leadId,
    required this.supervisorId,
  });

  @override
  State<SiteVisitFormScreen> createState() => _SiteVisitFormScreenState();
}

class _SiteVisitFormScreenState extends State<SiteVisitFormScreen> {
  bool loading = true;

  String? reportId;

  final estimatedBudgetController = TextEditingController();

  final totalCostController = TextEditingController();

  final usableAreaController = TextEditingController();

  final roomsController = TextEditingController();

  final siteAreaController = TextEditingController();

  bool clientApproval = false;

  String? completionMonths;

  final months = [
    "1 Month",
    "2 Months",
    "3 Months",
    "4 Months",
    "5 Months",
    "6 Months",
    "7 Months",
    "8 Months",
    "9 Months",
    "10 Months",
    "11 Months",
    "12 Months",
    "1 Year 1 Month",
    "1 Year 2 Months",
    "1 Year 3 Months",
    "1 Year 4 Months",
    "1 Year 5 Months",
    "1 Year 6 Months",
  ];

  @override
  void initState() {
    super.initState();
    loadDraft();
  }

  Future<void> loadDraft() async {
    final report = await ApiService.getSiteVisitReport(widget.leadId);

    if (report != null) {
      reportId = report["Id"];

      completionMonths = report["Estimated_Completion_Months__c"];

      estimatedBudgetController.text =
          report["Estimated_Budget_Description__c"] ?? "";

      totalCostController.text =
          report["Total_Estimated_Cost__c"]?.toString() ?? "";

      usableAreaController.text =
          report["Usable_Area_Sq_Ft__c"]?.toString() ?? "";

      roomsController.text = report["Rooms_Count__c"] ?? "";

      siteAreaController.text = report["Site_Area_Sq_Ft__c"] ?? "";

      clientApproval = report["Client_Approval__c"] == true;
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> saveDraft() async {
    final savedReportId = await ApiService.saveSiteVisitDraft(
      reportId: reportId,

      body: {
        "Lead__c": widget.leadId,

        "Supervisor_User__c": widget.supervisorId,

        "Estimated_Completion_Months__c": completionMonths,

        "Estimated_Budget_Description__c": estimatedBudgetController.text,

        "Total_Estimated_Cost__c": double.tryParse(totalCostController.text),

        "Client_Approval__c": clientApproval,

        "Rooms_Count__c": roomsController.text,

        "Usable_Area_Sq_Ft__c": double.tryParse(usableAreaController.text),

        "Site_Area_Sq_Ft__c": siteAreaController.text,

        "Site_Visit_Report_Status__c": "Pending",

        "Is_Final_Submitted__c": false,
      },
    );

    if (savedReportId != null) {
      reportId = savedReportId;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Draft Saved"),
          backgroundColor: Colors.green,
        ),
      );

      await loadDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Site Visit Report")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: completionMonths,

              items: months.map((e) {
                return DropdownMenuItem(value: e, child: Text(e));
              }).toList(),

              onChanged: (v) {
                setState(() {
                  completionMonths = v;
                });
              },

              decoration: const InputDecoration(
                labelText: "Estimated Completion Months",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: estimatedBudgetController,

              maxLines: 3,

              decoration: const InputDecoration(
                labelText: "Estimated Budget Description",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: totalCostController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(
                labelText: "Total Estimated Cost",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: usableAreaController,

              decoration: const InputDecoration(labelText: "Usable Area"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: siteAreaController,

              decoration: const InputDecoration(labelText: "Site Area"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: roomsController,

              decoration: const InputDecoration(labelText: "Rooms Count"),
            ),

            CheckboxListTile(
              value: clientApproval,

              title: const Text("Client Approval"),

              onChanged: (v) {
                setState(() {
                  clientApproval = v!;
                });
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: saveDraft,

                child: const Text("Save Draft"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
