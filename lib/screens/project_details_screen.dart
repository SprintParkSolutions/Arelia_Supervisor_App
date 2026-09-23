import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'project_additional_budget.dart';
import '../models/additional_budget_policy.dart';
import 'project_budget_review.dart';
import 'project_expense_sheet.dart';
import 'project_edit_sheet.dart';
import 'project_payment_terms.dart';

class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  static const _gold = Color(0xFFBF7A16);
  Map<String, dynamic>? _project;
  List<Map<String, dynamic>> _expenseSheets = const [];
  List<Map<String, dynamic>> _paymentTerms = const [];
  List<Map<String, dynamic>> _allProjectFields = const [];
  List<Map<String, dynamic>> _relatedLists = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _starting = false;
  bool _budgetReviewed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  Future<void> _load() async {
    setState(() {
      _loading = _project == null;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        ApiService.getProject(widget.projectId),
        ApiService.getProjectExpenseSheets(
          widget.projectId,
        ).catchError((_) => <Map<String, dynamic>>[]),
        StorageService.isProjectBudgetReviewed(widget.projectId),
        ApiService.getAllProjectDetails(
          widget.projectId,
        ).catchError((_) => <Map<String, dynamic>>[]),
        ApiService.getProjectRelatedLists(
          widget.projectId,
        ).catchError((_) => <Map<String, dynamic>>[]),
        ApiService.getProjectPaymentTerms(
          widget.projectId,
        ).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _project = results[0] as Map<String, dynamic>;
        _expenseSheets = results[1] as List<Map<String, dynamic>>;
        _budgetReviewed = results[2] as bool;
        _allProjectFields = results[3] as List<Map<String, dynamic>>;
        _relatedLists = results[4] as List<Map<String, dynamic>>;
        _paymentTerms = results[5] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.toString();
      });
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _load();
    if (mounted) setState(() => _refreshing = false);
  }

  bool get _started {
    final status = _value(_project?['_status']).toLowerCase();
    return status != '—' && status != 'initiated';
  }

  bool get _vendorsAssigned {
    final value = _project?['_totalVendors'];
    if (value == true) return true;
    final count = num.tryParse(value?.toString().trim() ?? '');
    if (count != null) return count > 0;
    final normalized = value?.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalized != null &&
        normalized.isNotEmpty &&
        normalized != 'no' &&
        normalized != 'false' &&
        normalized != 'none' &&
        normalized != 'notassigned';
  }

  bool get _expenseSheetApproved => _expenseSheets.any((sheet) {
    final status = sheet['status']?.toString().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (status == null || status.isEmpty) return false;
    return status == 'approved' ||
        status == 'managerapproved' ||
        status == 'accepted';
  });

  bool get _allPaymentTermsPaid =>
      _paymentTerms.isNotEmpty &&
      _paymentTerms.every((term) => term['paid'] == true);

  String get _additionalBudgetStatus =>
      _project?['_additionalRequestStatus']
          ?.toString()
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '') ??
      '';

  bool get _additionalBudgetResolved => const {
    'approved',
    'rejected',
    'accepted',
    'declined',
  }.contains(_additionalBudgetStatus);

  bool get _additionalBudgetSubmitted =>
      AdditionalBudgetPolicy.isPendingRequest(_project ?? {});

  void _showPendingAdditionalBudgetMessage() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Additional Budget Already Submitted'),
        content: const Text(AdditionalBudgetPolicy.pendingMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showExpenseSheet() async {
    final changed = await showProjectExpenseSheet(
      context,
      projectId: widget.projectId,
    );
    if (changed && mounted) await _load();
  }

  Future<void> _showBudgetReview() async {
    final project = _project;
    if (project == null) return;
    final reviewed = await showProjectBudgetReview(context, project: project);
    if (!reviewed || !mounted) return;
    await StorageService.markProjectBudgetReviewed(widget.projectId);
    if (mounted) setState(() => _budgetReviewed = true);
  }

  Future<void> _showProjectEditor() async {
    final changed = await showProjectEditor(
      context,
      projectId: widget.projectId,
    );
    if (changed && mounted) await _load();
  }

  Future<void> _confirmStart() async {
    if (_started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This project has already been started.')),
      );
      return;
    }
    final proceed = await showDialog<bool>(
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
              child: Icon(Icons.play_arrow_rounded),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Start Project',
                style: TextStyle(fontFamily: 'serif'),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to start this project? The project status will be changed from Initiated to In Progress.',
          style: TextStyle(fontSize: 16, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _gold),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Proceed'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    setState(() => _starting = true);
    try {
      await ApiService.startProject(widget.projectId);
      await _load();
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project started successfully in Salesforce.'),
          backgroundColor: Color(0xFF2D873B),
        ),
      );
    } catch (exception) {
      if (!mounted) return;
      setState(() => _starting = false);
      final message = exception.toString().replaceFirst('Exception: ', '');
      if (message.contains('first Payment Term installment')) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Start Project'),
            content: Text(
              'Action Required\n\nWe cannot start the project.\n\nPayment: $message',
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to start project: $message'),
            backgroundColor: const Color(0xFFC43C34),
          ),
        );
      }
    }
  }

  Future<void> _showAssignVendorsInstruction() async {
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
              child: Icon(Icons.groups_outlined),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Assign Vendors',
                style: TextStyle(fontFamily: 'serif'),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: const Text(
          'Please assign the Vendors for this project directly from the '
          'Salesforce Org. This stage will be marked as completed only after '
          'Salesforce reports that one or more vendors have been assigned.',
          style: TextStyle(fontSize: 16, height: 1.45),
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
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: const Color(0xFFFFFBF6),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFFBF8F3),
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
                colors: [
                  Color(0x22FFFFFF),
                  Color(0xEEFCF8F2),
                  Color(0xFFFBF8F3),
                ],
                stops: [0, .28, .55],
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
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _gold),
                        )
                      : _error != null
                      ? Center(
                          child: OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        )
                      : RefreshIndicator(
                          color: _gold,
                          onRefresh: _refresh,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            children: [
                              _summary(),
                              ..._projectDetailSections(),
                              for (final related in _relatedLists)
                                _relatedList(related),
                              _pathway(),
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
            'Project Details',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 27,
              color: Color(0xFF251E18),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Reload project',
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
            IconButton(
              tooltip: 'Edit project',
              onPressed: _showProjectEditor,
              icon: const Icon(Icons.edit_outlined, color: _gold),
            ),
          ],
        ),
      ],
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: const Color(0xF5FFFFFF),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0x55BF7A16)),
    boxShadow: const [
      BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 7)),
    ],
  );

  Widget _summary() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xFFF8E7CB),
          child: Icon(Icons.apartment_rounded, color: _gold, size: 34),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _value(_project?['Name']),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _value(_project?['_code']),
                style: const TextStyle(color: Color(0xFF77716A)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0x142D873B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _value(_project?['_status']),
            style: const TextStyle(
              color: Color(0xFF2D873B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _projectDetailSections() {
    const definitions = <String, (IconData, List<String>)>{
      'Project Information': (
        Icons.apartment_rounded,
        ['projectname', 'projectcode', 'status', 'owner', 'recordtype'],
      ),
      'Basic Project Details': (
        Icons.event_note_outlined,
        [
          'projectstartdate',
          'estimatedprojectduration',
          'estimatedenddate',
          'actualcompletiondate',
          'timeline',
          'holdreason',
          'completionstatus',
          'interiorcategory',
          'interiorprojecttype',
        ],
      ),
      'Manual Project Request Information': (
        Icons.edit_note_rounded,
        ['manual'],
      ),
      'Automatic Project Request Information': (
        Icons.auto_awesome_outlined,
        ['automatic', 'autoproject'],
      ),
      'Client Information': (
        Icons.person_outline_rounded,
        ['client', 'customer', 'lead', 'account', 'contact'],
      ),
      'Opportunity Information': (Icons.handshake_outlined, ['opportunity']),
      'Supervisor Information': (Icons.badge_outlined, ['supervisor']),
      'Additional Budget Information': (
        Icons.add_card_outlined,
        ['additionalbudget', 'additionalamount', 'additionalrequest'],
      ),
      'Company Information': (
        Icons.business_outlined,
        [
          'company',
          'finalapprovalbudget',
          'remainingprojectbudget',
          'profit',
          'budgetallocationforvendors',
          'totalvendorsamount',
          'totalapprovedexpenses',
        ],
      ),
    };
    String normalize(dynamic value) =>
        value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ??
        '';
    final remaining = List<Map<String, dynamic>>.from(
      _allProjectFields.where((field) {
        final apiName = field['apiName']?.toString() ?? '';
        final signature = normalize(field['label']) + normalize(apiName);
        final value = field['value']?.toString().trim() ?? '';
        return apiName != 'Id' &&
            value.isNotEmpty &&
            !signature.contains('negotiationreviewbudget') &&
            !signature.contains('negotiationbudget') &&
            !signature.contains('reviewbudget') &&
            !(apiName.endsWith('Id') && field['type'] != 'reference') &&
            !const {
              'isdeleted',
              'systemmodstamp',
              'lastreferenceddate',
              'lastvieweddate',
            }.contains(normalize(apiName));
      }),
    );
    final widgets = <Widget>[];
    for (final definition in definitions.entries) {
      final matches = <Map<String, dynamic>>[];
      remaining.removeWhere((field) {
        final signature =
            normalize(field['label']) + normalize(field['apiName']);
        final found = definition.value.$2.any(signature.contains);
        if (found) matches.add(field);
        return found;
      });
      if (matches.isNotEmpty) {
        widgets.add(
          _projectFieldSection(
            definition.key,
            definition.value.$1,
            matches,
            initiallyExpanded: definition.key == 'Project Information',
          ),
        );
      }
    }
    if (remaining.isNotEmpty) {
      widgets.add(
        _projectFieldSection(
          'Additional Information',
          Icons.info_outline_rounded,
          remaining,
        ),
      );
    }
    return widgets;
  }

  Widget _projectFieldSection(
    String title,
    IconData icon,
    List<Map<String, dynamic>> fields, {
    bool initiallyExpanded = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: _cardDecoration(),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF9F0E4),
        foregroundColor: _gold,
        child: Icon(icon),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'serif',
          fontSize: 20,
          color: Color(0xFF3D2B1B),
        ),
      ),
      subtitle: Text('${fields.length} details'),
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    fields[index]['label']?.toString() ?? 'Field',
                    style: const TextStyle(color: Color(0xFF77716A)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _displayProjectField(fields[index]),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (index != fields.length - 1)
            const Divider(height: 1, indent: 18, endIndent: 18),
        ],
        const SizedBox(height: 8),
      ],
    ),
  );

  String _displayValue(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '—';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is Map) {
      return value['Name']?.toString() ?? value.values.join(', ');
    }
    return value.toString();
  }

  String _displayProjectField(Map<String, dynamic> field) {
    final value = field['value'];
    if (value == null || value.toString().trim().isEmpty) return '—';
    final type = field['type']?.toString();
    if (type == 'date' || type == 'datetime') {
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) {
        return '${parsed.day.toString().padLeft(2, '0')}/'
            '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
      }
    }
    if (type == 'currency') {
      final amount = num.tryParse(value.toString());
      if (amount != null) return '₹${amount.toStringAsFixed(2)}';
    }
    if (type == 'percent') return '${value.toString()}%';
    return _displayValue(value);
  }

  Widget _relatedList(Map<String, dynamic> related) {
    final labels = List<dynamic>.from(related['fields'] as List? ?? const []);
    final records = List<dynamic>.from(related['records'] as List? ?? const []);
    final signature =
        related['label']?.toString().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        ) ??
        '';
    final paymentTerms = signature.contains('paymentterm');
    final projectHistory = signature.contains('projecthistory');
    final expenseSheets = signature.contains('projectexpensesheet');
    final recordCount = expenseSheets ? _expenseSheets.length : records.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF9F0E4),
          foregroundColor: _gold,
          child: Icon(Icons.account_tree_outlined),
        ),
        title: Text(
          related['label']?.toString() ?? 'Related Records',
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 20,
            color: Color(0xFF3D2B1B),
          ),
        ),
        subtitle: Text('$recordCount record${recordCount == 1 ? '' : 's'}'),
        children: [
          if (recordCount == 0)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No related records found.'),
            )
          else if (expenseSheets)
            for (final sheet in _expenseSheets) _expenseSheetCard(sheet)
          else
            for (
              var recordIndex = 0;
              recordIndex < records.length;
              recordIndex++
            )
              if (paymentTerms)
                _paymentTermCard(
                  labels,
                  records[recordIndex] as List,
                  recordIndex,
                )
              else if (projectHistory)
                _historyCard(
                  labels,
                  records[recordIndex] as List,
                  recordIndex == records.length - 1,
                )
              else
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 5, 14, 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x225D5148)),
                  ),
                  child: Column(
                    children: [
                      for (
                        var fieldIndex = 0;
                        fieldIndex < labels.length;
                        fieldIndex++
                      ) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                labels[fieldIndex].toString(),
                                style: const TextStyle(
                                  color: Color(0xFF77716A),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _displayValue(
                                  (records[recordIndex] as List).length >
                                          fieldIndex
                                      ? (records[recordIndex]
                                            as List)[fieldIndex]
                                      : null,
                                ),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (fieldIndex != labels.length - 1)
                          const Divider(height: 13),
                      ],
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _expenseSheetCard(Map<String, dynamic> sheet) {
    final materials = List<dynamic>.from(
      sheet['materials'] as List? ?? const [],
    );
    final otherExpenses = List<dynamic>.from(
      sheet['otherExpenses'] as List? ?? const [],
    );
    final files = List<dynamic>.from(sheet['files'] as List? ?? const []);
    final status = _displayValue(sheet['status']);
    final normalizedStatus = status.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final submitted =
        normalizedStatus.isNotEmpty &&
        normalizedStatus != '—' &&
        normalizedStatus != 'draft' &&
        normalizedStatus != 'new' &&
        normalizedStatus != 'notsent';
    final total = num.tryParse('${sheet['total']}');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showExpenseSheet,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: submitted
                  ? const Color(0xFFF3FAF1)
                  : const Color(0xFFFFFAF2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: submitted
                    ? const Color(0x5572AB5E)
                    : const Color(0x55BF7A16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: submitted
                          ? const Color(0xFFE4F3DF)
                          : const Color(0xFFF8E7CB),
                      foregroundColor: submitted
                          ? const Color(0xFF3F8E28)
                          : _gold,
                      child: const Icon(Icons.receipt_long_outlined),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayValue(sheet['name']),
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _friendlyDate(
                              sheet['date'] ?? sheet['createdDate'],
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF77716A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: submitted
                            ? const Color(0x183F8E28)
                            : const Color(0x18BF7A16),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: submitted ? const Color(0xFF3F8E28) : _gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.chevron_right_rounded, color: _gold),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: _expenseMetric(
                        Icons.inventory_2_outlined,
                        '${materials.length}',
                        'Materials',
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _expenseMetric(
                        Icons.payments_outlined,
                        '${otherExpenses.length}',
                        'Other costs',
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _expenseMetric(
                        Icons.attach_file_rounded,
                        '${files.length}',
                        'Files',
                      ),
                    ),
                  ],
                ),
                if (total != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Expense Total',
                        style: TextStyle(
                          color: Color(0xFF77716A),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF3D2B1B),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expenseMetric(IconData icon, String value, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      children: [
        Icon(icon, color: _gold, size: 18),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, color: Color(0xFF77716A)),
        ),
      ],
    ),
  );

  Map<String, dynamic> _recordValues(
    List<dynamic> labels,
    List<dynamic> record,
  ) => {
    for (var index = 0; index < labels.length; index++)
      labels[index].toString().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      ): index < record.length
          ? record[index]
          : null,
  };

  dynamic _relatedValue(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      if (values[key] != null) return values[key];
      for (final entry in values.entries) {
        if (entry.key.contains(key) && entry.value != null) return entry.value;
      }
    }
    return null;
  }

  String _friendlyDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return _displayValue(value);
    final hasTime = value.toString().contains('T');
    final hour = parsed.hour == 0
        ? 12
        : parsed.hour > 12
        ? parsed.hour - 12
        : parsed.hour;
    return '${parsed.day}/${parsed.month}/${parsed.year}'
        '${hasTime ? ', $hour:${parsed.minute.toString().padLeft(2, '0')} ${parsed.hour >= 12 ? 'PM' : 'AM'}' : ''}';
  }

  Widget _paymentTermCard(
    List<dynamic> labels,
    List<dynamic> record,
    int index,
  ) {
    final values = _recordValues(labels, record);
    final name = _relatedValue(values, ['name', 'termname', 'paymentterm']);
    final dueDate = _relatedValue(values, ['duedate']);
    final percentage = _relatedValue(values, ['percentage', 'percent']);
    final received =
        _relatedValue(values, ['paymentreceived', 'ispaid', 'paid']) == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 5, 14, 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: received ? const Color(0xFFF2FAF0) : const Color(0xFFFFFAF2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: received ? const Color(0x6672AB5E) : const Color(0x55BF7A16),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: received
                ? const Color(0xFF3F8E28)
                : const Color(0xFFF8E7CB),
            foregroundColor: received ? Colors.white : _gold,
            child: received
                ? const Icon(Icons.check_rounded)
                : Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayValue(name),
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _relatedChip(Icons.event_outlined, _friendlyDate(dueDate)),
                    _relatedChip(
                      Icons.percent_rounded,
                      _displayValue(percentage),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              Icon(
                received
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: received
                    ? const Color(0xFF3F8E28)
                    : const Color(0xFF918A83),
              ),
              Text(
                received ? 'Received' : 'Pending',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: received
                      ? const Color(0xFF3F8E28)
                      : const Color(0xFF77716A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _relatedChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _gold),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _historyCard(List<dynamic> labels, List<dynamic> record, bool last) {
    final values = _recordValues(labels, record);
    final date = _relatedValue(values, ['date', 'createddate']);
    final field = _relatedValue(values, ['field']);
    final user = _relatedValue(values, ['user', 'createdby']);
    final original = _relatedValue(values, ['originalvalue', 'oldvalue']);
    final changed = _relatedValue(values, ['newvalue']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 8,
                    backgroundColor: _gold,
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: const Color(0xFFE5D3B7),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x225D5148)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayValue(field),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          _friendlyDate(date),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF77716A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Changed by ${_displayValue(user)}',
                      style: const TextStyle(fontSize: 11, color: _gold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _historyValue(
                            'Original',
                            original,
                            const Color(0xFFFFF1F0),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 7),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: Color(0xFF99918A),
                          ),
                        ),
                        Expanded(
                          child: _historyValue(
                            'New',
                            changed,
                            const Color(0xFFF1FAF1),
                          ),
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
    );
  }

  Widget _historyValue(String label, dynamic value, Color color) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF77716A)),
        ),
        const SizedBox(height: 3),
        Text(
          _displayValue(value),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _pathway() {
    final actions = <(String, IconData, VoidCallback)>[
      ('Start Project', Icons.play_arrow_rounded, _confirmStart),
      ('Assign Vendors', Icons.groups_outlined, _showAssignVendorsInstruction),
      ('Create Expense Sheet', Icons.receipt_long_outlined, _showExpenseSheet),
      (
        'Payment Terms',
        Icons.account_balance_wallet_outlined,
        () async {
          await showProjectPaymentTerms(
            context,
            projectId: widget.projectId,
            readOnly: false,
          );
          if (mounted) await _load();
        },
      ),
      (
        'Additional Budget',
        Icons.add_card_outlined,
        () async {
          final changed = await showProjectAdditionalBudget(
            context,
            projectId: widget.projectId,
          );
          if (changed && mounted) await _load();
        },
      ),
      ('Review Budget', Icons.fact_check_outlined, _showBudgetReview),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 19, 12, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Progress Pathway',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 23,
              color: Color(0xFF3D2B1B),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Follow each project delivery stage in order.',
            style: TextStyle(color: Color(0xFF77716A)),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < actions.length; index++)
            _PathTile(
              number: index + 1,
              label: actions[index].$1,
              icon: actions[index].$2,
              completed: index == 0
                  ? _started
                  : index == 1
                  ? _vendorsAssigned
                  : index == 2
                  ? _expenseSheetApproved
                  : index == 3
                  ? _allPaymentTermsPaid
                  : index == 4
                  ? _additionalBudgetResolved
                  : index == 5 && _budgetReviewed,
              active: index == 0
                  ? !_started
                  : index == 1
                  ? _started && !_vendorsAssigned
                  : index == 2
                  ? _started && _vendorsAssigned && !_expenseSheetApproved
                  : index == 3
                  ? _paymentTerms.isNotEmpty && !_allPaymentTermsPaid
                  : index == 4
                  ? _additionalBudgetSubmitted
                  : index == 5 && _additionalBudgetResolved && !_budgetReviewed,
              loading: index == 0 && _starting,
              statusLabel: index == 4 && _additionalBudgetSubmitted
                  ? 'Pending approval'
                  : index == 3 &&
                        _paymentTerms.isNotEmpty &&
                        !_allPaymentTermsPaid
                  ? 'Existing'
                  : null,
              onTap: index == 4 && _additionalBudgetSubmitted
                  ? _showPendingAdditionalBudgetMessage
                  : actions[index].$3,
              last: index == actions.length - 1,
            ),
        ],
      ),
    );
  }
}

class _PathTile extends StatelessWidget {
  const _PathTile({
    required this.number,
    required this.label,
    required this.icon,
    required this.completed,
    required this.active,
    required this.loading,
    required this.onTap,
    required this.last,
    this.statusLabel,
  });
  final int number;
  final String label;
  final IconData icon;
  final bool completed, active, loading, last;
  final String? statusLabel;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = completed
        ? const Color(0xFF3F8E28)
        : active
        ? const Color(0xFFBF7A16)
        : const Color(0xFF77716A);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: completed || active
                      ? color
                      : const Color(0xFFF4F0EB),
                  child: completed
                      ? const Icon(Icons.check, color: Colors.white)
                      : Text(
                          '$number',
                          style: TextStyle(
                            color: active ? Colors.white : color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: completed
                          ? const Color(0xFF72AB5E)
                          : const Color(0xFFD8D2CB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: loading ? null : onTap,
                  borderRadius: BorderRadius.circular(17),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFFFF7EA)
                          : Colors.white.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: color.withValues(
                          alpha: completed || active ? .5 : .2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withValues(alpha: .1),
                          foregroundColor: color,
                          child: Icon(icon),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 17,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (loading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _ProjectDetailsScreenState._gold,
                            ),
                          )
                        else
                          Text(
                            statusLabel ??
                                (completed
                                    ? 'Completed'
                                    : active
                                    ? 'In Progress'
                                    : 'Upcoming'),
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(width: 5),
                        Icon(Icons.chevron_right, color: color),
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
