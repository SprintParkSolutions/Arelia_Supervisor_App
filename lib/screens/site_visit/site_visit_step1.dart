import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'site_visit_step2.dart';

class SiteVisitStep1 extends StatefulWidget {
  final String leadId;
  final String supervisorId;

  const SiteVisitStep1({
    super.key,
    required this.leadId,
    required this.supervisorId,
  });

  @override
  State<SiteVisitStep1> createState() => _SiteVisitStep1State();
}

class _SiteVisitStep1State extends State<SiteVisitStep1> {

  bool loading = true;

  String? reportId;

  final estimatedBudgetController = TextEditingController();
  final totalCostController = TextEditingController();
  final usableAreaController = TextEditingController();
  final roomsController = TextEditingController();

  bool clientApproval = false;

  String? completionMonths;

  final months = const [
    "1 Month",
    "2 Months",
    "3 Months",
    "4 Months",
    "5 Months",
    "6 Months"
  ];

  @override
  void initState() {
    super.initState();
    loadDraft();
  }

  Future<void> loadDraft() async {
    final report =
        await ApiService.getSiteVisitReport(widget.leadId);

    if (report != null) {
      reportId = report["Id"];

      completionMonths =
          report["Estimated_Completion_Months__c"];

      estimatedBudgetController.text =
          report["Estimated_Budget_Description__c"] ?? "";

      totalCostController.text =
          report["Total_Estimated_Cost__c"]?.toString() ?? "";

      usableAreaController.text =
          report["Usable_Area_Sq_Ft__c"]?.toString() ?? "";

      roomsController.text =
          report["Rooms_Count__c"] ?? "";

      clientApproval =
          report["Client_Approval__c"] == true;
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> createAndContinue() async {

  final body = {

    "Lead__c": widget.leadId,
    "Supervisor_User__c": widget.supervisorId,

    "Estimated_Completion_Months__c": completionMonths,

    "Estimated_Budget_Description__c":
        estimatedBudgetController.text,

    "Total_Estimated_Cost__c":
        double.tryParse(totalCostController.text),

    "Usable_Area_Sq_Ft__c":
        double.tryParse(usableAreaController.text),

    "Rooms_Count__c":
        roomsController.text,

    "Client_Approval__c":
        clientApproval,

    "Wizard_Step__c": 1,
  };

  reportId = await ApiService.saveSiteVisitDraft(
  reportId: reportId,
  body: body,
);

if (reportId == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Failed to save report"),
      backgroundColor: Colors.red,
    ),
  );
  return;
}

  Navigator.push(

    context,

    MaterialPageRoute(

      builder: (_) => SiteVisitStep2(

        reportId: reportId!,
        leadId: widget.leadId,
        supervisorId: widget.supervisorId,

      ),
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
        title: const Text("Site Visit Report"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            Row(
              children: [

                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: completionMonths,
                    decoration: const InputDecoration(
                      labelText: "Estimated Completion Months",
                      border: OutlineInputBorder(),
                    ),
                    items: months.map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        completionMonths = v;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: TextField(
                    controller: totalCostController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Total Estimated Cost",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

              ],
            ),

            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Expanded(
                  child: TextField(
                    controller: estimatedBudgetController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Estimated Budget Description",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: CheckboxListTile(
                    value: clientApproval,
                    title: const Text("Client Approval"),
                    onChanged: (v) {
                      setState(() {
                        clientApproval = v ?? false;
                      });
                    },
                  ),
                ),

              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [

                Expanded(
                  child: TextField(
                    controller: usableAreaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Usable Area (Sq Ft)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: TextField(
                    controller: roomsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Rooms Count",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

              ],
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: createAndContinue,
                child: const Text(
                  "Create & Continue",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    estimatedBudgetController.dispose();
    totalCostController.dispose();
    usableAreaController.dispose();
    roomsController.dispose();
    super.dispose();
  }
}