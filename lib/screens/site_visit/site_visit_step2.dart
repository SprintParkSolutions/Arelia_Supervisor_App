import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'site_visit_step3.dart';

class SiteVisitStep2 extends StatefulWidget {
  final String reportId;
  final String leadId;
  final String supervisorId;

  const SiteVisitStep2({
    super.key,
    required this.reportId,
    required this.leadId,
    required this.supervisorId,
  });

  @override
  State<SiteVisitStep2> createState() =>
      _SiteVisitStep2State();
}

class _SiteVisitStep2State
    extends State<SiteVisitStep2> {

  File? selectedFile;

  bool loading = false;


  String fileName = "";

  @override
  void initState() {
    super.initState();
    
  }

  

  Future<void> pickFile() async {

    FilePickerResult? result =
        await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        "pdf",
        "jpg",
        "jpeg",
        "png"
      ],
    );

    if (result == null) return;

    selectedFile =
        File(result.files.single.path!);

    fileName = result.files.single.name;

    setState(() {});
  }

 Future<void> uploadFile() async {

  // If no file is selected, simply skip upload
  if (selectedFile == null) {

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SiteVisitStep3(
          leadId: widget.leadId,
          supervisorId: widget.supervisorId,
        ),
      ),
    );

    return;
  }

  setState(() {
    loading = true;
  });

  bool success = await ApiService.uploadBlueprint(
    reportId: widget.reportId,
    file: selectedFile!,
  );

  setState(() {
    loading = false;
  });

  if (!success) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Blueprint upload failed"),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => SiteVisitStep3(
        leadId: widget.leadId,
        supervisorId: widget.supervisorId,
      ),
    ),
  );
}

  Widget stepHeader() {

    return Row(
      children: [

        Expanded(
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius:
                  BorderRadius.circular(25),
            ),
            child: const Center(
              child: Icon(
                Icons.check,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius:
                  BorderRadius.circular(25),
            ),
            child: const Center(
              child: Text(
                "Upload Documents",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius:
                  BorderRadius.circular(25),
            ),
            child: const Center(
              child: Text(
                "Preview & Submit",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Site Visit Report"),
      ),

      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          children: [

            stepHeader(),

            const SizedBox(height:40),

            const Text(
              "Upload Layout Blueprint",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height:30),

            Expanded(

              child: Container(

                width: double.infinity,

                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                    width: 2,
                  ),
                  borderRadius:
                      BorderRadius.circular(10),
                ),

                child: Center(

                  child: Column(

                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [

                OutlinedButton.icon(
  onPressed: pickFile,
  icon: const Icon(Icons.upload),
  label: Text(
    fileName.isEmpty ? "Choose Blueprint (Optional)" : "Change File",
  ),
),

const SizedBox(height: 20),

if (fileName.isNotEmpty)
  Text(
    fileName,
    style: const TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.green,
    ),
  ),

                      if (fileName.isNotEmpty)

                        Padding(
                          padding:
                              const EdgeInsets.only(
                                  top: 20),
                          child: Text(fileName),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height:25),

            SizedBox(

              width: double.infinity,

              height: 50,

              child: ElevatedButton(

                onPressed:
                    loading ? null : uploadFile,

                child: loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        "Next : Preview",
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}