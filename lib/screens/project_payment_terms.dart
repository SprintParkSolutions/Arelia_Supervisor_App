import 'package:flutter/material.dart';

import '../services/api_service.dart';

Future<void> showProjectPaymentTerms(
  BuildContext context, {
  required String projectId,
  bool readOnly = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0x990E0B08),
  builder: (_) => _PaymentTermsPanel(projectId: projectId, readOnly: readOnly),
);

class _PaymentTermsPanel extends StatefulWidget {
  const _PaymentTermsPanel({required this.projectId, required this.readOnly});

  final String projectId;
  final bool readOnly;

  @override
  State<_PaymentTermsPanel> createState() => _PaymentTermsPanelState();
}

class _PaymentTermsPanelState extends State<_PaymentTermsPanel> {
  static const _gold = Color(0xFFBF7A16);
  static const _green = Color(0xFF2D873B);

  List<_PaymentTerm> _terms = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return value?.toString() ?? '—';
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
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  String _number(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await ApiService.getProjectPaymentTerms(widget.projectId);
      if (!mounted) return;
      setState(() {
        _terms = records
            .map(
              (record) => _PaymentTerm(
                id: record['id'].toString(),
                name: record['term']?.toString() ?? 'Payment Term',
                percentage: num.tryParse('${record['percentage']}') ?? 0,
                dueDate: _date(record['dueDate']),
                apiDueDate: record['dueDate']?.toString() ?? '',
                paid: record['paid'] == true,
              ),
            )
            .toList();
        _loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _updatePaymentStatus() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.updateProjectPaymentTermStatuses(
        projectId: widget.projectId,
        terms: _terms
            .map(
              (term) => {
                'id': term.id,
                'term': term.name,
                'percentage': term.percentage,
                'dueDate': term.apiDueDate,
                'paid': term.paid,
              },
            )
            .toList(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment terms updated in Salesforce.'),
          backgroundColor: _green,
        ),
      );
      await _load();
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .94,
    child: Material(
      color: const Color(0xFFFFFBF5),
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 68,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE9D5B4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            _header(),
            const Divider(height: 1, color: Color(0x1A000000)),
            if (_saving)
              const LinearProgressIndicator(
                color: _gold,
                backgroundColor: Color(0xFFF8E7CB),
              ),
            if (_error != null && _terms.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFC43C34)),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _gold))
                  : _error != null && _terms.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _terms.isEmpty
                  ? const Center(child: Text('No payment terms found.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      itemCount: _terms.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) =>
                          _termCard(index, _terms[index]),
                    ),
            ),
            if (!_loading && _terms.isNotEmpty) _footer(),
          ],
        ),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 10, 13),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 27,
          backgroundColor: Color(0xFFF8E7CB),
          foregroundColor: _gold,
          child: Icon(Icons.account_balance_wallet_outlined, size: 27),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment Terms Manager',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF251E18),
                ),
              ),
              SizedBox(height: 2),
              Text(
                widget.readOnly
                    ? 'Existing Salesforce payment terms (read-only).'
                    : 'Review instalments and mark payments received.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF77716A)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _termCard(int index, _PaymentTerm term) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.fromLTRB(15, 14, 10, 14),
    decoration: BoxDecoration(
      color: term.paid ? const Color(0xFFF4FAF1) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: term.paid ? const Color(0x6672AB5E) : const Color(0x225D5148),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: term.paid ? _green : const Color(0xFFF8E7CB),
          foregroundColor: term.paid ? Colors.white : _gold,
          child: term.paid
              ? const Icon(Icons.check_rounded, size: 22)
              : Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                term.name,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF251E18),
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 7,
                children: [
                  _detailChip(
                    '${_number(term.percentage)}%',
                    Icons.percent_rounded,
                  ),
                  _detailChip(term.dueDate, Icons.event_outlined),
                ],
              ),
            ],
          ),
        ),
        Column(
          children: [
            if (!widget.readOnly)
              IconButton(
                tooltip: 'Edit payment term',
                onPressed: _saving ? null : () => _editTerm(term),
                icon: const Icon(Icons.edit_outlined, color: _gold),
              ),
            Checkbox(
              value: term.paid,
              activeColor: _green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: _saving || widget.readOnly
                  ? null
                  : (value) => setState(() => term.paid = value ?? false),
            ),
            Text(
              term.paid ? 'Paid' : 'Paid?',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: term.paid ? _green : const Color(0xFF77716A),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _editTerm(_PaymentTerm term) async {
    final name = TextEditingController(text: term.name);
    final percentage = TextEditingController(text: _number(term.percentage));
    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Payment Term'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Term name'),
            ),
            TextField(
              controller: percentage,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Percentage',
                suffixText: '%',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    final parsed = num.tryParse(percentage.text.trim());
    if (apply == true && mounted) {
      if (name.text.trim().isEmpty ||
          parsed == null ||
          parsed < 0 ||
          parsed > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a name and a percentage from 0 to 100.'),
          ),
        );
      } else {
        setState(() {
          term.name = name.text.trim();
          term.percentage = parsed;
        });
      }
    }
    name.dispose();
    percentage.dispose();
  }

  Widget _detailChip(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F3EC),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _gold),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _footer() => Container(
    padding: const EdgeInsets.fromLTRB(18, 13, 18, 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0x1A000000))),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total payment terms',
              style: TextStyle(color: Color(0xFF77716A)),
            ),
            Text(
              '${_number(_terms.fold<num>(0, (sum, term) => sum + term.percentage))}%',
              style: const TextStyle(
                color: _green,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (!widget.readOnly) const SizedBox(height: 12),
        if (!widget.readOnly)
          FilledButton.icon(
            onPressed: _saving ? null : _updatePaymentStatus,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(
              _saving ? 'Updating...' : 'Save Payment Terms',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    ),
  );
}

class _PaymentTerm {
  _PaymentTerm({
    required this.id,
    required this.name,
    required this.percentage,
    required this.dueDate,
    required this.apiDueDate,
    this.paid = false,
  });

  final String id;
  String name;
  num percentage;
  final String dueDate;
  final String apiDueDate;
  bool paid;
}
