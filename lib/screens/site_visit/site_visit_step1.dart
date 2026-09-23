import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'site_visit_step2.dart';

class SiteVisitStep1 extends StatefulWidget {
  const SiteVisitStep1({
    super.key,
    required this.leadId,
    required this.supervisorId,
  });

  final String leadId;
  final String supervisorId;

  @override
  State<SiteVisitStep1> createState() => _SiteVisitStep1State();
}

class _SiteVisitStep1State extends State<SiteVisitStep1> {
  static const _gold = Color(0xFFBF7A16);
  bool loading = true;
  bool saving = false;
  String? reportId;
  String? completionMonths;
  bool clientApproval = false;

  final estimatedBudgetController = TextEditingController();
  final totalCostController = TextEditingController();
  final usableAreaController = TextEditingController();
  final roomsController = TextEditingController();
  final months = const [
    '1 Month',
    '2 Months',
    '3 Months',
    '4 Months',
    '5 Months',
    '6 Months',
    '7 Months',
    '8 Months',
    '9 Months',
    '10 Months',
    '11 Months',
    '12 Months',
    '1 Year 1 Month',
    '1 Year 2 Months',
    '1 Year 3 Months',
    '1 Year 4 Months',
    '1 Year 5 Months',
    '1 Year 6 Months',
  ];

  @override
  void initState() {
    super.initState();
    loadDraft();
  }

  Future<void> loadDraft() async {
    try {
      final report = await ApiService.getSiteVisitReport(widget.leadId);
      if (report != null) {
        reportId = report['Id'];
        completionMonths = report['Estimated_Completion_Months__c'];
        estimatedBudgetController.text =
            report['Estimated_Budget_Description__c'] ?? '';
        totalCostController.text =
            report['Total_Estimated_Cost__c']?.toString() ?? '';
        usableAreaController.text =
            report['Usable_Area_Sq_Ft__c']?.toString() ?? '';
        roomsController.text = report['Rooms_Count__c'] ?? '';
        clientApproval = report['Client_Approval__c'] == true;
      }
      if (mounted) setState(() => loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> createAndContinue() async {
    setState(() => saving = true);
    final body = {
      'Lead__c': widget.leadId,
      'Supervisor_User__c': widget.supervisorId,
      'Estimated_Completion_Months__c': completionMonths,
      'Estimated_Budget_Description__c': estimatedBudgetController.text,
      'Total_Estimated_Cost__c': double.tryParse(totalCostController.text),
      'Usable_Area_Sq_Ft__c': double.tryParse(usableAreaController.text),
      'Rooms_Count__c': roomsController.text,
      'Client_Approval__c': clientApproval,
      'Wizard_Step__c': 1,
    };
    reportId = await ApiService.saveSiteVisitDraft(
      reportId: reportId,
      body: body,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (reportId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save report'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SiteVisitStep2(
          reportId: reportId!,
          leadId: widget.leadId,
          supervisorId: widget.supervisorId,
        ),
      ),
    );
    if (submitted == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _ReportScaffold(
      title: 'Site Visit Report',
      onBack: () => Navigator.pop(context),
      child: loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                const Text(
                  'Please fill in the site visit report details below.',
                  style: TextStyle(color: Color(0xFF6F6861), fontSize: 16),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 620;
                    final fields = [
                      _ReportFieldCard(
                        title: 'Estimated Completion Months',
                        icon: Icons.calendar_month_outlined,
                        child: DropdownButtonFormField<String>(
                          initialValue: completionMonths,
                          hint: const Text('Select months'),
                          decoration: _inputDecoration(),
                          items: months
                              .map(
                                (month) => DropdownMenuItem(
                                  value: month,
                                  child: Text(month),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => completionMonths = value);
                          },
                        ),
                      ),
                      _ReportFieldCard(
                        title: 'Total Estimated Cost',
                        icon: Icons.currency_rupee,
                        child: TextField(
                          controller: totalCostController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _inputDecoration(
                            hint: 'Enter total cost',
                          ),
                        ),
                      ),
                    ];
                    if (!wide) {
                      return Column(
                        children: [
                          fields[0],
                          const SizedBox(height: 14),
                          fields[1],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 14),
                        Expanded(child: fields[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _ReportFieldCard(
                  title: 'Estimated Budget Description',
                  icon: Icons.description_outlined,
                  child: TextField(
                    controller: estimatedBudgetController,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: _inputDecoration(
                      hint: 'Describe the estimated budget and scope',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _reportCardDecoration(),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Color(0xFFF8EFE3),
                        child: Icon(Icons.verified_user_outlined, color: _gold),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Client Approval',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 20,
                                color: Color(0xFF302820),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Confirm if the client has approved the estimated plan',
                              style: TextStyle(
                                color: Color(0xFF77716B),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: clientApproval,
                        activeColor: _gold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        onChanged: (value) {
                          setState(() => clientApproval = value ?? false);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _ReportFieldCard(
                        title: 'Usable Area (Sq Ft)',
                        icon: Icons.crop_free_outlined,
                        child: TextField(
                          controller: usableAreaController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _inputDecoration(hint: 'Enter area'),
                        ),
                      ),
                      _ReportFieldCard(
                        title: 'Rooms Count',
                        icon: Icons.bed_outlined,
                        child: TextField(
                          controller: roomsController,
                          decoration: _inputDecoration(hint: 'Enter rooms'),
                        ),
                      ),
                    ];
                    if (constraints.maxWidth < 620) {
                      return Column(
                        children: [
                          cards[0],
                          const SizedBox(height: 14),
                          cards[1],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 14),
                        Expanded(child: cards[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _GoldButton(
                  label: 'Create & Continue',
                  icon: Icons.arrow_forward_rounded,
                  loading: saving,
                  onTap: createAndContinue,
                ),
              ],
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

class _ReportScaffold extends StatelessWidget {
  const _ReportScaffold({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    child: Row(
                      children: [
                        _BackButton(onTap: onBack),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 29,
                              color: Color(0xFF251E18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 50),
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xEFFFFFFF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x55BF7A16)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Color(0xFFBF7A16)),
        ),
      ),
    );
  }
}

class _ReportFieldCard extends StatelessWidget {
  const _ReportFieldCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _reportCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFF8EFE3),
                child: Icon(icon, color: const Color(0xFFBF7A16), size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 18,
                    color: Color(0xFF302820),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({String? hint}) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: const Color(0xBFFFFFFF),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0x66BF7A16)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFBF7A16), width: 1.4),
  ),
);

BoxDecoration _reportCardDecoration() => BoxDecoration(
  color: const Color(0xEFFFFFFF),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: const Color(0x44BF7A16)),
  boxShadow: const [
    BoxShadow(color: Color(0x106B4B20), blurRadius: 18, offset: Offset(0, 7)),
  ],
);

class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          loading ? 'Saving...' : label,
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
    );
  }
}
