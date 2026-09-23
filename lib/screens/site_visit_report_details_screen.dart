import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

class SiteVisitReportDetailsScreen extends StatefulWidget {
  const SiteVisitReportDetailsScreen({super.key, required this.leadId});

  final String leadId;

  @override
  State<SiteVisitReportDetailsScreen> createState() =>
      _SiteVisitReportDetailsScreenState();
}

class _SiteVisitReportDetailsScreenState
    extends State<SiteVisitReportDetailsScreen> {
  static const _gold = Color(0xFFBF7A16);
  bool loading = true;
  bool processing = false;
  Map<String, dynamic>? report;
  Map<String, dynamic>? lead;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final loadedReport = await ApiService.getSiteVisitReport(widget.leadId);
      final loadedLead = await ApiService.getLead(widget.leadId);
      if (!mounted) return;
      setState(() {
        report = loadedReport;
        lead = loadedLead;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> showManagerApprovalBottomSheet() async {
    final decision = await showModalBottomSheet<_ManagerDecision>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990E0B08),
      builder: (_) => const _ManagerApprovalSheet(),
    );
    if (decision == null || !mounted) return;

    setState(() => processing = true);
    final success = decision.approve
        ? await ApiService.approveSiteVisitReport(
            reportId: report!['Id'],
            leadId: lead!['Id'],
          )
        : await ApiService.requestSiteVisitChanges(
            reportId: report!['Id'],
            leadId: lead!['Id'],
            reason: decision.reason,
          );
    if (!mounted) return;
    setState(() => processing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            decision.approve
                ? 'Site Visit Approved Successfully'
                : 'Changes Requested Successfully',
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Something went wrong.'),
        ),
      );
    }
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
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x08FFFFFF), Color(0xB8FCF8F2)],
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
                        : report == null
                        ? _notFound()
                        : RefreshIndicator(
                            color: _gold,
                            onRefresh: loadData,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                112,
                              ),
                              children: [
                                _ReportSection(
                                  title: 'Visit Summary',
                                  icon: Icons.description_outlined,
                                  rows: [
                                    _ReportDatum(
                                      Icons.person_outline,
                                      'Lead Name',
                                      lead?['Name'],
                                    ),
                                    _ReportDatum(
                                      Icons.verified_user_outlined,
                                      'Supervisor',
                                      report?['Supervisor_User__r']?['Name'],
                                    ),
                                    _ReportDatum(
                                      Icons.calendar_today_outlined,
                                      'Site Visit Date',
                                      report?['Site_Visit_Date__c'],
                                    ),
                                    _ReportDatum(
                                      Icons.schedule_outlined,
                                      'Time Slot',
                                      report?['Site_Visit_Time_Slot__c'],
                                    ),
                                    _ReportDatum(
                                      Icons.flag_outlined,
                                      'Visit Type',
                                      report?['Site_Visit_Type__c'],
                                    ),
                                    _ReportDatum(
                                      Icons.hourglass_empty,
                                      'Estimated Completion',
                                      report?['Estimated_Completion_Months__c'],
                                    ),
                                    _ReportDatum(
                                      Icons.location_on_outlined,
                                      'Site Address',
                                      report?['Site_Address__c'],
                                    ),
                                    _ReportDatum(
                                      Icons.account_balance_wallet_outlined,
                                      'Budget Description',
                                      report?['Estimated_Budget_Description__c'],
                                    ),
                                  ],
                                ),
                                _ReportSection(
                                  title: 'Budget & Area',
                                  icon: Icons.trending_up_rounded,
                                  rows: [
                                    _ReportDatum(
                                      Icons.sell_outlined,
                                      'Estimated Budget',
                                      report?['Estimated_Budget_Description__c'],
                                    ),
                                    _ReportDatum(
                                      Icons.currency_rupee,
                                      'Total Estimated Cost',
                                      report?['Total_Estimated_Cost__c'],
                                    ),
                                    _ReportDatum(
                                      Icons.crop_square,
                                      'Site Area',
                                      report?['Site_Area_Sq_Ft__c'],
                                    ),
                                    _ReportDatum(
                                      Icons.bed_outlined,
                                      'Rooms Count',
                                      report?['Rooms_Count__c'],
                                    ),
                                    _ReportDatum(
                                      Icons.straighten,
                                      'Usable Area',
                                      report?['Usable_Area_Sq_Ft__c'],
                                    ),
                                  ],
                                ),
                                _ReportSection(
                                  title: 'Approval Status',
                                  icon: Icons.verified_user_outlined,
                                  rows: [
                                    _ReportDatum(
                                      Icons.person_add_alt_outlined,
                                      'Client Approval',
                                      report?['Client_Approval__c'] == true
                                          ? 'Yes'
                                          : 'No',
                                      badge: true,
                                    ),
                                    _ReportDatum(
                                      Icons.cloud_upload_outlined,
                                      'Blueprint Uploaded',
                                      report?['Layout_Blueprint_Uploaded__c'] ==
                                              true
                                          ? 'Yes'
                                          : 'No',
                                      badge: true,
                                    ),
                                    _ReportDatum(
                                      Icons.admin_panel_settings_outlined,
                                      'Management Approval',
                                      report?['Management_Approval__c'] == true
                                          ? 'Approved'
                                          : 'Pending',
                                      badge: true,
                                    ),
                                    _ReportDatum(
                                      Icons.flag_outlined,
                                      'Status',
                                      report?['Site_Visit_Report_Status__c'],
                                      badge: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE1A13A), Color(0xFFB96F0D)],
                    ),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x336F430C),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: processing
                        ? null
                        : showManagerApprovalBottomSheet,
                    icon: processing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: Text(
                      processing ? 'Processing...' : 'Manager Approval',
                      style: const TextStyle(fontFamily: 'serif', fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
              child: const Icon(Icons.arrow_back_rounded, color: _gold),
            ),
          ),
        ),
        const Expanded(
          child: Text(
            'Site Visit Report Details',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: Color(0xFF251E18),
              fontFamily: 'serif',
              fontSize: 27,
            ),
          ),
        ),
        const SizedBox(width: 50),
      ],
    ),
  );

  Widget _notFound() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.find_in_page_outlined, size: 52, color: _gold),
        const SizedBox(height: 12),
        const Text(
          'Site Visit Report not found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            setState(() => loading = true);
            loadData();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _ReportDatum {
  const _ReportDatum(this.icon, this.label, this.value, {this.badge = false});
  final IconData icon;
  final String label;
  final dynamic value;
  final bool badge;
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.icon,
    required this.rows,
  });
  final String title;
  final IconData icon;
  final List<_ReportDatum> rows;

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xEFFFFFFF),
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: const Color(0x44BF7A16)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x116B4B20),
          blurRadius: 20,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFFF8EFE3),
              child: Icon(icon, color: const Color(0xFFBF7A16), size: 25),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3D2B1B),
                  fontFamily: 'serif',
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12, bottom: 4),
          child: Divider(color: Color(0x33BF7A16)),
        ),
        for (var index = 0; index < rows.length; index++)
          _ReportRow(
            data: rows[index],
            value: _value(rows[index].value),
            divider: index != rows.length - 1,
          ),
      ],
    ),
  );
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.data,
    required this.value,
    required this.divider,
  });
  final _ReportDatum data;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
      border: divider
          ? const Border(bottom: BorderSide(color: Color(0x22BF7A16)))
          : null,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: const Color(0xFFF9F3EA),
          child: Icon(data.icon, color: const Color(0xFFBF7A16), size: 19),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 125,
          child: Text(
            data.label,
            style: const TextStyle(
              color: Color(0xFF55483C),
              fontFamily: 'serif',
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: data.badge && value != '—'
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusBadge(value: value),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final positive = [
      'yes',
      'approved',
      'completed',
    ].contains(value.toLowerCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFE1F1DC) : const Color(0xFFF8EBD5),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: positive ? const Color(0xFFCBE5C5) : const Color(0xFFEACB99),
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: positive ? const Color(0xFF267832) : const Color(0xFF9D5C0C),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ManagerDecision {
  const _ManagerDecision({required this.approve, this.reason = ''});
  final bool approve;
  final String reason;
}

class _ManagerApprovalSheet extends StatefulWidget {
  const _ManagerApprovalSheet();

  @override
  State<_ManagerApprovalSheet> createState() => _ManagerApprovalSheetState();
}

class _ManagerApprovalSheetState extends State<_ManagerApprovalSheet> {
  static const _gold = Color(0xFFBF7A16);
  final reasonController = TextEditingController();
  bool approve = true;
  String? error;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 8),
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE8D3B5),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 22),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: Color(0xFFF8E8CF),
                  child: Icon(Icons.verified_outlined, color: _gold, size: 28),
                ),
                SizedBox(width: 13),
                Text(
                  'Manager Approval',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 27,
                    color: Color(0xFF251E18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Review this report and choose an action.',
              style: TextStyle(color: Color(0xFF77716A)),
            ),
            const SizedBox(height: 22),
            _DecisionCard(
              icon: Icons.check_circle_outline,
              title: 'Approve Report',
              subtitle: 'Accept this site visit report as complete.',
              selected: approve,
              onTap: () => setState(() {
                approve = true;
                error = null;
              }),
            ),
            const SizedBox(height: 11),
            _DecisionCard(
              icon: Icons.rate_review_outlined,
              title: 'Request Changes',
              subtitle: 'Return the report with manager feedback.',
              selected: !approve,
              onTap: () => setState(() => approve = false),
            ),
            if (!approve) ...[
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Reason for changes',
                  hintText: 'Describe what needs to be updated',
                  errorText: error,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _gold),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      foregroundColor: _gold,
                      side: const BorderSide(color: Color(0x66BF7A16)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      final reason = reasonController.text.trim();
                      if (!approve && reason.isEmpty) {
                        setState(() => error = 'Please enter the reason.');
                        return;
                      }
                      Navigator.pop(
                        context,
                        _ManagerDecision(approve: approve, reason: reason),
                      );
                    },
                    icon: Icon(
                      approve
                          ? Icons.check_circle_outline
                          : Icons.send_outlined,
                    ),
                    label: Text(approve ? 'Approve' : 'Request Changes'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: _gold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF6E8) : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? const Color(0xFFBF7A16) : const Color(0x44BF7A16),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFF8E8CF),
              child: Icon(icon, color: const Color(0xFFBF7A16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF77716A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: const Color(0xFFBF7A16),
            ),
          ],
        ),
      ),
    ),
  );
}
