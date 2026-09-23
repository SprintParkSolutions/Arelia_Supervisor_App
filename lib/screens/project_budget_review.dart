import 'package:flutter/material.dart';

Future<bool> showProjectBudgetReview(
  BuildContext context, {
  required Map<String, dynamic> project,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990E0B08),
      builder: (_) => _BudgetReviewPanel(project: project),
    ) ??
    false;

class _BudgetReviewPanel extends StatelessWidget {
  const _BudgetReviewPanel({required this.project});

  static const _gold = Color(0xFFBF7A16);
  static const _green = Color(0xFF2D873B);
  final Map<String, dynamic> project;

  num _number(String key) => num.tryParse('${project['_$key'] ?? 0}') ?? 0;

  String _plain(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _currency(num value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(2).split('.');
    var whole = fixed.first;
    final tail = whole.length > 3 ? whole.substring(whole.length - 3) : whole;
    var head = whole.length > 3 ? whole.substring(0, whole.length - 3) : '';
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    whole = [...groups, tail].join(',');
    return '${negative ? '-' : ''}₹$whole.${fixed.last}';
  }

  String _percent(dynamic value) {
    final number = num.tryParse('${value ?? 0}') ?? 0;
    return '${number == number.roundToDouble() ? number.toInt() : number}%';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _number('remainingBudget');
    final vendorAllocation = _number('vendorBudgetAllocation');
    final approvedExpenses = _number('totalApprovedExpenses');
    final storedFinal = project['_finalRemainingBudget'];
    final finalRemaining = storedFinal == null
        ? remaining - vendorAllocation - approvedExpenses
        : num.tryParse('$storedFinal') ?? 0;
    return FractionallySizedBox(
      heightFactor: .92,
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
              _header(context),
              const Divider(height: 1, color: Color(0x1A000000)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  children: [
                    _section('Project Budget', Icons.account_balance_outlined, [
                      (
                        'Project Final Approval Budget',
                        _currency(_number('finalApprovalBudget')),
                      ),
                      (
                        'Company Share of Project',
                        _currency(_number('companyShare')),
                      ),
                      ('Remaining Project Budget', _currency(remaining)),
                      (
                        'Budget allocation for vendors',
                        _currency(vendorAllocation),
                      ),
                      ('Total Approved Expenses', _currency(approvedExpenses)),
                    ]),
                    const SizedBox(height: 14),
                    _section('Progress & Profit', Icons.trending_up_rounded, [
                      (
                        'Project Completion Status',
                        _percent(project['_projectCompletionStatus']),
                      ),
                      (
                        'Supervisor Profit Percentage',
                        _percent(project['_supervisorProfitPercentage']),
                      ),
                      ('Total Profit', _currency(_number('totalProfit'))),
                      (
                        'Total Profit Percentage',
                        _percent(project['_totalProfitPercentage']),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1FAF1),
                        borderRadius: BorderRadius.circular(18),
                        border: const Border(
                          left: BorderSide(color: _green, width: 5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Final Remaining Budget',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _currency(finalRemaining),
                            style: const TextStyle(
                              color: _green,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0x1A000000))),
                ),
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Close Summary'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 10, 13),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 27,
          backgroundColor: Color(0xFFF8E7CB),
          foregroundColor: _gold,
          child: Icon(Icons.fact_check_outlined, size: 27),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Budget Review Summary',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF251E18),
                ),
              ),
              Text(
                _plain(project['Name']),
                style: const TextStyle(fontSize: 12, color: Color(0xFF77716A)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _section(String title, IconData icon, List<(String, String)> rows) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x225D5148)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFF8E7CB),
                  foregroundColor: _gold,
                  child: Icon(icon),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < rows.length; index++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        rows[index].$1,
                        style: const TextStyle(color: Color(0xFF68615A)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Text(
                        rows[index].$2,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              if (index != rows.length - 1)
                const Divider(height: 1, color: Color(0x14000000)),
            ],
          ],
        ),
      );
}
