import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'site_visit/site_visit_step1.dart';
import 'site_visit_report_details_screen.dart';

class LeadDetailsScreen extends StatefulWidget {
  const LeadDetailsScreen({super.key, required this.leadId});

  final String leadId;

  @override
  State<LeadDetailsScreen> createState() => _LeadDetailsScreenState();
}

class _LeadDetailsScreenState extends State<LeadDetailsScreen> {
  static const _gold = Color(0xFFBF7A16);
  static const _ink = Color(0xFF211C17);

  bool loading = true;
  bool _refreshing = false;
  Map<String, dynamic>? lead;
  Map<String, dynamic>? siteVisitReport;
  List<Map<String, dynamic>> detailSections = const [];
  List<dynamic> supervisors = [];
  String? selectedType;
  String? selectedSlot;
  DateTime? selectedDate;

  final appointmentTypes = const ['New', 'Follow-up'];
  final timeSlots = const [
    '9AM-10AM',
    '10AM-11AM',
    '11AM-12PM',
    '12PM-1PM',
    '1PM-2PM',
    '2PM-3PM',
    '3PM-4PM',
    '4PM-5PM',
    '5PM-6PM',
  ];

  @override
  void initState() {
    super.initState();
    loadLead();
  }

  Future<void> loadLead() async {
    try {
      Future<T?> optional<T>(Future<T> request) async {
        try {
          return await request;
        } catch (_) {
          return null;
        }
      }

      final results = await Future.wait<dynamic>([
        ApiService.getLead(widget.leadId),
        optional(ApiService.getSiteVisitReport(widget.leadId)),
        optional(
          ApiService.getRecordDetailSections(
            recordId: widget.leadId,
            objectApiName: 'Lead',
          ),
        ),
      ]);
      final result = results[0] as Map<String, dynamic>;
      final loadedReport = results[1] as Map<String, dynamic>?;
      final loadedSections =
          results[2] as List<Map<String, dynamic>>? ?? const [];
      if (!mounted) return;
      setState(() {
        lead = result;
        siteVisitReport = loadedReport;
        detailSections = loadedSections;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      _message(error.toString(), error: true);
    }
  }

  Future<void> _refreshLead() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await loadLead();
    if (mounted) setState(() => _refreshing = false);
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? const Color(0xFFC9413A) : Colors.green,
        content: Text(message),
      ),
    );
  }

  Future<void> assignSupervisor() async {
    var showingProgress = false;
    try {
      _showProgress();
      showingProgress = true;
      supervisors = await ApiService.getSupervisors();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showingProgress = false;
      final selectedUser = await showModalBottomSheet<dynamic>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: const Color(0x990E0B08),
        builder: (context) => _SupervisorPickerSheet(
          supervisors: supervisors,
          currentSupervisorId: lead?['Supervisor_User__c']?.toString(),
        ),
      );
      if (selectedUser == null) return;

      _showProgress();
      showingProgress = true;
      final previousSupervisor = lead!['Supervisor_User__c'];
      final leadName = lead!['Name'] ?? widget.leadId;
      final success = await ApiService.assignSupervisor(
        leadId: lead!['Id'],
        supervisorId: selectedUser['Id'],
      );
      if (success && previousSupervisor != selectedUser['Id']) {
        final action = previousSupervisor == null ? 'assigned' : 'reassigned';
        unawaited(
          NotificationService.instance.recordConfirmedAction(
            source: 'Lead',
            recordId: widget.leadId,
            title: 'Supervisor $action · $leadName',
            body:
                'Supervisor $action: ${selectedUser['Name'] ?? 'Selected supervisor'}',
            fields: {'Supervisor_User__c': selectedUser['Id']},
          ),
        );
      }
      if (!mounted) return;
      if (success) {
        await loadLead();
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        showingProgress = false;
        _message('Supervisor Assigned Successfully');
      } else {
        Navigator.of(context, rootNavigator: true).pop();
        showingProgress = false;
        _message('Failed to assign Supervisor', error: true);
      }
    } catch (error) {
      if (showingProgress && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _message(error.toString(), error: true);
    }
  }

  Future<void> showBookSiteVisitDialog() async {
    selectedType ??= appointmentTypes.first;
    final booking = await showModalBottomSheet<_SiteVisitBooking>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990E0B08),
      builder: (context) => _BookSiteVisitSheet(
        appointmentTypes: appointmentTypes,
        timeSlots: timeSlots,
        initialType: selectedType!,
        initialDate: selectedDate,
        initialSlot: selectedSlot,
      ),
    );
    if (booking == null || !mounted) return;

    selectedType = booking.type;
    selectedDate = booking.date;
    selectedSlot = booking.slot;
    final date =
        '${booking.date.year.toString().padLeft(4, '0')}-'
        '${booking.date.month.toString().padLeft(2, '0')}-'
        '${booking.date.day.toString().padLeft(2, '0')}';

    _showProgress();
    final success = await ApiService.bookSiteVisit(
      leadId: lead!['Id'],
      appointmentType: booking.type,
      appointmentDate: date,
      appointmentSlot: booking.slot,
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (success) {
      await loadLead();
      _message('Site Visit Booked Successfully');
    } else {
      _message('Failed to book Site Visit', error: true);
    }
  }

  Future<void> _approveLead() async {
    final projectSubmitted = lead!['Project_Request_Submitted__c'] == true;
    final approvalStatus = lead!['Approval_Status__c']?.toString() ?? '';
    if (approvalStatus.toLowerCase() == 'approved') {
      _message('This Lead is already approved.');
      return;
    }
    if (!projectSubmitted) {
      _message(
        'Project Request has not been submitted. Lead cannot be approved.',
        error: true,
      );
      return;
    }

    _showProgress();
    final success = await ApiService.approveLead(lead!['Id']);
    if (!mounted) return;
    Navigator.pop(context);
    if (success) {
      _message('Lead Approved Successfully.');
      await loadLead();
    } else {
      _message('Failed to approve the Lead.', error: true);
    }
  }

  Future<void> _rejectLead() async {
    if (lead?['IsConverted'] == true) return;
    _showProgress();
    final success = await ApiService.rejectLead(lead!['Id']);
    if (!mounted) return;
    Navigator.pop(context);
    if (success) {
      await loadLead();
      _message('Lead rejected successfully.');
    } else {
      _message('Unable to reject the Lead.', error: true);
    }
  }

  Future<void> _assignSupervisor() async {
    if ((lead!['Approval_Status__c'] ?? '') != 'Approved') {
      _message(
        'Please approve the Lead before assigning a Supervisor.',
        error: true,
      );
      return;
    }
    await assignSupervisor();
  }

  void _bookSiteVisit() {
    if (lead!['Supervisor_User__c'] == null) {
      _message(
        'Please assign a Supervisor before booking a Site Visit.',
        error: true,
      );
      return;
    }
    showBookSiteVisitDialog();
  }

  Future<void> _openReportData() async {
    if (lead!['Supervisor_User__c'] == null) {
      _message('Please assign a Supervisor first.', error: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SiteVisitStep1(
          leadId: lead!['Id'],
          supervisorId: lead!['Supervisor_User__c'],
        ),
      ),
    );
    if (mounted) await loadLead();
  }

  Future<void> _openReportDetails() async {
    if (lead!['Supervisor_User__c'] == null) {
      _message('Please assign a Supervisor first.', error: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SiteVisitReportDetailsScreen(leadId: lead!['Id']),
      ),
    );
    if (mounted) await loadLead();
  }

  void _showProgress() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _gold)),
    );
  }

  Future<void> _showEditLead() async {
    final current = lead!;
    final formKey = GlobalKey<FormState>();
    final controllers = <String, TextEditingController>{
      'Name': TextEditingController(text: _text(current['Name'], empty: '')),
      'Company': TextEditingController(
        text: _text(current['Company'], empty: ''),
      ),
      'Phone': TextEditingController(text: _text(current['Phone'], empty: '')),
      'Email': TextEditingController(text: _text(current['Email'], empty: '')),
      'Status': TextEditingController(
        text: _text(current['Status'], empty: ''),
      ),
      'Customer_Budget__c': TextEditingController(
        text: _text(current['Customer_Budget__c'], empty: ''),
      ),
      'Site_Location__c': TextEditingController(
        text: _text(current['Site_Location__c'], empty: ''),
      ),
      'Project_Description__c': TextEditingController(
        text: _text(current['Project_Description__c'], empty: ''),
      ),
      'Appointment_Confirmation_Type__c': TextEditingController(
        text: _text(current['Appointment_Confirmation_Type__c'], empty: ''),
      ),
      'Appointment_Status__c': TextEditingController(
        text: _text(current['Appointment_Status__c'], empty: ''),
      ),
      'Appointment_Sent_date__c': TextEditingController(
        text: _text(current['Appointment_Sent_date__c'], empty: ''),
      ),
      'Appointment_Date__c': TextEditingController(
        text: _text(current['Appointment_Date__c'], empty: ''),
      ),
      'Appointment_Time_Slots__c': TextEditingController(
        text: _text(current['Appointment_Time_Slots__c'], empty: ''),
      ),
      'Appointment_Rescheduled_Time__c': TextEditingController(
        text: _text(current['Appointment_Rescheduled_Time__c'], empty: ''),
      ),
      'Time_Slots__c': TextEditingController(
        text: _text(current['Time_Slots__c'], empty: ''),
      ),
    };
    var projectSubmitted = current['Project_Request_Submitted__c'] == true;
    var appointmentCompleted = current['Appointment_Completed__c'] == true;
    var saving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: const Color(0xFFFFFBF6),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.viewInsetsOf(context).bottom +
                  MediaQueryData.fromView(View.of(context)).viewPadding.bottom +
                  20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(0xFFF5E8D5),
                          child: Icon(Icons.edit_outlined, color: _gold),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Edit Lead Information',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Saved changes are written directly to this Salesforce Lead record.',
                      style: TextStyle(color: Color(0xFF77716A), height: 1.4),
                    ),
                    const SizedBox(height: 22),
                    _EditHeading('Contact & lead'),
                    _EditField(
                      controller: controllers['Name']!,
                      label: 'Lead Name',
                      required: true,
                    ),
                    _EditField(
                      controller: controllers['Company']!,
                      label: 'Company',
                      required: true,
                    ),
                    _EditField(
                      controller: controllers['Phone']!,
                      label: 'Phone',
                      keyboardType: TextInputType.phone,
                    ),
                    _EditField(
                      controller: controllers['Email']!,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _EditField(
                      controller: controllers['Status']!,
                      label: 'Lead Status',
                    ),
                    const _LockedEditNote(
                      text:
                          'Lead Owner and Approval Status remain controlled by Salesforce actions.',
                    ),
                    const SizedBox(height: 18),
                    _EditHeading('Project information'),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Project Submitted'),
                      value: projectSubmitted,
                      activeTrackColor: _gold,
                      onChanged: (value) {
                        setSheetState(() => projectSubmitted = value);
                      },
                    ),
                    _EditField(
                      controller: controllers['Customer_Budget__c']!,
                      label: 'Customer Budget',
                    ),
                    _EditField(
                      controller: controllers['Site_Location__c']!,
                      label: 'Site Location',
                    ),
                    _EditField(
                      controller: controllers['Project_Description__c']!,
                      label: 'Project Description',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 18),
                    _EditHeading('Appointment information'),
                    _EditField(
                      controller:
                          controllers['Appointment_Confirmation_Type__c']!,
                      label: 'Appointment Type',
                    ),
                    _EditField(
                      controller: controllers['Appointment_Status__c']!,
                      label: 'Appointment Status',
                    ),
                    _EditField(
                      controller: controllers['Appointment_Sent_date__c']!,
                      label: 'Appointment Sent Date (YYYY-MM-DD)',
                    ),
                    _EditField(
                      controller: controllers['Appointment_Date__c']!,
                      label: 'Confirmed Date (YYYY-MM-DD)',
                    ),
                    _EditField(
                      controller: controllers['Appointment_Time_Slots__c']!,
                      label: 'Appointment Time Slot',
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Appointment Confirmed'),
                      value: appointmentCompleted,
                      activeTrackColor: _gold,
                      onChanged: (value) {
                        setSheetState(() => appointmentCompleted = value);
                      },
                    ),
                    _EditField(
                      controller:
                          controllers['Appointment_Rescheduled_Time__c']!,
                      label: 'Rescheduled Date (YYYY-MM-DD)',
                    ),
                    _EditField(
                      controller: controllers['Time_Slots__c']!,
                      label: 'Rescheduled Time Slot',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          saving
                              ? 'Saving to Salesforce…'
                              : 'Save to Salesforce',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                FocusScope.of(context).unfocus();
                                final fields = _changedSalesforceFields(
                                  controllers: controllers,
                                  current: current,
                                  projectSubmitted: projectSubmitted,
                                  appointmentCompleted: appointmentCompleted,
                                );
                                if (fields.isEmpty) {
                                  _message('No changes to save.');
                                  return;
                                }
                                setSheetState(() => saving = true);
                                final sheetNavigator = Navigator.of(
                                  sheetContext,
                                );
                                final rootNavigator = Navigator.of(
                                  this.context,
                                  rootNavigator: true,
                                );
                                try {
                                  await ApiService.updateLead(
                                    leadId: widget.leadId,
                                    fields: fields,
                                  );
                                  if (!mounted) return;
                                  sheetNavigator.pop();
                                  _showProgress();
                                  await loadLead();
                                  if (!mounted) return;
                                  rootNavigator.pop();
                                  _message(
                                    'Lead updated in Salesforce successfully.',
                                  );
                                } catch (error) {
                                  setSheetState(() => saving = false);
                                  _message(
                                    'Salesforce update failed: $error',
                                    error: true,
                                  );
                                }
                              },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Map<String, dynamic> _changedSalesforceFields({
    required Map<String, TextEditingController> controllers,
    required Map<String, dynamic> current,
    required bool projectSubmitted,
    required bool appointmentCompleted,
  }) {
    final fields = <String, dynamic>{};

    final editedName = controllers['Name']!.text.trim();
    if (!_sameValue(editedName, current['Name'])) {
      final nameParts = editedName
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
      fields['LastName'] = nameParts.isEmpty ? null : nameParts.last;
      fields['FirstName'] = nameParts.length <= 1
          ? null
          : nameParts.sublist(0, nameParts.length - 1).join(' ');
    }

    for (final entry in controllers.entries) {
      if (entry.key == 'Name') continue;
      final value = _salesforceValue(
        entry.key,
        entry.value.text,
        current[entry.key],
      );
      if (!_sameValue(value, current[entry.key])) fields[entry.key] = value;
    }

    if (projectSubmitted != (current['Project_Request_Submitted__c'] == true)) {
      fields['Project_Request_Submitted__c'] = projectSubmitted;
    }
    if (appointmentCompleted != (current['Appointment_Completed__c'] == true)) {
      fields['Appointment_Completed__c'] = appointmentCompleted;
    }
    return fields;
  }

  bool _sameValue(dynamic first, dynamic second) {
    final firstText = first?.toString().trim() ?? '';
    final secondText = second?.toString().trim() ?? '';
    if (first is num || second is num) {
      final firstNumber = num.tryParse(firstText);
      final secondNumber = num.tryParse(secondText);
      if (firstNumber != null && secondNumber != null) {
        return firstNumber == secondNumber;
      }
    }
    return firstText == secondText;
  }

  dynamic _salesforceValue(String field, String raw, dynamic original) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (field == 'Customer_Budget__c') {
      return num.tryParse(value) ?? value;
    }
    if (original is int) return int.tryParse(value) ?? value;
    if (original is double) return double.tryParse(value) ?? value;
    if (original is num) return num.tryParse(value) ?? value;
    return value;
  }

  static String _text(dynamic value, {String empty = '—'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? empty : text;
  }

  String _initials() {
    final parts = _text(
      lead?['Name'],
      empty: '',
    ).split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2);
    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'AS' : initials;
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
                  colors: [
                    Color(0x08FFFFFF),
                    Color(0x70FCF8F2),
                    Color(0x20FCF8F2),
                  ],
                  stops: [0, 0.38, 1],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _gold),
                          )
                        : lead == null
                        ? _buildLoadError()
                        : RefreshIndicator(
                            color: _gold,
                            onRefresh: _refreshLead,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                              children: [
                                if (_leadLayoutSections.isNotEmpty)
                                  ..._leadLayoutSections.asMap().entries.map(
                                    (entry) => _layoutSection(
                                      entry.value,
                                      initiallyExpanded: entry.key == 0,
                                    ),
                                  )
                                else ...[
                                  _overviewSection(),
                                  _projectSection(),
                                  _supervisorSection(),
                                  _appointmentSection(),
                                ],
                                _actionsSection(),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Lead Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontFamily: 'serif',
                fontSize: 29,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _refreshing
              ? const SizedBox(
                  width: 50,
                  height: 50,
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _gold,
                    ),
                  ),
                )
              : _HeaderButton(icon: Icons.refresh_rounded, onTap: _refreshLead),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'Lead options',
            color: const Color(0xFFFFFBF6),
            onSelected: (value) {
              if (value == 'edit' && lead != null) _showEditLead();
              if (value == 'refresh') _refreshLead();
              if (value == 'reject') _rejectLead();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined, color: _gold),
                  title: Text('Edit Lead'),
                ),
              ),
              PopupMenuItem(
                value: 'reject',
                enabled: lead?['IsConverted'] != true,
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cancel_outlined, color: Colors.red),
                  title: Text('Reject Lead'),
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh_rounded, color: _gold),
                  title: Text('Refresh'),
                ),
              ),
            ],
            child: const _HeaderButtonSurface(icon: Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: _gold),
          const SizedBox(height: 12),
          const Text('Unable to load this lead'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => loading = true);
              loadLead();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _overviewSection() {
    return _DetailSection(
      title: 'Overview',
      icon: Icons.person_outline_rounded,
      initiallyExpanded: true,
      leading: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFF8E8CF), Color(0xFFEEC98F)],
          ),
          border: Border.all(color: const Color(0x44BF7A16)),
        ),
        child: Text(
          _initials(),
          style: const TextStyle(
            color: _ink,
            fontFamily: 'serif',
            fontSize: 27,
          ),
        ),
      ),
      rows: [
        _DetailData(Icons.person_outline, 'Lead Name', lead!['Name']),
        _DetailData(Icons.business_outlined, 'Company', lead!['Company']),
        _DetailData(Icons.phone_outlined, 'Phone', lead!['Phone']),
        _DetailData(Icons.email_outlined, 'Email', lead!['Email']),
        _DetailData(
          Icons.bookmark_border,
          'Lead Status',
          lead!['Status'],
          badge: true,
        ),
        _DetailData(
          Icons.person_pin_outlined,
          'Lead Owner',
          lead!['Owner']?['Name'],
        ),
        _DetailData(
          Icons.verified_user_outlined,
          'Approval Status',
          lead!['Approval_Status__c'],
          badge: true,
        ),
      ],
    );
  }

  String _normalizeSection(dynamic value) =>
      value.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<Map<String, dynamic>> get _leadLayoutSections {
    const orderedNames = [
      ['leadinformation'],
      ['projectinformation'],
      ['manualprojectrequest'],
      ['automaticprojectrequest'],
      ['sitevisitinformation', 'leadsitevisitinformation'],
      ['supervisorinformation'],
      ['appointmentinformation', 'sitevisitappointment'],
    ];
    final selected = <Map<String, dynamic>>[];
    for (final aliases in orderedNames) {
      for (final section in detailSections) {
        final title = _normalizeSection(section['title']);
        if (aliases.any(title.contains) && !selected.contains(section)) {
          selected.add(section);
        }
      }
    }
    return selected;
  }

  IconData _sectionIcon(String title) {
    final value = _normalizeSection(title);
    if (value.contains('appointment')) return Icons.calendar_month_outlined;
    if (value.contains('supervisor')) return Icons.supervisor_account_outlined;
    if (value.contains('sitevisit')) return Icons.location_on_outlined;
    if (value.contains('project')) return Icons.home_work_outlined;
    return Icons.person_outline_rounded;
  }

  IconData _fieldIcon(String label) {
    final value = _normalizeSection(label);
    if (value.contains('email')) return Icons.email_outlined;
    if (value.contains('phone') || value.contains('contact')) {
      return Icons.phone_outlined;
    }
    if (value.contains('date') || value.contains('time')) {
      return Icons.event_outlined;
    }
    if (value.contains('budget') || value.contains('amount')) {
      return Icons.currency_rupee_rounded;
    }
    if (value.contains('status') || value.contains('approval')) {
      return Icons.verified_outlined;
    }
    if (value.contains('location') || value.contains('address')) {
      return Icons.location_on_outlined;
    }
    return Icons.label_outline_rounded;
  }

  Widget _layoutSection(
    Map<String, dynamic> section, {
    bool initiallyExpanded = false,
  }) {
    final title = section['title']?.toString() ?? 'Information';
    final fields = section['fields'] as List<dynamic>? ?? const [];
    return _DetailSection(
      title: title,
      icon: _sectionIcon(title),
      initiallyExpanded: initiallyExpanded,
      rows: fields.map((raw) {
        final field = raw as Map<String, dynamic>;
        final label = field['label']?.toString() ?? '';
        final normalized = _normalizeSection(label);
        return _DetailData(
          _fieldIcon(label),
          label,
          field['value'],
          badge:
              normalized.contains('status') || normalized.contains('approval'),
        );
      }).toList(),
    );
  }

  Widget _projectSection() {
    return _DetailSection(
      title: 'Project Information',
      icon: Icons.folder_open_outlined,
      rows: [
        _DetailData(
          Icons.assignment_outlined,
          'Project Submitted',
          lead!['Project_Request_Submitted__c'] == true ? 'Yes' : 'No',
        ),
        _DetailData(
          Icons.currency_rupee,
          'Customer Budget',
          lead!['Customer_Budget__c'],
        ),
        _DetailData(
          Icons.location_on_outlined,
          'Site Location',
          lead!['Site_Location__c'],
        ),
        _DetailData(
          Icons.description_outlined,
          'Project Description',
          lead!['Project_Description__c'],
        ),
      ],
    );
  }

  Widget _supervisorSection() {
    return _DetailSection(
      title: 'Supervisor Information',
      icon: Icons.person_outline_rounded,
      rows: [
        _DetailData(
          Icons.person_outline,
          'Supervisor',
          lead!['Supervisor_User__r']?['Name'],
        ),
        _DetailData(
          Icons.email_outlined,
          'Supervisor Email',
          lead!['Supervisor_User_Email__c'],
        ),
        _DetailData(
          Icons.phone_outlined,
          'Supervisor Phone',
          lead!['Supervisor_User_Phone__c'],
        ),
      ],
    );
  }

  Widget _appointmentSection() {
    return _DetailSection(
      title: 'Appointment Information',
      icon: Icons.calendar_month_outlined,
      rows: [
        _DetailData(
          Icons.sell_outlined,
          'Appointment Type',
          lead!['Appointment_Confirmation_Type__c'],
        ),
        _DetailData(
          Icons.bookmark_border,
          'Appointment Status',
          lead!['Appointment_Status__c'],
          badge: true,
        ),
        _DetailData(
          Icons.calendar_today_outlined,
          'Appointment Sent Date',
          lead!['Appointment_Sent_date__c'],
        ),
        _DetailData(
          Icons.event_available_outlined,
          'Appointment Confirmed Date',
          lead!['Appointment_Date__c'],
        ),
        _DetailData(
          Icons.schedule_outlined,
          'Appointment Time Slot',
          lead!['Appointment_Time_Slots__c'],
        ),
        _DetailData(
          Icons.person_outline,
          'Appointment Confirmed',
          lead!['Appointment_Completed__c'] == true ? 'Yes' : 'No',
        ),
        _DetailData(
          Icons.event_repeat_outlined,
          'Rescheduled Date',
          lead!['Appointment_Rescheduled_Time__c'],
        ),
        _DetailData(
          Icons.update_outlined,
          'Rescheduled Time Slot',
          lead!['Time_Slots__c'],
        ),
      ],
    );
  }

  Future<void> _showConvertLeadNotice() async {
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x990E0B08),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF6),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x55BF7A16)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF7EEE1),
                    foregroundColor: const Color(0xFF7B5424),
                  ),
                ),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFF8E7CB), Color(0xFFEBC58A)],
                  ),
                ),
                child: const Icon(
                  Icons.sync_alt_rounded,
                  color: Color(0xFFBF7A16),
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Convert To Lead',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF251E18),
                  fontFamily: 'serif',
                  fontSize: 27,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please convert this Lead from the Salesforce Org.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6F6861),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Close'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFBF7A16),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

  Widget _actionsSection() {
    final wizardStep =
        num.tryParse(siteVisitReport?['Wizard_Step__c']?.toString() ?? '') ?? 0;
    final reportFinalized =
        siteVisitReport?['Is_Final_Submitted__c'] == true || wizardStep >= 3;
    final reportApproved = siteVisitReport?['Management_Approval__c'] == true;
    final appointmentStatus =
        lead?['Appointment_Status__c']?.toString().trim().toLowerCase() ?? '';
    const completedAppointmentStatuses = {
      'approved',
      'rescheduled',
      'appointment rescheduled',
      // Retain compatibility if this legacy misspelling exists in Salesforce.
      'appointement rescheduled',
    };
    final appointmentConfirmedValue = lead?['Appointment_Completed__c'];
    final appointmentConfirmed =
        appointmentConfirmedValue == true ||
        appointmentConfirmedValue?.toString().trim().toLowerCase() == 'yes' ||
        appointmentConfirmedValue?.toString().trim().toLowerCase() == 'true';
    final completion = <bool>[
      lead?['Approval_Status__c']?.toString().toLowerCase() == 'approved',
      lead?['Supervisor_User__c'] != null,
      completedAppointmentStatuses.contains(appointmentStatus) &&
          appointmentConfirmed,
      reportFinalized,
      reportApproved,
      lead?['IsConverted'] == true,
    ];
    final firstIncomplete = completion.indexWhere((done) => !done);
    final actions = <_WorkflowItem>[
      _WorkflowItem(
        label: 'Approve Lead',
        icon: Icons.check_circle_outline,
        onTap: _approveLead,
      ),
      _WorkflowItem(
        label: 'Assign Supervisor',
        icon: Icons.person_add_alt,
        onTap: _assignSupervisor,
      ),
      _WorkflowItem(
        label: 'Book Site Visit',
        icon: Icons.calendar_month_outlined,
        onTap: _bookSiteVisit,
      ),
      _WorkflowItem(
        label: 'Site Visit Report Data',
        icon: Icons.note_add_outlined,
        onTap: _openReportData,
      ),
      _WorkflowItem(
        label: 'Manager Approval',
        icon: Icons.admin_panel_settings_outlined,
        onTap: _openReportDetails,
      ),
      _WorkflowItem(
        label: 'Convert To Lead',
        icon: Icons.sync_alt_rounded,
        onTap: _showConvertLeadNotice,
      ),
    ];

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.fromLTRB(13, 16, 13, 8),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 14),
                child: Text(
                  'Lead Progress Pathway',
                  style: TextStyle(
                    color: Color(0xFF3D2B1B),
                    fontFamily: 'serif',
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              for (var index = 0; index < actions.length; index++)
                _WorkflowStepTile(
                  number: index + 1,
                  item: actions[index],
                  state: completion[index]
                      ? _WorkflowState.completed
                      : index == firstIncomplete
                      ? _WorkflowState.current
                      : _WorkflowState.upcoming,
                  isLast: index == actions.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _SiteVisitBooking {
  const _SiteVisitBooking({
    required this.type,
    required this.date,
    required this.slot,
  });

  final String type;
  final DateTime date;
  final String slot;
}

class _BookSiteVisitSheet extends StatefulWidget {
  const _BookSiteVisitSheet({
    required this.appointmentTypes,
    required this.timeSlots,
    required this.initialType,
    this.initialDate,
    this.initialSlot,
  });

  final List<String> appointmentTypes;
  final List<String> timeSlots;
  final String initialType;
  final DateTime? initialDate;
  final String? initialSlot;

  @override
  State<_BookSiteVisitSheet> createState() => _BookSiteVisitSheetState();
}

class _BookSiteVisitSheetState extends State<_BookSiteVisitSheet> {
  static const _gold = Color(0xFFBF7A16);
  late String selectedType;
  DateTime? selectedDate;
  String? selectedSlot;

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
    selectedDate = widget.initialDate;
    selectedSlot = widget.initialSlot;
  }

  String _displayDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool _slotHasPassed(DateTime date, String slot) {
    final matches = RegExp(
      r'(\d{1,2})\s*(AM|PM)',
      caseSensitive: false,
    ).allMatches(slot).toList();
    if (matches.isEmpty) return true;
    // A slot becomes unavailable as soon as it starts. For example, at
    // 1:15 PM the 1PM-2PM slot must no longer be offered.
    var hour = int.parse(matches.first.group(1)!);
    final period = matches.first.group(2)!.toUpperCase();
    if (hour == 12) hour = 0;
    if (period == 'PM') hour += 12;
    final start = DateTime(date.year, date.month, date.day, hour);
    return !start.isAfter(DateTime.now());
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final earliest = DateTime(now.year, now.month, now.day);
    final initial = selectedDate != null && !selectedDate!.isBefore(earliest)
        ? selectedDate!
        : earliest;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _gold,
            onPrimary: Colors.white,
            surface: Color(0xFFFFFBF6),
            onSurface: Color(0xFF29241F),
          ),
          datePickerTheme: const DatePickerThemeData(
            backgroundColor: Color(0xFFFFFBF6),
            headerBackgroundColor: Color(0xFFF5E3C7),
            headerForegroundColor: Color(0xFF392B1A),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) {
      setState(() {
        selectedDate = date;
        if (selectedSlot != null && _slotHasPassed(date, selectedSlot!)) {
          selectedSlot = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSlots = selectedDate == null
        ? widget.timeSlots
        : widget.timeSlots
              .where((slot) => !_slotHasPassed(selectedDate!, slot))
              .toList();
    final canSubmit =
        selectedDate != null &&
        selectedSlot != null &&
        !_slotHasPassed(selectedDate!, selectedSlot!);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBF6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8D3B5),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFF8E8CF),
                    child: Icon(
                      Icons.event_available_outlined,
                      color: _gold,
                      size: 29,
                    ),
                  ),
                  SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      'Book Site Visit',
                      style: TextStyle(
                        color: Color(0xFF211C17),
                        fontFamily: 'serif',
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Schedule a visit for this lead',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF716A63), fontSize: 15),
              ),
              const SizedBox(height: 26),
              _BookingLabel('Appointment Type'),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _gold,
                ),
                dropdownColor: const Color(0xFFFFFBF6),
                borderRadius: BorderRadius.circular(16),
                decoration: _bookingDecoration(),
                items: widget.appointmentTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedType = value);
                },
              ),
              const SizedBox(height: 18),
              _BookingLabel('Appointment Date'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(15),
                child: InputDecorator(
                  decoration: _bookingDecoration(
                    suffixIcon: const Icon(
                      Icons.calendar_month_outlined,
                      color: _gold,
                    ),
                  ),
                  child: Text(
                    selectedDate == null
                        ? 'Select date'
                        : _displayDate(selectedDate!),
                    style: TextStyle(
                      color: selectedDate == null
                          ? const Color(0xFF9A958F)
                          : const Color(0xFF292622),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _BookingLabel('Time Slot'),
              DropdownButtonFormField<String>(
                initialValue: selectedSlot,
                hint: const Text('Select time slot'),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _gold,
                ),
                dropdownColor: const Color(0xFFFFFBF6),
                borderRadius: BorderRadius.circular(16),
                decoration: _bookingDecoration(),
                items: availableSlots
                    .map(
                      (slot) =>
                          DropdownMenuItem(value: slot, child: Text(slot)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => selectedSlot = value),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _gold,
                          fontFamily: 'serif',
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: canSubmit
                            ? const LinearGradient(
                                colors: [Color(0xFFE2A12E), Color(0xFFBE7610)],
                              )
                            : null,
                        color: canSubmit ? null : const Color(0xFFD8D1C9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: canSubmit
                            ? const [
                                BoxShadow(
                                  color: Color(0x336F430C),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton.icon(
                        onPressed: canSubmit
                            ? () => Navigator.pop(
                                context,
                                _SiteVisitBooking(
                                  type: selectedType,
                                  date: selectedDate!,
                                  slot: selectedSlot!,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text(
                          'Book Site Visit',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white70,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
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
  }

  InputDecoration _bookingDecoration({Widget? suffixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xBFFFFFFF),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFCE9138)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _gold, width: 1.5),
      ),
    );
  }
}

class _BookingLabel extends StatelessWidget {
  const _BookingLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 7),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF7B4F19),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SupervisorPickerSheet extends StatefulWidget {
  const _SupervisorPickerSheet({
    required this.supervisors,
    this.currentSupervisorId,
  });

  final List<dynamic> supervisors;
  final String? currentSupervisorId;

  @override
  State<_SupervisorPickerSheet> createState() => _SupervisorPickerSheetState();
}

class _SupervisorPickerSheetState extends State<_SupervisorPickerSheet> {
  static const _gold = Color(0xFFBF7A16);
  dynamic selectedUser;

  @override
  void initState() {
    super.initState();
    if (widget.supervisors.isEmpty) return;
    for (final user in widget.supervisors) {
      if (user['Id']?.toString() == widget.currentSupervisorId) {
        selectedUser = user;
        return;
      }
    }
    selectedUser = widget.supervisors.first;
  }

  String _initials(dynamic user) {
    final name = user['Name']?.toString().trim() ?? '';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'AS' : initials;
  }

  String _subtitle(dynamic user) {
    final role = user['UserRole']?['Name']?.toString().trim() ?? '';
    if (role.isNotEmpty) return role;
    final name = user['Name']?.toString().toLowerCase() ?? '';
    return name.contains('llc')
        ? 'Organization Supervisor'
        : 'Individual Supervisor';
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.76;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        22 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE8D3B5),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: Color(0xFFF8E8CF),
                child: Icon(
                  Icons.person_add_alt_1_outlined,
                  color: _gold,
                  size: 28,
                ),
              ),
              SizedBox(width: 14),
              Flexible(
                child: Text(
                  'Assign Supervisor',
                  style: TextStyle(
                    color: Color(0xFF211C17),
                    fontFamily: 'serif',
                    fontSize: 27,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a supervisor to assign this lead',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF716A63), fontSize: 15),
          ),
          const SizedBox(height: 24),
          if (widget.supervisors.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    color: Color(0xFFBF7A16),
                    size: 42,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No active supervisors found',
                    style: TextStyle(
                      color: Color(0xFF4E4842),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.supervisors.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = widget.supervisors[index];
                  final selected = selectedUser?['Id'] == user['Id'];
                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => setState(() => selectedUser = user),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFFFFCF7)
                              : const Color(0x99FFFFFF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? _gold : const Color(0x44BF7A16),
                            width: selected ? 1.4 : 1,
                          ),
                          boxShadow: selected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x146B4718),
                                    blurRadius: 15,
                                    offset: Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFF8E8CE),
                                    Color(0xFFEFC98C),
                                  ],
                                ),
                              ),
                              child: Text(
                                _initials(user),
                                style: const TextStyle(
                                  color: Color(0xFF30271D),
                                  fontFamily: 'serif',
                                  fontSize: 21,
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['Name'] ?? 'Unnamed supervisor',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF292622),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _subtitle(user),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF77716A),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? _gold : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? _gold
                                      : const Color(0xFFAA7D3C),
                                  width: 1.5,
                                ),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 57,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: selectedUser == null
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFE3A12E), Color(0xFFBE7610)],
                      ),
                color: selectedUser == null ? const Color(0xFFD8D1C9) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: selectedUser == null
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x336F430C),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
              ),
              child: ElevatedButton.icon(
                onPressed: selectedUser == null
                    ? null
                    : () => Navigator.pop(context, selectedUser),
                icon: const Icon(Icons.person_add_alt, size: 24),
                label: const Text(
                  'Confirm Assignment',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _gold, fontFamily: 'serif', fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailData {
  const _DetailData(this.icon, this.label, this.value, {this.badge = false});

  final IconData icon;
  final String label;
  final dynamic value;
  final bool badge;
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.rows,
    this.leading,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final List<_DetailData> rows;
  final Widget? leading;
  final bool initiallyExpanded;

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFFF8F0E5),
          child: Icon(icon, color: const Color(0xFFBF7A16), size: 25),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF211C17),
            fontFamily: 'serif',
            fontSize: 23,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text('${rows.length} details'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: const Color(0x8AFFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x33BF7A16)),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < rows.length; index++)
                        _DetailRow(
                          data: rows[index],
                          value: _value(rows[index].value),
                          showDivider: index != rows.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.data,
    required this.value,
    required this.showDivider,
  });

  final _DetailData data;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0x14000000)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: const Color(0xFFBF7A16), size: 19),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              data.label,
              style: const TextStyle(
                color: Color(0xFF77716B),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: data.badge && value != '—'
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: _ValueBadge(value: value),
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF292622),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ValueBadge extends StatelessWidget {
  const _ValueBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final positive = [
      'new',
      'approved',
      'qualified',
      'completed',
    ].contains(value.toLowerCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFE3F3E0) : const Color(0xFFF9EEDB),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: positive ? const Color(0xFFCBE7C6) : const Color(0xFFF0D9B4),
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: positive ? const Color(0xFF238435) : const Color(0xFFA35D08),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

enum _WorkflowState { completed, current, upcoming }

class _WorkflowItem {
  const _WorkflowItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _WorkflowStepTile extends StatelessWidget {
  const _WorkflowStepTile({
    required this.number,
    required this.item,
    required this.state,
    required this.isLast,
  });

  final int number;
  final _WorkflowItem item;
  final _WorkflowState state;
  final bool isLast;

  Color get _accent => switch (state) {
    _WorkflowState.completed => const Color(0xFF4D8B2C),
    _WorkflowState.current => const Color(0xFFC8780B),
    _WorkflowState.upcoming => const Color(0xFF746E67),
  };

  Color get _softColor => switch (state) {
    _WorkflowState.completed => const Color(0xFFF0F7EA),
    _WorkflowState.current => const Color(0xFFFFF4E3),
    _WorkflowState.upcoming => const Color(0xFFF7F4F0),
  };

  String get _status => switch (state) {
    _WorkflowState.completed => 'Completed',
    _WorkflowState.current => 'In Progress',
    _WorkflowState.upcoming => 'Upcoming',
  };

  IconData get _statusIcon => switch (state) {
    _WorkflowState.completed => Icons.check_circle,
    _WorkflowState.current => Icons.pending_outlined,
    _WorkflowState.upcoming => Icons.schedule_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state == _WorkflowState.upcoming
                        ? const Color(0xFFFFFCF8)
                        : _accent,
                    border: Border.all(color: _accent, width: 1.5),
                    boxShadow: state == _WorkflowState.current
                        ? const [
                            BoxShadow(
                              color: Color(0x55C8780B),
                              blurRadius: 13,
                              spreadRadius: 2,
                            ),
                          ]
                        : const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 7,
                              offset: Offset(0, 3),
                            ),
                          ],
                  ),
                  child: state == _WorkflowState.completed
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : Text(
                          '$number',
                          style: TextStyle(
                            color: state == _WorkflowState.upcoming
                                ? _accent
                                : Colors.white,
                            fontFamily: 'serif',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: state == _WorkflowState.completed
                          ? const Color(0xFF71A954)
                          : state == _WorkflowState.current
                          ? const Color(0xFFD7902D)
                          : const Color(0xFFD5CEC5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(17),
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(17),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    constraints: const BoxConstraints(minHeight: 76),
                    padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                    decoration: BoxDecoration(
                      color: const Color(0xEFFFFFFF),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: state == _WorkflowState.upcoming
                            ? const Color(0x44A99D90)
                            : _accent.withValues(alpha: 0.42),
                        width: state == _WorkflowState.current ? 1.4 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(
                            alpha: state == _WorkflowState.current
                                ? 0.17
                                : 0.08,
                          ),
                          blurRadius: 13,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _softColor,
                            border: Border.all(
                              color: _accent.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Icon(item.icon, color: _accent, size: 24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF2A241F),
                              fontFamily: 'serif',
                              fontSize: 17,
                              fontWeight: state == _WorkflowState.current
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _softColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon, color: _accent, size: 15),
                              const SizedBox(width: 4),
                              Text(
                                _status,
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: _accent,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: _HeaderButtonSurface(icon: icon),
      ),
    );
  }
}

class _HeaderButtonSurface extends StatelessWidget {
  const _HeaderButtonSurface({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x55BF7A16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: const Color(0xFFBF7A16), size: 28),
    );
  }
}

class _EditHeading extends StatelessWidget {
  const _EditHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFBF7A16),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.label,
    this.required = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? '$label is required'
                  : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x44BF7A16)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFBF7A16)),
          ),
        ),
      ),
    );
  }
}

class _LockedEditNote extends StatelessWidget {
  const _LockedEditNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EFE3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFBF7A16), size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6D655C),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: const Color(0xEFFFFFFF),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0x55BF7A16)),
    boxShadow: const [
      BoxShadow(color: Color(0x126B4B20), blurRadius: 20, offset: Offset(0, 7)),
    ],
  );
}
