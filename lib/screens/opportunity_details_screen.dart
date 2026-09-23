import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

class OpportunityDetailsScreen extends StatefulWidget {
  const OpportunityDetailsScreen({super.key, required this.opportunityId});

  final String opportunityId;

  @override
  State<OpportunityDetailsScreen> createState() =>
      _OpportunityDetailsScreenState();
}

class _OpportunityDetailsScreenState extends State<OpportunityDetailsScreen> {
  static const _gold = Color(0xFFBF7A16);
  bool loading = true;
  bool _refreshing = false;
  String? error;
  Map<String, dynamic>? opportunity;
  List<Map<String, dynamic>> architectureSubmissions = [];
  List<Map<String, dynamic>> proformaSubmissions = [];
  Map<String, dynamic>? budgetReview;
  Map<String, dynamic>? paymentTerms;
  Map<String, bool> workflowStages = {};
  List<Map<String, dynamic>> detailSections = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final initialLoad = opportunity == null;
    setState(() {
      loading = initialLoad;
      error = null;
    });
    try {
      Future<T?> optional<T>(Future<T> request) async {
        try {
          return await request;
        } catch (_) {
          return null;
        }
      }

      // These resources are independent. Fetching them concurrently avoids
      // stacking several Salesforce round trips during every screen refresh.
      final responses = await Future.wait<dynamic>([
        ApiService.getOpportunity(widget.opportunityId),
        optional(
          ApiService.getArchitectureDesignSubmissions(widget.opportunityId),
        ),
        optional(
          ApiService.getProformaInvoiceSubmissions(widget.opportunityId),
        ),
        optional(ApiService.getBudgetReview(widget.opportunityId)),
        optional(ApiService.getPaymentTerms(widget.opportunityId)),
        optional(ApiService.getOpportunityWorkflowStages(widget.opportunityId)),
        optional(
          ApiService.getRecordDetailSections(
            recordId: widget.opportunityId,
            objectApiName: 'Opportunity',
          ),
        ),
      ]);
      final result = responses[0] as Map<String, dynamic>;
      final submissions =
          responses[1] as List<Map<String, dynamic>>? ?? const [];
      final invoices = responses[2] as List<Map<String, dynamic>>? ?? const [];
      final review = responses[3] as Map<String, dynamic>?;
      final terms = responses[4] as Map<String, dynamic>?;
      final stages = responses[5] as Map<String, bool>? ?? const {};
      final loadedSections =
          responses[6] as List<Map<String, dynamic>>? ?? const [];
      if (!mounted) return;
      setState(() {
        opportunity = result;
        architectureSubmissions = submissions;
        proformaSubmissions = invoices;
        budgetReview = review;
        paymentTerms = terms;
        workflowStages = stages;
        detailSections = loadedSections;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = exception.toString();
      });
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _load();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _refreshWorkflowStages() async {
    try {
      final stages = await ApiService.getOpportunityWorkflowStages(
        widget.opportunityId,
      );
      if (!mounted) return;
      setState(() => workflowStages = stages);
    } catch (_) {
      // Keep the last known stage state if Salesforce is temporarily unavailable.
    }
  }

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(_value(value));
    if (date == null) return _value(value);
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

  String _amount(dynamic value) {
    final number = num.tryParse(_value(value));
    if (number == null) return '—';
    final whole = number.round().toString();
    final reversed = whole.split('').reversed.toList();
    final groups = <String>[];
    for (var index = 0; index < reversed.length; index += 3) {
      final end = index + 3 > reversed.length ? reversed.length : index + 3;
      groups.add(reversed.sublist(index, end).reversed.join());
    }
    return '₹${groups.reversed.join(',')}';
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
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _gold),
                          )
                        : error != null
                        ? _errorState()
                        : RefreshIndicator(
                            color: _gold,
                            onRefresh: _refresh,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                              children: [
                                _heroCard(),
                                if (_opportunityLayoutSections.isNotEmpty)
                                  ..._opportunityLayoutSections
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => _layoutSection(
                                          entry.value,
                                          initiallyExpanded: entry.key == 0,
                                        ),
                                      )
                                else
                                  ..._fallbackDetailSections(),
                                _opportunityPathway(),
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
            'Opportunity Details',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF251E18),
              fontFamily: 'serif',
              fontSize: 27,
            ),
          ),
        ),
        Material(
          color: const Color(0xEFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          child: IconButton(
            tooltip: 'Reload opportunity',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _gold,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: _gold),
          ),
        ),
      ],
    ),
  );

  Widget _heroCard() {
    final stage = _value(opportunity!['StageName']);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFF8E7CB), Color(0xFFEBC58A)],
              ),
            ),
            child: const Icon(Icons.show_chart_rounded, color: _gold, size: 34),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _value(opportunity!['Name']),
                  style: const TextStyle(
                    color: Color(0xFF27221D),
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _value(opportunity!['Account']?['Name']),
                  style: const TextStyle(color: Color(0xFF77716A)),
                ),
                const SizedBox(height: 10),
                _StageBadge(stage: stage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeSection(dynamic value) =>
      value.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<Map<String, dynamic>> get _opportunityLayoutSections {
    const orderedNames = [
      ['opportunitydetails', 'opportunityinformation'],
      ['architectureinformation'],
      ['budgetdetails'],
      ['catalogueinformation'],
      ['paymentinformation'],
      ['leadinformation'],
      ['projectinformation'],
      ['manualprojectrequest'],
      ['automaticprojectrequest'],
      ['supervisorinformation'],
      ['leadsitevisitappointment'],
      ['leadsitevisitinformation'],
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

  IconData _layoutIcon(String title) {
    final value = _normalizeSection(title);
    if (value.contains('architect')) return Icons.architecture_outlined;
    if (value.contains('budget') || value.contains('payment')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (value.contains('catalogue')) return Icons.collections_bookmark_outlined;
    if (value.contains('appointment')) return Icons.calendar_month_outlined;
    if (value.contains('sitevisit')) return Icons.location_on_outlined;
    if (value.contains('supervisor')) return Icons.supervisor_account_outlined;
    if (value.contains('project')) return Icons.home_work_outlined;
    if (value.contains('lead')) return Icons.person_outline_rounded;
    return Icons.trending_up_rounded;
  }

  Widget _layoutSection(
    Map<String, dynamic> section, {
    bool initiallyExpanded = false,
  }) {
    final title = section['title']?.toString() ?? 'Information';
    final fields = section['fields'] as List<dynamic>? ?? const [];
    return _DetailSection(
      title: title,
      icon: _layoutIcon(title),
      initiallyExpanded: initiallyExpanded,
      rows: fields.map((raw) {
        final field = raw as Map<String, dynamic>;
        final label = field['label']?.toString() ?? '';
        final normalized = _normalizeSection(label);
        return _Datum(
          label,
          field['value'],
          badge:
              normalized.contains('status') ||
              normalized.contains('approval') ||
              normalized == 'stage',
        );
      }).toList(),
    );
  }

  List<Widget> _fallbackDetailSections() => [
    _DetailSection(
      title: 'Opportunity Details',
      icon: Icons.trending_up_rounded,
      initiallyExpanded: true,
      rows: [
        _Datum('Opportunity Name', opportunity!['Name']),
        _Datum('Account', opportunity!['Account']?['Name']),
        _Datum('Owner', opportunity!['Owner']?['Name']),
        _Datum('Stage', opportunity!['StageName'], badge: true),
        _Datum('Amount', _amount(opportunity!['Amount'])),
        _Datum('Probability', '${_value(opportunity!['Probability'])}%'),
        _Datum('Close Date', _date(opportunity!['CloseDate'])),
        _Datum('Description', opportunity!['Description']),
      ],
    ),
  ];

  bool _hasValue(dynamic value) =>
      value != null && value.toString().trim().isNotEmpty;

  Future<void> _openArchitectInformation() async {
    final result = await showModalBottomSheet<_ArchitectInformation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990E0B08),
      builder: (_) => _ArchitectInformationSheet(
        initialName: opportunity?['Architect_Name__c']?.toString() ?? '',
        initialEmail: opportunity?['Architect_Email__c']?.toString() ?? '',
        initialPhone:
            opportunity?['Architect_Contact_Number__c']?.toString() ?? '',
      ),
    );
    if (result == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _gold)),
    );
    try {
      await ApiService.updateOpportunityArchitectInformation(
        opportunityId: widget.opportunityId,
        architectName: result.name,
        architectEmail: result.email,
        architectContactNumber: result.phone,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Architect information saved to Salesforce.'),
          backgroundColor: Color(0xFF2D873B),
        ),
      );
    } catch (exception) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save architect information: $exception'),
          backgroundColor: const Color(0xFFC43C34),
        ),
      );
    }
  }

  Future<void> _openArchitectureDesign() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990E0B08),
      builder: (_) => _ArchitectureDesignSheet(
        opportunityId: widget.opportunityId,
        initialSubmissions: architectureSubmissions,
      ),
    );
    if (mounted && changed == true) await _load();
  }

  Future<void> _openProformaInvoice() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990E0B08),
      builder: (_) => _ProformaInvoiceSheet(
        opportunityId: widget.opportunityId,
        initialSubmissions: proformaSubmissions,
      ),
    );
    if (mounted && changed == true) await _load();
  }

  Future<void> _openBudgetReview() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990E0B08),
      builder: (_) => _BudgetReviewSheet(
        opportunityId: widget.opportunityId,
        initialData: budgetReview,
      ),
    );
    if (mounted && changed == true) await _load();
  }

  Future<void> _openPaymentTerms() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990E0B08),
      builder: (_) => _PaymentTermsSheet(
        opportunityId: widget.opportunityId,
        initialData: paymentTerms,
      ),
    );
    if (mounted && changed == true) await _load();
  }

  Future<void> _showSalesforceOrgInstruction(String action) async {
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x990E0B08),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFF8E7CB),
              foregroundColor: _gold,
              child: Icon(Icons.cloud_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(action)),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: Text(
          'Please complete the $action functionality directly from the '
          'Salesforce Org. Once it is completed successfully, this stage will '
          'automatically update in the mobile app after refresh.',
          style: const TextStyle(fontSize: 16, height: 1.45),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (mounted) await _refreshWorkflowStages();
  }

  Widget _opportunityPathway() {
    final architectComplete =
        _hasValue(opportunity?['Architect_Name__c']) &&
        _hasValue(opportunity?['Architect_Email__c']) &&
        _hasValue(opportunity?['Architect_Contact_Number__c']);
    bool clientApproved(dynamic value) {
      if (value == true) return true;
      final status = value?.toString().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      return status != null &&
          status.contains('approved') &&
          !status.contains('notapproved') &&
          !status.contains('request');
    }

    String normalizedStatus(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    bool changesRequested(dynamic value) {
      final status = normalizedStatus(value);
      return status.contains('request') ||
          status.contains('change') ||
          status.contains('negoti') ||
          status.contains('reject');
    }

    final latestArchitecture = architectureSubmissions.isEmpty
        ? null
        : architectureSubmissions.first;
    final architectureStatus = latestArchitecture?['_status'];
    final architectureHasFiles =
        (latestArchitecture?['_files'] as List<dynamic>? ?? const [])
            .isNotEmpty;
    final architectureChanges = changesRequested(architectureStatus);
    final architectureSent = architectureHasFiles && !architectureChanges;
    final architectureClientApproved = clientApproved(architectureStatus);
    final architectureManagerApproved =
        latestArchitecture?['_managerApproval'] == true;

    final latestProforma = proformaSubmissions.isEmpty
        ? null
        : proformaSubmissions.first;
    final proformaStatus = latestProforma?['_clientStatus'];
    final proformaHasFiles =
        (latestProforma?['_files'] as List<dynamic>? ?? const []).isNotEmpty;
    final proformaChanges = changesRequested(proformaStatus);
    final proformaUploaded = proformaHasFiles && !proformaChanges;
    final proformaClientApproved = clientApproved(proformaStatus);
    final proformaManagerApproved = latestProforma?['_managerApproval'] == true;
    final budgetApproval =
        (budgetReview?['budgetReviewStatus'] ?? budgetReview?['clientApproval'])
            ?.toString()
            .trim()
            .toLowerCase();
    final budgetSubmitted =
        budgetReview?['clientApprovalSent'] == true ||
        clientApproved(budgetReview?['clientApproval']) ||
        clientApproved(budgetReview?['managerApproval']) ||
        budgetApproval == 'sent for client approval' ||
        budgetApproval == 'client approved' ||
        budgetApproval == 'client requested changes' ||
        budgetApproval == 'manager approved' ||
        budgetApproval == 'manager requested changes';
    final budgetClientStatus = budgetReview?['clientApproval'];
    final budgetManagerStatus = budgetReview?['managerApproval'];
    final budgetClientApproved =
        clientApproved(budgetClientStatus) ||
        budgetApproval == 'client approved' ||
        budgetApproval == 'manager approved';
    final budgetManagerApproved =
        clientApproved(budgetManagerStatus) ||
        budgetApproval == 'manager approved';
    final budgetClientChanges =
        changesRequested(budgetClientStatus) ||
        budgetApproval == 'client requested changes';
    final budgetManagerChanges =
        changesRequested(budgetManagerStatus) ||
        budgetApproval == 'manager requested changes';
    final paymentStatus = paymentTerms?['approval'];
    final paymentManagerStatus = paymentTerms?['managerApproval'];
    final paymentClientStatus = paymentTerms?['clientApproval'];
    final normalizedPaymentStatus = normalizedStatus(paymentStatus);
    // The boolean field in this org means "submitted", not "approved".
    // Only an explicit Salesforce approval-status value completes this stage.
    final paymentApproved =
        clientApproved(paymentManagerStatus) ||
        (paymentStatus is! bool && clientApproved(paymentStatus));
    final paymentSubmitted =
        paymentStatus == true ||
        normalizedPaymentStatus.contains('submit') ||
        normalizedPaymentStatus.contains('pending') ||
        normalizedPaymentStatus.contains('managerapproval') ||
        paymentApproved;
    // Salesforce orgs may expose the whole Payment Terms workflow through the
    // status field rather than a separate client-approval field. Read both so
    // the final client approval advances to Send Client Agreement.
    final paymentClientApproved =
        clientApproved(paymentClientStatus) ||
        (normalizedPaymentStatus.contains('client') &&
            clientApproved(paymentStatus));
    final paymentClientChanges =
        changesRequested(paymentClientStatus) ||
        (normalizedPaymentStatus.contains('client') &&
            changesRequested(paymentStatus));
    final clientAgreementCompleted =
        workflowStages['clientAgreement'] == true ||
        workflowStages['tenderInvitation'] == true ||
        workflowStages['vendorOpportunity'] == true ||
        workflowStages['vendorAgreement'] == true ||
        workflowStages['convertToProject'] == true;
    final effectivePaymentClientApproved =
        paymentClientApproved || clientAgreementCompleted;
    // Client-requested terms must pass through manager approval again.
    final paymentManagerApproved = paymentApproved && !paymentClientChanges;
    final items = <_OpportunityWorkflowItem>[
      _OpportunityWorkflowItem(
        'Architect Information',
        Icons.person_pin_outlined,
        onTap: _openArchitectInformation,
      ),
      _OpportunityWorkflowItem(
        'Upload Architecture Design',
        Icons.architecture_outlined,
        onTap: _openArchitectureDesign,
      ),
      _OpportunityWorkflowItem(
        'Send Architecture Client Approval',
        Icons.send_outlined,
        statusLabel: architectureChanges
            ? 'Changes Requested'
            : architectureSent
            ? 'Sent'
            : null,
      ),
      _OpportunityWorkflowItem(
        'Client Architecture Approval',
        Icons.how_to_reg_outlined,
        statusLabel: architectureChanges ? 'Changes Requested' : null,
      ),
      const _OpportunityWorkflowItem(
        'Architecture Manager Approval',
        Icons.admin_panel_settings_outlined,
      ),
      _OpportunityWorkflowItem(
        'Upload Proforma Invoice',
        Icons.upload_file_outlined,
        onTap: _openProformaInvoice,
      ),
      _OpportunityWorkflowItem(
        'Proforma Client Approval',
        Icons.fact_check_outlined,
        statusLabel: proformaChanges ? 'Changes Requested' : null,
      ),
      const _OpportunityWorkflowItem(
        'Proforma Manager Approval',
        Icons.admin_panel_settings_outlined,
      ),
      _OpportunityWorkflowItem(
        'Budget Review',
        Icons.account_balance_wallet_outlined,
        onTap: _openBudgetReview,
      ),
      _OpportunityWorkflowItem(
        'Budget Review Client Approval',
        Icons.how_to_reg_outlined,
        statusLabel: budgetClientChanges ? 'Changes Requested' : null,
        forceInProgress:
            budgetSubmitted && !budgetClientApproved && !budgetClientChanges,
      ),
      _OpportunityWorkflowItem(
        'Budget Review Manager Approval',
        Icons.admin_panel_settings_outlined,
        statusLabel: budgetManagerChanges ? 'Changes Requested' : null,
        forceInProgress:
            budgetClientApproved &&
            !budgetManagerApproved &&
            !budgetManagerChanges,
      ),
      _OpportunityWorkflowItem(
        'Payment Terms Manager Approval',
        Icons.receipt_long_outlined,
        onTap: _openPaymentTerms,
        statusLabel: changesRequested(paymentStatus) || paymentClientChanges
            ? 'Changes Requested'
            : null,
        forceInProgress:
            (paymentSubmitted && !paymentManagerApproved) ||
            paymentClientChanges,
      ),
      _OpportunityWorkflowItem(
        'Payment Terms Client Approval',
        Icons.how_to_reg_outlined,
        statusLabel: paymentClientChanges ? 'Changes Requested' : null,
        forceInProgress:
            paymentManagerApproved &&
            !effectivePaymentClientApproved &&
            !paymentClientChanges,
      ),
      _OpportunityWorkflowItem(
        'Send Client Agreement',
        Icons.handshake_outlined,
        onTap: () => _showSalesforceOrgInstruction('Send Client Agreement'),
      ),
      _OpportunityWorkflowItem(
        'Tender Invitation',
        Icons.campaign_outlined,
        onTap: () => _showSalesforceOrgInstruction('Tender Invitation'),
      ),
      _OpportunityWorkflowItem(
        'Vendor Opportunity',
        Icons.storefront_outlined,
        onTap: () => _showSalesforceOrgInstruction('Vendor Opportunity'),
      ),
      const _OpportunityWorkflowItem(
        'Vendor Agreement',
        Icons.verified_user_outlined,
      ),
      _OpportunityWorkflowItem(
        'Convert To Project',
        Icons.swap_horiz_rounded,
        onTap: () => _showSalesforceOrgInstruction('Convert To Project'),
      ),
    ];
    final completion = <bool>[
      architectComplete,
      architectureSent,
      architectureSent,
      architectureClientApproved,
      architectureManagerApproved,
      proformaUploaded,
      proformaClientApproved,
      proformaManagerApproved,
      budgetSubmitted,
      budgetClientApproved,
      budgetManagerApproved,
      paymentManagerApproved,
      effectivePaymentClientApproved,
      clientAgreementCompleted,
      workflowStages['tenderInvitation'] == true,
      workflowStages['vendorOpportunity'] == true,
      workflowStages['vendorAgreement'] == true,
      workflowStages['convertToProject'] == true,
    ];
    const optionalIndexes = <int>{};
    var firstIncomplete = -1;
    for (var index = 0; index < completion.length; index++) {
      if (!optionalIndexes.contains(index) && !completion[index]) {
        firstIncomplete = index;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 19, 12, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Opportunity Progress Pathway',
            style: TextStyle(
              color: Color(0xFF3D2B1B),
              fontFamily: 'serif',
              fontSize: 23,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Complete each stage to unlock the next step.',
            style: TextStyle(color: Color(0xFF77716A)),
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < items.length; index++)
            _OpportunityPathwayTile(
              number: index + 1,
              item: items[index],
              state: optionalIndexes.contains(index)
                  ? _PathwayState.optional
                  : completion[index]
                  ? _PathwayState.completed
                  : items[index].forceInProgress
                  ? _PathwayState.inProgress
                  : index == firstIncomplete
                  ? _PathwayState.inProgress
                  : _PathwayState.upcoming,
              isLast: index == items.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _errorState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, color: _gold, size: 50),
        const SizedBox(height: 12),
        const Text('Unable to load opportunity'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

enum _PathwayState { completed, inProgress, upcoming, optional }

class _OpportunityWorkflowItem {
  const _OpportunityWorkflowItem(
    this.label,
    this.icon, {
    this.onTap,
    this.statusLabel,
    this.forceInProgress = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final String? statusLabel;
  final bool forceInProgress;
}

class _OpportunityPathwayTile extends StatelessWidget {
  const _OpportunityPathwayTile({
    required this.number,
    required this.item,
    required this.state,
    required this.isLast,
  });

  final int number;
  final _OpportunityWorkflowItem item;
  final _PathwayState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final completed = state == _PathwayState.completed;
    final active = state == _PathwayState.inProgress;
    final optional = state == _PathwayState.optional;
    final color = completed
        ? const Color(0xFF4B962F)
        : active
        ? const Color(0xFFBF7A16)
        : optional
        ? const Color(0xFF7B6B91)
        : const Color(0xFF817A73);
    final stateLabel = completed
        ? 'Completed'
        : item.statusLabel != null
        ? item.statusLabel!
        : active
        ? 'In Progress'
        : optional
        ? 'Optional'
        : 'Upcoming';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed || active ? color : Colors.white,
                    border: Border.all(color: color.withValues(alpha: 0.45)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x196B4B20), blurRadius: 8),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: completed
                      ? const Icon(Icons.check, size: 21, color: Colors.white)
                      : Text(
                          '$number',
                          style: TextStyle(
                            color: active ? Colors.white : color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: completed
                          ? const Color(0xFF75A95F)
                          : const Color(0xFFD9D2CB),
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
                color: active
                    ? const Color(0xFFFFF9EF)
                    : const Color(0xF7FFFFFF),
                borderRadius: BorderRadius.circular(17),
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(17),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 82),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D6B4B20),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: color.withValues(alpha: 0.09),
                          child: Icon(item.icon, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: const Color(0xFF29231E),
                                  fontFamily: 'serif',
                                  fontSize: 17,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.24),
                                  ),
                                ),
                                child: Text(
                                  stateLabel,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.onTap != null) ...[
                          const SizedBox(width: 5),
                          Icon(Icons.chevron_right_rounded, color: color),
                        ],
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

class _ArchitectureDesignSheet extends StatefulWidget {
  const _ArchitectureDesignSheet({
    required this.opportunityId,
    required this.initialSubmissions,
  });
  final String opportunityId;
  final List<Map<String, dynamic>> initialSubmissions;

  @override
  State<_ArchitectureDesignSheet> createState() =>
      _ArchitectureDesignSheetState();
}

class _ArchitectureDesignSheetState extends State<_ArchitectureDesignSheet> {
  static const _gold = Color(0xFFBF7A16);
  final List<PlatformFile> _selectedFiles = [];
  final _amountController = TextEditingController();
  late List<Map<String, dynamic>> _submissions;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _submissions = List<Map<String, dynamic>>.from(widget.initialSubmissions);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    final usable = result.files.where((file) => file.path != null);
    setState(() {
      _selectedFiles.addAll(usable);
      _error = null;
    });
  }

  Future<void> _upload() async {
    final amount = num.tryParse(
      _amountController.text.replaceAll(',', '').trim(),
    );
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid architecture design amount.');
      return;
    }
    if (_selectedFiles.isEmpty) {
      setState(() => _error = 'Select at least one design file.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ApiService.uploadArchitectureDesign(
        opportunityId: widget.opportunityId,
        amount: amount,
        files: _selectedFiles.map((item) => File(item.path!)).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Architecture design submitted to Salesforce.'),
          backgroundColor: Color(0xFF2D873B),
        ),
      );
      Navigator.pop(context, true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _size(dynamic bytes) {
    final value = num.tryParse(bytes?.toString() ?? '') ?? 0;
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(value / 1024).toStringAsFixed(0)} KB';
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return value?.toString() ?? '—';
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  void _close() => Navigator.pop(context, false);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.94,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9D6B8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 27,
                        backgroundColor: Color(0xFFF8E7CB),
                        child: Icon(Icons.architecture_outlined, color: _gold),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Architecture Design Submission',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 22,
                                color: Color(0xFF302218),
                              ),
                            ),
                            Text(
                              'Upload the complete package for client approval.',
                              style: TextStyle(color: Color(0xFF77716A)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _uploading ? null : _close,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x22BF7A16)),
            if (_uploading)
              const LinearProgressIndicator(
                color: _gold,
                backgroundColor: Color(0xFFF8E7CB),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: [
                  _guidelines(),
                  const SizedBox(height: 15),
                  _uploadCard(),
                  const SizedBox(height: 22),
                  const Text(
                    'Submission History',
                    style: TextStyle(
                      color: Color(0xFF3D2B1B),
                      fontFamily: 'serif',
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_submissions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: _cardDecoration(),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: Color(0xFFBF7A16),
                            size: 34,
                          ),
                          SizedBox(height: 8),
                          Text('No architecture submissions yet.'),
                        ],
                      ),
                    )
                  else
                    for (final submission in _submissions)
                      _historyCard(submission),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guidelines() => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF2D873B)),
            SizedBox(width: 9),
            Text(
              'Submission Guidelines',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SizedBox(height: 13),
        Text('✓  3D renders — interior and exterior'),
        SizedBox(height: 7),
        Text('✓  Plans, drawings and supporting PDFs'),
        SizedBox(height: 7),
        Text('✓  CAD, ZIP or any other required design format'),
        SizedBox(height: 11),
        Text(
          'Revisions should include every updated document.',
          style: TextStyle(color: Color(0xFF77716A)),
        ),
      ],
    ),
  );

  Widget _uploadCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF9EF),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x88BF7A16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _amountController,
          enabled: !_uploading,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Architecture Design Amount *',
            prefixText: '₹ ',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _pickFiles,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Choose Design Files'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _gold,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: _gold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'All file formats are supported. Select one or multiple files.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF77716A), fontSize: 12),
        ),
        if (_selectedFiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final file in _selectedFiles)
            Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, color: _gold),
                  const SizedBox(width: 8),
                  Expanded(child: Text(file.name)),
                  Text(
                    _size(file.size),
                    style: const TextStyle(
                      color: Color(0xFF77716A),
                      fontSize: 11,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _uploading
                        ? null
                        : () => setState(() => _selectedFiles.remove(file)),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 7),
          FilledButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: _uploading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _uploading ? 'Uploading to Salesforce…' : 'Submit Design Package',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Color(0xFFC43C34))),
        ],
      ],
    ),
  );

  Widget _historyCard(Map<String, dynamic> submission) {
    final files = submission['_files'] as List<dynamic>? ?? const [];
    final status = submission['_status']?.toString().trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  submission['Name']?.toString() ?? 'Architecture Design',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              _HistoryStatus(label: status?.isNotEmpty == true ? status! : '—'),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Sent: ${_date(submission['_sentDate'] ?? submission['CreatedDate'])}',
            style: const TextStyle(color: Color(0xFF77716A)),
          ),
          if (submission['_clientComments']?.toString().trim().isNotEmpty ==
              true) ...[
            const SizedBox(height: 6),
            Text('Client: ${submission['_clientComments']}'),
          ],
          if (submission['_managerComments']?.toString().trim().isNotEmpty ==
              true) ...[
            const SizedBox(height: 4),
            Text('Manager: ${submission['_managerComments']}'),
          ],
          if (submission['_managerApproval'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Manager Approval: '
              '${submission['_managerApproval'] == true ? 'Approved' : submission['_managerApproval']}',
            ),
          ],
          if (submission['_budget'] != null) ...[
            const SizedBox(height: 4),
            Text('Amount: ₹${submission['_budget']}'),
          ],
          const Divider(height: 20),
          if (files.isEmpty)
            const Text(
              'No linked files',
              style: TextStyle(color: Color(0xFF77716A)),
            )
          else
            for (final raw in files)
              Builder(
                builder: (_) {
                  final link = raw as Map<String, dynamic>;
                  final document =
                      link['ContentDocument'] as Map<String, dynamic>? ??
                      const {};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: _gold,
                          size: 20,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(document['Title']?.toString() ?? 'File'),
                        ),
                        Text(
                          _size(document['ContentSize']),
                          style: const TextStyle(
                            color: Color(0xFF77716A),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}

class _HistoryStatus extends StatelessWidget {
  const _HistoryStatus({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final color = lower.contains('approved')
        ? const Color(0xFF2D873B)
        : lower.contains('change')
        ? const Color(0xFFC43C34)
        : const Color(0xFFBF7A16);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProformaInvoiceSheet extends StatefulWidget {
  const _ProformaInvoiceSheet({
    required this.opportunityId,
    required this.initialSubmissions,
  });
  final String opportunityId;
  final List<Map<String, dynamic>> initialSubmissions;

  @override
  State<_ProformaInvoiceSheet> createState() => _ProformaInvoiceSheetState();
}

class _ProformaInvoiceSheetState extends State<_ProformaInvoiceSheet> {
  static const _gold = Color(0xFFBF7A16);
  final List<PlatformFile> _selectedFiles = [];
  late List<Map<String, dynamic>> _history;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _history = List<Map<String, dynamic>>.from(widget.initialSubmissions);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedFiles.addAll(result.files.where((file) => file.path != null));
      _error = null;
    });
  }

  Future<void> _upload() async {
    if (_selectedFiles.isEmpty) {
      setState(() => _error = 'Select at least one invoice file.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ApiService.uploadProformaInvoice(
        opportunityId: widget.opportunityId,
        files: _selectedFiles.map((file) => File(file.path!)).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proforma invoice uploaded to Salesforce.'),
          backgroundColor: Color(0xFF2D873B),
        ),
      );
      Navigator.pop(context, true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _size(dynamic bytes) {
    final value = num.tryParse(bytes?.toString() ?? '') ?? 0;
    return value >= 1024 * 1024
        ? '${(value / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(value / 1024).toStringAsFixed(0)} KB';
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? '—'
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.94,
    ),
    decoration: const BoxDecoration(
      color: Color(0xFFFFFBF5),
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 9),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9D6B8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 27,
                      backgroundColor: Color(0xFFF8E7CB),
                      child: Icon(Icons.receipt_long_outlined, color: _gold),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proforma Invoice Submission',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 22,
                              color: Color(0xFF302218),
                            ),
                          ),
                          Text(
                            'Upload the finalized invoice for approval.',
                            style: TextStyle(color: Color(0xFF77716A)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _uploading
                          ? null
                          : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x22BF7A16)),
          if (_uploading)
            const LinearProgressIndicator(
              color: _gold,
              backgroundColor: Color(0xFFF8E7CB),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                _guidelines(),
                const SizedBox(height: 15),
                _uploadCard(),
                const SizedBox(height: 22),
                const Text(
                  'Proforma Invoice History',
                  style: TextStyle(
                    color: Color(0xFF3D2B1B),
                    fontFamily: 'serif',
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 10),
                if (_history.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: _cardDecoration(),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          color: _gold,
                          size: 34,
                        ),
                        SizedBox(height: 8),
                        Text('No Proforma Invoice submissions yet.'),
                      ],
                    ),
                  )
                else
                  for (final invoice in _history) _historyCard(invoice),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _guidelines() => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF2D873B)),
            SizedBox(width: 9),
            Text(
              'Submission Guidelines',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SizedBox(height: 13),
        Text('✓  Proforma invoice and finalized pricing'),
        SizedBox(height: 7),
        Text('✓  Cost breakdown or BOQ'),
        SizedBox(height: 7),
        Text('✓  Tax and supporting documents, when applicable'),
        SizedBox(height: 11),
        Text(
          'Revisions should include all updated documents.',
          style: TextStyle(color: Color(0xFF77716A)),
        ),
      ],
    ),
  );

  Widget _uploadCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF9EF),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x88BF7A16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _uploading ? null : _pickFiles,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Choose Invoice Files'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _gold,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: _gold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'All formats are supported. Select one or multiple files.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF77716A), fontSize: 12),
        ),
        if (_selectedFiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final file in _selectedFiles)
            Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: _gold),
                  const SizedBox(width: 8),
                  Expanded(child: Text(file.name)),
                  Text(
                    _size(file.size),
                    style: const TextStyle(
                      color: Color(0xFF77716A),
                      fontSize: 11,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _uploading
                        ? null
                        : () => setState(() => _selectedFiles.remove(file)),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: _uploading ? null : _upload,
            icon: _uploading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(
              _uploading ? 'Uploading to Salesforce…' : 'Submit Invoice',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Color(0xFFC43C34))),
        ],
      ],
    ),
  );

  Widget _historyCard(Map<String, dynamic> invoice) {
    final files = invoice['_files'] as List<dynamic>? ?? const [];
    final status = invoice['_clientStatus']?.toString().trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice['Name']?.toString() ?? 'Proforma Invoice',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              _HistoryStatus(label: status?.isNotEmpty == true ? status! : '—'),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Submitted: ${_date(invoice['_sentDate'] ?? invoice['CreatedDate'])}',
            style: const TextStyle(color: Color(0xFF77716A)),
          ),
          if (invoice['_clientComments']?.toString().trim().isNotEmpty ==
              true) ...[
            const SizedBox(height: 5),
            Text('Client: ${invoice['_clientComments']}'),
          ],
          if (invoice['_managerApproval'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Manager Approval: '
              '${invoice['_managerApproval'] == true ? 'Approved' : 'Pending'}',
            ),
          ],
          if (invoice['_managerComments']?.toString().trim().isNotEmpty ==
              true) ...[
            const SizedBox(height: 4),
            Text('Manager: ${invoice['_managerComments']}'),
          ],
          const Divider(height: 20),
          if (files.isEmpty)
            const Text(
              'No linked files',
              style: TextStyle(color: Color(0xFF77716A)),
            )
          else
            for (final raw in files)
              Builder(
                builder: (_) {
                  final link = raw as Map<String, dynamic>;
                  final document =
                      link['ContentDocument'] as Map<String, dynamic>? ??
                      const {};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file_outlined,
                          color: _gold,
                          size: 20,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(document['Title']?.toString() ?? 'File'),
                        ),
                        Text(
                          _size(document['ContentSize']),
                          style: const TextStyle(
                            color: Color(0xFF77716A),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}

class _PaymentTermDraft {
  _PaymentTermDraft({
    this.id,
    String term = '',
    String percentage = '',
    this.dueDate,
    this.paid = false,
  }) : termController = TextEditingController(text: term),
       percentageController = TextEditingController(text: percentage);

  final String? id;
  final TextEditingController termController;
  final TextEditingController percentageController;
  DateTime? dueDate;
  bool paid;

  void dispose() {
    termController.dispose();
    percentageController.dispose();
  }
}

class _PaymentTermsSheet extends StatefulWidget {
  const _PaymentTermsSheet({
    required this.opportunityId,
    required this.initialData,
  });

  final String opportunityId;
  final Map<String, dynamic>? initialData;

  @override
  State<_PaymentTermsSheet> createState() => _PaymentTermsSheetState();
}

class _PaymentTermsSheetState extends State<_PaymentTermsSheet> {
  static const _gold = Color(0xFFBF7A16);
  Map<String, dynamic>? _data;
  final List<_PaymentTermDraft> _terms = [];
  bool _loading = false;
  bool _editing = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    if (_data == null) {
      _reload();
    } else {
      _syncTerms();
    }
  }

  @override
  void dispose() {
    _clearTerms();
    super.dispose();
  }

  void _clearTerms() {
    for (final term in _terms) {
      term.dispose();
    }
    _terms.clear();
  }

  void _syncTerms() {
    _clearTerms();
    final records = _data?['terms'] as List<dynamic>? ?? const [];
    for (final raw in records) {
      final record = raw as Map;
      _terms.add(
        _PaymentTermDraft(
          id: record['id']?.toString(),
          term: record['term']?.toString() ?? '',
          percentage: record['percentage']?.toString() ?? '',
          dueDate: DateTime.tryParse(record['dueDate']?.toString() ?? ''),
          paid: record['paid'] == true,
        ),
      );
    }
    _editing = _terms.isEmpty;
    if (_terms.isEmpty) _terms.add(_PaymentTermDraft());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.getPaymentTerms(widget.opportunityId);
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
        _syncTerms();
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double get _total => _terms.fold<double>(
    0,
    (sum, item) => sum + (double.tryParse(item.percentageController.text) ?? 0),
  );

  void _addTerm() {
    setState(() {
      _terms.add(_PaymentTermDraft());
      _error = null;
    });
  }

  void _removeTerm(int index) {
    if (_terms.length == 1) return;
    setState(() {
      _terms.removeAt(index).dispose();
      _error = null;
    });
  }

  Future<void> _pickDate(int index) async {
    final initial = _terms[index].dueDate ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) {
      setState(() => _terms[index].dueDate = value);
    }
  }

  String _apiDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime? value) => value == null
      ? 'Select due date'
      : '${value.day.toString().padLeft(2, '0')}/'
            '${value.month.toString().padLeft(2, '0')}/${value.year}';

  List<Map<String, dynamic>> _payload() => _terms
      .map(
        (term) => {
          if (term.id != null) 'id': term.id,
          'term': term.termController.text.trim(),
          'percentage': term.percentageController.text.trim(),
          'dueDate': term.dueDate == null ? '' : _apiDate(term.dueDate!),
          'paid': term.paid,
        },
      )
      .toList();

  Future<bool> _save({bool submit = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.savePaymentTerms(
        opportunityId: widget.opportunityId,
        terms: _payload(),
        submitForManagerApproval: submit,
      );
      if (!mounted) return false;
      setState(() {
        _data = result;
        _loading = false;
        _changed = true;
        _syncTerms();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submit
                ? 'Payment Terms submitted for manager approval.'
                : 'Payment Terms saved in Salesforce.',
          ),
          backgroundColor: const Color(0xFF2D873B),
        ),
      );
      return true;
    } catch (exception) {
      if (!mounted) return false;
      setState(() {
        _loading = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
      return false;
    }
  }

  Future<void> _submit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit for Manager Approval?'),
        content: const Text(
          'The payment schedule will be saved and the existing Salesforce '
          'manager approval automation will be started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final saved = await _save(submit: true);
      if (saved && mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.95,
    ),
    decoration: const BoxDecoration(
      color: Color(0xFFFFFBF5),
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 10, 10),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9D6B8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 27,
                      backgroundColor: Color(0xFFF8E7CB),
                      child: Icon(Icons.payments_outlined, color: _gold),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Terms Manager',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 24,
                              color: Color(0xFF302218),
                            ),
                          ),
                          Text(
                            'Configure the client payment schedule.',
                            style: TextStyle(color: Color(0xFF77716A)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pop(context, _changed),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x22BF7A16)),
          if (_loading)
            const LinearProgressIndicator(
              color: _gold,
              backgroundColor: Color(0xFFF8E7CB),
            ),
          Expanded(
            child: _loading && _data == null
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _error != null && _data == null
                ? _errorView()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      if (!_editing && _terms.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _cardDecoration(),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF2F9E82),
                                size: 52,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Payment Terms Configured',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 23,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._terms.asMap().entries.map(
                                (entry) => _viewTerm(entry.key, entry.value),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._terms.asMap().entries.map(
                          (entry) => _editTerm(entry.key, entry.value),
                        ),
                      if (_editing) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _addTerm,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Installment'),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('Total: '),
                          Text(
                            '${_total.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: (_total - 100).abs() < 0.001
                                  ? const Color(0xFF2D873B)
                                  : const Color(0xFFC43C34),
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFC43C34)),
                        ),
                      ],
                    ],
                  ),
          ),
          if (_data != null || _terms.isNotEmpty) _actionBar(),
        ],
      ),
    ),
  );

  Widget _viewTerm(int index, _PaymentTermDraft term) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFF8E7CB),
      foregroundColor: _gold,
      child: Text('${index + 1}'),
    ),
    title: Text(term.termController.text),
    subtitle: Text('Due: ${_displayDate(term.dueDate)}'),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${term.percentageController.text}%'),
        if (term.paid)
          const Text('Paid', style: TextStyle(color: Color(0xFF2D873B))),
      ],
    ),
  );

  Widget _editTerm(int index, _PaymentTermDraft term) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFF8E7CB),
              foregroundColor: _gold,
              child: Text('${index + 1}'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: term.termController,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Term Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              onPressed: _loading || _terms.length == 1
                  ? null
                  : () => _removeTerm(index),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final percentage = TextField(
              controller: term.percentageController,
              enabled: !_loading,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Percentage',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            );
            final date = OutlinedButton.icon(
              onPressed: _loading ? null : () => _pickDate(index),
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _displayDate(term.dueDate),
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            );
            if (constraints.maxWidth < 350) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [percentage, const SizedBox(height: 10), date],
              );
            }
            return Row(
              children: [
                Expanded(child: percentage),
                const SizedBox(width: 10),
                Expanded(child: date),
              ],
            );
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: term.paid,
          onChanged: _loading
              ? null
              : (value) => setState(() => term.paid = value == true),
          title: const Text('Paid'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    ),
  );

  Widget _actionBar() => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    decoration: const BoxDecoration(
      color: Color(0xFFFFFBF5),
      border: Border(top: BorderSide(color: Color(0x22BF7A16))),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final editActions = _editing
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                              _syncTerms();
                              _error = null;
                            }),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading ? null : () => _save(),
                      style: FilledButton.styleFrom(backgroundColor: _gold),
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_loading ? 'Saving…' : 'Save'),
                    ),
                  ),
                ],
              )
            : OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Terms'),
              );
        final submit = FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.email_outlined),
          label: Text(
            _loading ? 'Processing…' : 'Submit for Manager Approval',
            textAlign: TextAlign.center,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2F7FD2),
            minimumSize: const Size.fromHeight(48),
          ),
        );
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [editActions, const SizedBox(height: 8), submit],
          );
        }
        return Row(
          children: [
            Expanded(child: editActions),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: submit),
          ],
        );
      },
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: _gold, size: 44),
          const SizedBox(height: 10),
          Text(_error ?? 'Unable to load Payment Terms.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _BudgetReviewSheet extends StatefulWidget {
  const _BudgetReviewSheet({
    required this.opportunityId,
    required this.initialData,
  });
  final String opportunityId;
  final Map<String, dynamic>? initialData;

  @override
  State<_BudgetReviewSheet> createState() => _BudgetReviewSheetState();
}

class _BudgetReviewSheetState extends State<_BudgetReviewSheet> {
  static const _gold = Color(0xFFBF7A16);
  late Map<String, dynamic>? _data;
  late final TextEditingController _budgetController;
  late final TextEditingController _durationController;
  bool _loading = false;
  bool _editing = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _budgetController = TextEditingController();
    _durationController = TextEditingController();
    _syncControllers();
    if (_data == null) _reload();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _budgetController.text = _data?['supervisorBudget']?.toString() ?? '';
    _durationController.text = _data?['duration']?.toString() ?? '';
  }

  List<String> get _durationValues {
    final configured = (_data?['durationOptions'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty);
    final current = _durationController.text.trim();
    return <String>{...configured, if (current.isNotEmpty) current}.toList();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.getBudgetReview(widget.opportunityId);
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
        _syncControllers();
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (_budgetController.text.trim().isEmpty ||
        _durationController.text.trim().isEmpty) {
      setState(() => _error = 'Budget and duration are required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.saveBudgetReview(
        opportunityId: widget.opportunityId,
        supervisorBudget: _budgetController.text,
        duration: _durationController.text,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
        _editing = false;
        _changed = true;
        _syncControllers();
      });
      _message('Budget Review updated in Salesforce.');
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _send() async {
    if (_editing) await _save();
    if (!mounted || _editing || _loading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send for Client Approval?'),
        content: const Text(
          'The current budget, architecture design details, and payment terms '
          'will be sent using the existing Salesforce email automation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.sendBudgetReviewForClientApproval(
        widget.opportunityId,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
        _changed = true;
      });
      _message('Budget Review sent for client approval.');
      Navigator.pop(context, true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), backgroundColor: const Color(0xFF2D873B)),
    );
  }

  String _currency(dynamic value) {
    final number = num.tryParse(value?.toString() ?? '');
    if (number == null) return '—';
    final whole = number.round().toString();
    final reversed = whole.split('').reversed.toList();
    final groups = <String>[];
    for (var index = 0; index < reversed.length; index += 3) {
      final end = (index + 3).clamp(0, reversed.length);
      groups.add(reversed.sublist(index, end).reversed.join());
    }
    return '₹${groups.reversed.join(',')}';
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? value?.toString() ?? '—'
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.95,
    ),
    decoration: const BoxDecoration(
      color: Color(0xFFFFFBF5),
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9D6B8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 27,
                      backgroundColor: Color(0xFFF8E7CB),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: _gold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Budget Review',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 25,
                              color: Color(0xFF302218),
                            ),
                          ),
                          Text(
                            'Review the complete project budget.',
                            style: TextStyle(color: Color(0xFF77716A)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pop(context, _changed),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x22BF7A16)),
          if (_loading)
            const LinearProgressIndicator(
              color: _gold,
              backgroundColor: Color(0xFFF8E7CB),
            ),
          Expanded(
            child: _loading && _data == null
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _error != null && _data == null
                ? _errorView()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _summaryCard(
                              'Customer Budget',
                              _currency(_data?['customerBudget']),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryCard(
                              'Supervisor Budget',
                              _currency(_data?['supervisorBudget']),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Supervisor Estimate',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _budgetController,
                              enabled: _editing && !_loading,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Supervisor Estimated Budget',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                '${_editing}_${_durationController.text}',
                              ),
                              initialValue:
                                  _durationValues.contains(
                                    _durationController.text,
                                  )
                                  ? _durationController.text
                                  : null,
                              items: _durationValues
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: !_editing || _loading
                                  ? null
                                  : (value) => setState(
                                      () => _durationController.text =
                                          value ?? '',
                                    ),
                              decoration: const InputDecoration(
                                labelText: 'Duration',
                                hintText: 'Select duration',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _summaryCard(
                        'Final Budget',
                        _currency(_data?['finalBudget']),
                        prominent: true,
                      ),
                      const SizedBox(height: 12),
                      _architectureSection(),
                      const SizedBox(height: 12),
                      _paymentTermsSection(),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFC43C34)),
                        ),
                      ],
                    ],
                  ),
          ),
          if (_data != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBF5),
                border: Border(top: BorderSide(color: Color(0x22BF7A16))),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cancelOrEdit = _editing
                      ? OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                  _editing = false;
                                  _error = null;
                                  _syncControllers();
                                }),
                          child: const Text('Cancel', maxLines: 1),
                        )
                      : OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () => setState(() => _editing = true),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit', maxLines: 1),
                        );
                  final save = FilledButton.icon(
                    onPressed: _loading ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: _gold),
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_loading ? 'Saving…' : 'Save'),
                    ),
                  );
                  final send = FilledButton.icon(
                    onPressed: _loading ? null : _send,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.email_outlined),
                    label: const Text(
                      'Send for Client Approval',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3B9A4A),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  );
                  if (_editing && constraints.maxWidth < 430) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: cancelOrEdit),
                            const SizedBox(width: 9),
                            Expanded(child: save),
                          ],
                        ),
                        const SizedBox(height: 9),
                        send,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: cancelOrEdit),
                      if (_editing) ...[
                        const SizedBox(width: 9),
                        Expanded(child: save),
                      ],
                      const SizedBox(width: 9),
                      Expanded(flex: 2, child: send),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );

  Widget _summaryCard(String title, String value, {bool prominent = false}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: prominent
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF77716A))),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                color: const Color(0xFF29231E),
                fontSize: prominent ? 27 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _architectureSection() {
    final designs = _data?['architectureDesigns'] as List<dynamic>? ?? const [];
    return _listSection(
      title: 'Architecture Design',
      icon: Icons.architecture_outlined,
      empty: 'No Architecture Design records found.',
      children: designs
          .map(
            (raw) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text((raw as Map)['name']?.toString() ?? 'Design'),
              trailing: Text(_currency(raw['budget'])),
            ),
          )
          .toList(),
    );
  }

  Widget _paymentTermsSection() {
    final terms = _data?['paymentTerms'] as List<dynamic>? ?? const [];
    return _listSection(
      title: 'Payment Terms',
      icon: Icons.receipt_long_outlined,
      empty: 'Payment Terms added later will appear here automatically.',
      children: terms
          .map(
            (raw) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text((raw as Map)['term']?.toString() ?? 'Term'),
              subtitle: Text('Due: ${_date(raw['dueDate'])}'),
              trailing: Text('${raw['percentage'] ?? '—'}%'),
            ),
          )
          .toList(),
    );
  }

  Widget _listSection({
    required String title,
    required IconData icon,
    required String empty,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _gold),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontFamily: 'serif', fontSize: 20),
            ),
          ],
        ),
        const Divider(),
        if (children.isEmpty)
          Text(empty, style: const TextStyle(color: Color(0xFF77716A)))
        else
          ...children,
      ],
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: _gold, size: 44),
          const SizedBox(height: 10),
          Text(_error ?? 'Unable to load Budget Review.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _ArchitectInformation {
  const _ArchitectInformation({
    required this.name,
    required this.email,
    required this.phone,
  });
  final String name;
  final String email;
  final String phone;
}

class _ArchitectInformationSheet extends StatefulWidget {
  const _ArchitectInformationSheet({
    required this.initialName,
    required this.initialEmail,
    required this.initialPhone,
  });
  final String initialName;
  final String initialEmail;
  final String initialPhone;

  @override
  State<_ArchitectInformationSheet> createState() =>
      _ArchitectInformationSheetState();
}

class _ArchitectInformationSheetState
    extends State<_ArchitectInformationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ArchitectInformation(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBF5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9D6B8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Color(0xFFF8E7CB),
                        child: Icon(
                          Icons.person_pin_outlined,
                          color: Color(0xFFBF7A16),
                        ),
                      ),
                      SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Architect Information',
                              style: TextStyle(
                                color: Color(0xFF302218),
                                fontFamily: 'serif',
                                fontSize: 25,
                              ),
                            ),
                            Text(
                              'Enter the architect contact details.',
                              style: TextStyle(color: Color(0xFF77716A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ArchitectField(
                    controller: _nameController,
                    label: 'Architect Name',
                    icon: Icons.person_outline,
                    validator: (value) => _required(value, 'Architect name'),
                  ),
                  const SizedBox(height: 15),
                  _ArchitectField(
                    controller: _emailController,
                    label: 'Architect Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final requiredError = _required(value, 'Architect email');
                      if (requiredError != null) return requiredError;
                      final email = value!.trim();
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  _ArchitectField(
                    controller: _phoneController,
                    label: 'Architect Contact Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      final requiredError = _required(
                        value,
                        'Architect contact number',
                      );
                      if (requiredError != null) return requiredError;
                      final digits = value!.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 7) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Save Architect Information'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFBF7A16),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF9B6010)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchitectField extends StatelessWidget {
  const _ArchitectField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFFBF7A16)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0x55BF7A16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFBF7A16), width: 1.5),
      ),
    ),
  );
}

class _Datum {
  const _Datum(this.label, this.value, {this.badge = false});
  final String label;
  final dynamic value;
  final bool badge;
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.rows,
    this.initiallyExpanded = false,
  });
  final String title;
  final IconData icon;
  final List<_Datum> rows;
  final bool initiallyExpanded;

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null%' ? '—' : text;
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: _cardDecoration(),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF8EFE3),
        child: Icon(icon, color: const Color(0xFFBF7A16)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF3D2B1B),
          fontFamily: 'serif',
          fontSize: 21,
        ),
      ),
      subtitle: Text('${rows.length} details'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (var index = 0; index < rows.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: index == rows.length - 1
                  ? null
                  : const Border(bottom: BorderSide(color: Color(0x22BF7A16))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 128,
                  child: Text(
                    rows[index].label,
                    style: const TextStyle(color: Color(0xFF77716A)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: rows[index].badge
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: _StageBadge(stage: _value(rows[index].value)),
                        )
                      : Text(
                          _value(rows[index].value),
                          style: const TextStyle(
                            color: Color(0xFF292622),
                            height: 1.4,
                          ),
                        ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});
  final String stage;

  @override
  Widget build(BuildContext context) {
    final lower = stage.toLowerCase();
    final won = lower.contains('won');
    final lost = lower.contains('lost');
    final color = won
        ? const Color(0xFF2D873B)
        : lost
        ? const Color(0xFFC43C34)
        : const Color(0xFFB36B08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        stage,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: const Color(0xEFFFFFFF),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: const Color(0x44BF7A16)),
  boxShadow: const [
    BoxShadow(color: Color(0x116B4B20), blurRadius: 20, offset: Offset(0, 7)),
  ],
);
