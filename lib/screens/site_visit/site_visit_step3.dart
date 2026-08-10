import 'package:flutter/material.dart';
import '../../services/api_service.dart';
class SiteVisitStep3 extends StatefulWidget {
  final String leadId;
  final String supervisorId;

  const SiteVisitStep3({
    super.key,
    required this.leadId,
    required this.supervisorId,
  });

  @override
  State<SiteVisitStep3> createState() => _SiteVisitStep3State();
}

class _SiteVisitStep3State extends State<SiteVisitStep3> {

  bool loading = true;

  Map<String,dynamic>? report;
  Map<String,dynamic>? lead;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async{

    report =
        await ApiService.getSiteVisitReport(widget.leadId);

    lead =
        await ApiService.getLead(widget.leadId);

    setState(() {
      loading=false;
    });

  }

  Widget row(String title,dynamic value){

    return Padding(

      padding: const EdgeInsets.symmetric(vertical:10),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          SizedBox(

            width:180,

            child: Text(

              title,

              style: const TextStyle(

                fontWeight: FontWeight.bold,

                fontSize:16,

              ),

            ),

          ),

          Expanded(

            child: Text(

              value?.toString() ?? "-",

              style: const TextStyle(fontSize:16),

            ),

          )

        ],

      ),

    );

  }

  Future<void> saveDraft() async{

    await ApiService.saveSiteVisitDraft(

      reportId: report!["Id"],

      body:{

        "Wizard_Step__c":3,

      },

    );

    ScaffoldMessenger.of(context).showSnackBar(

      const SnackBar(

        content: Text("Draft Saved Successfully"),

        backgroundColor: Colors.green,

      ),

    );

  }

  Future<void> finalSubmit() async{

    await ApiService.finalSubmitSiteVisit(

      reportId: report!["Id"],

    );

    ScaffoldMessenger.of(context).showSnackBar(

      const SnackBar(

        content: Text("Site Visit Submitted"),

        backgroundColor: Colors.green,

      ),

    );

    Navigator.pop(context,true);

  }

  @override
  Widget build(BuildContext context) {

    if(loading){

      return const Scaffold(

        body: Center(

          child: CircularProgressIndicator(),

        ),

      );

    }

    return Scaffold(

      appBar: AppBar(

        title: const Text("Preview Site Visit Report"),

      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),

        child: Card(

          elevation:3,

          child: Padding(

            padding: const EdgeInsets.all(20),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Container(

                  width: double.infinity,

                  padding: const EdgeInsets.all(15),

                  decoration: BoxDecoration(

                    color: Colors.orange.shade100,

                    borderRadius: BorderRadius.circular(10),

                  ),

                  child: Column(

                    children: const [

                      Text(

                        "Preview Mode",

                        style: TextStyle(

                          fontSize:18,

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                      SizedBox(height:8),

                      Text(

                        "Please verify all the details before Final Submit.",

                        textAlign: TextAlign.center,

                      )

                    ],

                  ),

                ),

                const SizedBox(height:25),

                row(
                  "Lead",
                  lead!["Name"],
                ),

                row(
                  "Supervisor",
                  lead!["Supervisor_User__r"]?["Name"],
                ),

                row(
                  "Site Visit Date",
                  report!["Site_Visit_Date__c"],
                ),

                row(
                  "Time Slot",
                  report!["Site_Visit_Time_Slot__c"],
                ),

                row(
                  "Estimated Completion",
                  report!["Estimated_Completion_Months__c"],
                ),

                row(
                  "Estimated Budget",
                  report!["Estimated_Budget_Description__c"],
                ),

                row(
                  "Total Estimated Cost",
                  report!["Total_Estimated_Cost__c"],
                ),

                row(
                  "Client Approval",
                  report!["Client_Approval__c"]==true
                      ?"Yes":"No",
                ),

                row(
                  "Usable Area",
                  report!["Usable_Area_Sq_Ft__c"],
                ),

                row(
                  "Rooms Count",
                  report!["Rooms_Count__c"],
                ),

                row(
                  "Site Area",
                  report!["Site_Area_Sq_Ft__c"],
                ),

                row(
                  "Layout Uploaded",
                  report!["Layout_Blueprint_Uploaded__c"]==true
                      ?"Uploaded":"Pending",
                ),

                row(
                  "Management Approval",
                  report!["Management_Approval__c"]==true
                      ?"Approved":"Pending",
                ),

                row(
                  "Status",
                  report!["Site_Visit_Report_Status__c"],
                ),

                const SizedBox(height:35),

                Row(

                  children: [

                    Expanded(

                      child: OutlinedButton(

                        onPressed: ()=>Navigator.pop(context),

                        child: const Text("Back"),

                      ),

                    ),

                    const SizedBox(width:15),

                    Expanded(

                      child: ElevatedButton(

                        onPressed: saveDraft,

                        child: const Text("Save Draft"),

                      ),

                    ),

                    const SizedBox(width:15),

                    Expanded(

                      child: ElevatedButton(

                        style: ElevatedButton.styleFrom(

                          backgroundColor: Colors.green,

                        ),

                        onPressed: finalSubmit,

                        child: const Text(

                          "Final Submit",

                          style: TextStyle(

                            color: Colors.white,

                          ),

                        ),

                      ),

                    )

                  ],

                )

              ],

            ),

          ),

        ),

      ),

    );

  }

}