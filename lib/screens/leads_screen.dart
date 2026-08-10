import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'lead_details_screen.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  List<dynamic> leads = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadLeads();
  }

  Future<void> loadLeads() async {
    try {
      final result = await ApiService.getLeads();

      setState(() {
        leads = result;
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

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "qualified":
        return Colors.green;
      case "working":
        return Colors.orange;
      case "new":
        return Colors.blue;
      case "closed":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F0F0F),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          "Supervisor Leads",
          style: TextStyle(
            color: Color(0xffD4AF37),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xffD4AF37),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xffD4AF37),
              onRefresh: loadLeads,
              child: ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: leads.length,
                itemBuilder: (context, index) {
                  final lead = leads[index];

                 return InkWell(
  borderRadius: BorderRadius.circular(15),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadDetailsScreen(
          leadId: lead["Id"],
        ),
      ),
    );
  },
  child: Card(
                    margin: const EdgeInsets.only(bottom: 15),
                    color: const Color(0xff1A1A1A),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: const BorderSide(
                        color: Color(0xffD4AF37),
                        width: 0.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 25,
                                backgroundColor: Color(0xffD4AF37),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(width: 15),

                              Expanded(
                                child: Text(
                                  lead["Name"] ?? "",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          infoTile(
                            Icons.business,
                            "Company",
                            lead["Company"] ?? "-",
                          ),

                          infoTile(
                            Icons.phone,
                            "Phone",
                            lead["Phone"] ?? "-",
                          ),

                          infoTile(
                            Icons.email,
                            "Email",
                            lead["Email"] ?? "-",
                          ),

                          infoTile(
                            Icons.person_outline,
                            "Owner",
                            lead["Owner"]?["Name"] ?? "-",
                          ),

                          const SizedBox(height: 15),

                          Row(
                            children: [

                              const Text(
                                "Status : ",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: getStatusColor(
                                    lead["Status"] ?? "",
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  lead["Status"] ?? "",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget infoTile(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [

          Icon(
            icon,
            color: const Color(0xffD4AF37),
            size: 20,
          ),

          const SizedBox(width: 10),

          Text(
            "$title : ",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          )
        ],
      ),
    );
  }
}