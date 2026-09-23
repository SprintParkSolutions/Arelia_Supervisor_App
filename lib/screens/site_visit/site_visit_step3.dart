import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';

class SiteVisitStep3 extends StatefulWidget {
  const SiteVisitStep3({
    super.key,
    required this.leadId,
    required this.supervisorId,
    this.blueprintFile,
    this.blueprintName,
  });
  final String leadId;
  final String supervisorId;
  final File? blueprintFile;
  final String? blueprintName;

  @override
  State<SiteVisitStep3> createState() => _SiteVisitStep3State();
}

class _SiteVisitStep3State extends State<SiteVisitStep3> {
  static const _gold = Color(0xFFBF7A16);
  bool loading = true;
  bool saving = false;
  bool submitting = false;
  Map<String, dynamic>? report;
  Map<String, dynamic>? lead;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      report = await ApiService.getSiteVisitReport(widget.leadId);
      lead = await ApiService.getLead(widget.leadId);
      if (mounted) setState(() => loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> saveDraft() async {
    setState(() => saving = true);
    await ApiService.saveSiteVisitDraft(
      reportId: report!['Id'],
      body: {'Wizard_Step__c': 3},
    );
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft Saved Successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> finalSubmit() async {
    setState(() => submitting = true);
    final success = await ApiService.finalSubmitSiteVisit(
      reportId: report!['Id'],
      leadId: widget.leadId,
    );
    if (!mounted) return;
    setState(() => submitting = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit the report for manager approval.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Site Visit Report sent for manager approval.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFFCF8F2),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFCF8F2),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/arelia_lead_details_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x08FFFFFF), Color(0xC8FCF8F2)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _gold),
                          )
                        : report == null || lead == null
                        ? const Center(child: Text('Report data unavailable'))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFF4DF),
                                      Color(0xFFF7E1B9),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0x66BF7A16),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: Color(0xFFFFEBC8),
                                      child: Icon(
                                        Icons.visibility_outlined,
                                        color: _gold,
                                      ),
                                    ),
                                    SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Preview Mode',
                                            style: TextStyle(
                                              color: Color(0xFF74460E),
                                              fontFamily: 'serif',
                                              fontSize: 21,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            'Please verify all details before Final Submit.',
                                            style: TextStyle(
                                              color: Color(0xFF6B5841),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 5,
                                ),
                                decoration: _previewCardDecoration(),
                                child: Column(children: _rows()),
                              ),
                              if (widget.blueprintFile != null) ...[
                                const SizedBox(height: 16),
                                _blueprintPreview(),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: loading || report == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: _bottomStyle(outlined: true),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : saveDraft,
                        style: _bottomStyle(outlined: true),
                        child: Text(saving ? 'Saving...' : 'Save Draft'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE1A13A), Color(0xFFB96F0D)],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ElevatedButton(
                          onPressed: submitting ? null : finalSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(
                            submitting ? 'Submitting…' : 'Submit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
    child: Row(
      children: [
        Material(
          color: const Color(0xEFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x55BF7A16)),
              ),
              child: const Icon(Icons.arrow_back, color: _gold),
            ),
          ),
        ),
        const Expanded(
          child: Text(
            'Preview Site Visit Report',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 26,
              color: Color(0xFF251E18),
            ),
          ),
        ),
        const SizedBox(width: 50),
      ],
    ),
  );

  List<Widget> _rows() {
    final data = [
      (Icons.person_outline, 'Lead', lead!['Name'], false),
      (
        Icons.verified_user_outlined,
        'Supervisor',
        lead!['Supervisor_User__r']?['Name'],
        false,
      ),
      (
        Icons.calendar_today_outlined,
        'Site Visit Date',
        report!['Site_Visit_Date__c'],
        false,
      ),
      (
        Icons.schedule_outlined,
        'Time Slot',
        report!['Site_Visit_Time_Slot__c'],
        false,
      ),
      (
        Icons.hourglass_empty,
        'Estimated Completion',
        report!['Estimated_Completion_Months__c'],
        false,
      ),
      (
        Icons.description_outlined,
        'Estimated Budget',
        report!['Estimated_Budget_Description__c'],
        false,
      ),
      (
        Icons.currency_rupee,
        'Total Estimated Cost',
        report!['Total_Estimated_Cost__c'],
        false,
      ),
      (
        Icons.verified_user_outlined,
        'Client Approval',
        report!['Client_Approval__c'] == true ? 'Yes' : 'No',
        true,
      ),
      (Icons.crop_free, 'Usable Area', report!['Usable_Area_Sq_Ft__c'], false),
      (Icons.bed_outlined, 'Rooms Count', report!['Rooms_Count__c'], false),
      (Icons.crop_square, 'Site Area', report!['Site_Area_Sq_Ft__c'], false),
      (
        Icons.cloud_upload_outlined,
        'Layout Uploaded',
        report!['Layout_Blueprint_Uploaded__c'] == true
            ? 'Uploaded'
            : 'Pending',
        true,
      ),
      (
        Icons.shield_outlined,
        'Management Approval',
        report!['Management_Approval__c'] == true ? 'Approved' : 'Pending',
        true,
      ),
      (
        Icons.flag_outlined,
        'Status',
        report!['Site_Visit_Report_Status__c'],
        true,
      ),
    ];
    return [
      for (var index = 0; index < data.length; index++)
        _PreviewRow(
          icon: data[index].$1,
          label: data[index].$2,
          value: _value(data[index].$3),
          badge: data[index].$4,
          divider: index != data.length - 1,
        ),
    ];
  }

  Widget _blueprintPreview() {
    final file = widget.blueprintFile!;
    final name =
        widget.blueprintName ?? file.path.split(Platform.pathSeparator).last;
    final extension = name.split('.').last.toLowerCase();
    final isImage = {'jpg', 'jpeg', 'png'}.contains(extension);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _previewCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uploaded Blueprint',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3C3127),
            ),
          ),
          const SizedBox(height: 12),
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                file,
                width: double.infinity,
                height: 240,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _blueprintFileTile(name),
              ),
            )
          else
            _blueprintFileTile(name),
        ],
      ),
    );
  }

  Widget _blueprintFileTile(String name) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF6E8),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x44BF7A16)),
    ),
    child: Row(
      children: [
        const Icon(Icons.insert_drive_file_outlined, color: _gold, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
        const Icon(Icons.check_circle, color: Color(0xFF438A47)),
      ],
    ),
  );

  ButtonStyle _bottomStyle({required bool outlined}) =>
      OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF5E3C14),
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(
          color: outlined ? const Color(0x66BF7A16) : Colors.transparent,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.badge,
    required this.divider,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool badge;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: divider
          ? const Border(bottom: BorderSide(color: Color(0x33C89245)))
          : null,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFF8EFE3),
          child: Icon(icon, color: const Color(0xFFBF7A16), size: 20),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'serif',
              color: Color(0xFF3C3127),
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: badge
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          [
                            'yes',
                            'approved',
                            'uploaded',
                          ].contains(value.toLowerCase())
                          ? const Color(0xFFE1F1DC)
                          : const Color(0xFFF8EBD5),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(value),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF292622),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
        ),
      ],
    ),
  );
}

BoxDecoration _previewCardDecoration() => BoxDecoration(
  color: const Color(0xEFFFFFFF),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: const Color(0x44BF7A16)),
  boxShadow: const [
    BoxShadow(color: Color(0x116B4B20), blurRadius: 20, offset: Offset(0, 7)),
  ],
);
