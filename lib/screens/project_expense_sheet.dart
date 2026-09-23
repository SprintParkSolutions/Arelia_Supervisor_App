import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';

Future<bool> showProjectExpenseSheet(
  BuildContext context, {
  required String projectId,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: const Color(0x990E0B08),
        builder: (_) => _ExpenseSheetPanel(projectId: projectId),
      ) ??
      false;
}

class _ExpenseSheetPanel extends StatefulWidget {
  const _ExpenseSheetPanel({required this.projectId});
  final String projectId;

  @override
  State<_ExpenseSheetPanel> createState() => _ExpenseSheetPanelState();
}

class _ExpenseSheetPanelState extends State<_ExpenseSheetPanel> {
  static const _gold = Color(0xFFBF7A16);
  final _materials = <_MaterialRow>[_MaterialRow()];
  final _expenses = <_OtherExpenseRow>[_OtherExpenseRow()];
  final _files = <PlatformFile>[];
  List<Map<String, dynamic>> _history = const [];
  bool _historyLoading = true;
  bool _saving = false;
  bool _changed = false;
  int _tab = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    for (final row in _materials) {
      row.dispose();
    }
    for (final row in _expenses) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _error = null;
    });
    try {
      final history = await ApiService.getProjectExpenseSheets(
        widget.projectId,
      );
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyLoading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _historyLoading = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double get _total {
    final materials = _materials.fold<double>(
      0,
      (sum, row) =>
          sum +
          (double.tryParse(row.quantity.text) ?? 0) *
              (double.tryParse(row.rate.text) ?? 0),
    );
    return materials +
        _expenses.fold<double>(
          0,
          (sum, row) => sum + (double.tryParse(row.amount.text) ?? 0),
        );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;
    setState(() {
      _files.addAll(result.files.where((file) => file.path != null));
    });
  }

  Future<void> _save(bool submit) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.saveProjectExpenseSheet(
        projectId: widget.projectId,
        materials: _materials.map((row) => row.data).toList(),
        otherExpenses: _expenses.map((row) => row.data).toList(),
        files: _files.map((file) => File(file.path!)).toList(),
        submitForApproval: submit,
      );
      if (!mounted) return;
      _changed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submit
                ? 'Expense sheet submitted in Salesforce.'
                : 'Expense sheet saved as a draft in Salesforce.',
          ),
          backgroundColor: const Color(0xFF2D873B),
        ),
      );
      for (final row in _materials) {
        row.dispose();
      }
      for (final row in _expenses) {
        row.dispose();
      }
      _materials
        ..clear()
        ..add(_MaterialRow());
      _expenses
        ..clear()
        ..add(_OtherExpenseRow());
      _files.clear();
      setState(() {
        _saving = false;
        _tab = 1;
      });
      await _loadHistory();
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
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
                _tabs(),
                if (_saving)
                  const LinearProgressIndicator(
                    color: _gold,
                    backgroundColor: Color(0xFFF8E7CB),
                  ),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                Expanded(child: _tab == 0 ? _entryForm() : _historyView()),
                if (_tab == 0) _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFF8E7CB),
          foregroundColor: _gold,
          child: Icon(Icons.receipt_long_outlined, size: 28),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage Project Expenses',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 24,
                  color: Color(0xFF35251A),
                ),
              ),
              Text(
                'Create, submit and review expense sheets.',
                style: TextStyle(color: Color(0xFF77716A)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context, _changed),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _tabs() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SegmentedButton<int>(
      segments: const [
        ButtonSegment(
          value: 0,
          icon: Icon(Icons.edit_note_outlined),
          label: Text('Entry Form'),
        ),
        ButtonSegment(
          value: 1,
          icon: Icon(Icons.history_rounded),
          label: Text('History'),
        ),
      ],
      selected: {_tab},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: const Color(0xFFF8E7CB),
        selectedForegroundColor: _gold,
      ),
      onSelectionChanged: (value) => setState(() => _tab = value.first),
    ),
  );

  Widget _entryForm() => ListView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
    children: [
      _sectionTitle('1. Materials Purchased', Icons.shopping_cart_outlined),
      for (var index = 0; index < _materials.length; index++)
        _materialCard(index),
      _addButton(
        'Add Material Row',
        () => setState(() => _materials.add(_MaterialRow())),
      ),
      const SizedBox(height: 18),
      _sectionTitle('2. Other Expenses', Icons.payments_outlined),
      for (var index = 0; index < _expenses.length; index++)
        _expenseCard(index),
      _addButton(
        'Add Expense Row',
        () => setState(() => _expenses.add(_OtherExpenseRow())),
      ),
      const SizedBox(height: 18),
      _filePicker(),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8EF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x553F8E28)),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'GRAND TOTAL PAYABLE',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '₹${_total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF2D873B),
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _sectionTitle(String title, IconData icon) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF9F0E4),
      borderRadius: BorderRadius.circular(15),
      border: const Border(left: BorderSide(color: _gold, width: 4)),
    ),
    child: Row(
      children: [
        Icon(icon, color: _gold),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _materialCard(int index) {
    final row = _materials[index];
    return _rowCard(
      index,
      onDelete: _materials.length == 1
          ? null
          : () => setState(() => _materials.removeAt(index).dispose()),
      children: [
        _field(row.item, 'Item Name'),
        _field(row.description, 'Description'),
        _field(row.brand, 'Brand'),
        Row(
          children: [
            Expanded(child: _numberField(row.quantity, 'Quantity')),
            const SizedBox(width: 10),
            Expanded(child: _numberField(row.rate, 'Rate (₹)')),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Amount: ₹${row.total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: _gold),
          ),
        ),
      ],
    );
  }

  Widget _expenseCard(int index) {
    final row = _expenses[index];
    return _rowCard(
      index,
      onDelete: _expenses.length == 1
          ? null
          : () => setState(() => _expenses.removeAt(index).dispose()),
      children: [
        _field(row.description, 'Description'),
        _numberField(row.amount, 'Amount (₹)'),
      ],
    );
  }

  Widget _rowCard(
    int index, {
    required VoidCallback? onDelete,
    required List<Widget> children,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x44BF7A16)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFF8E7CB),
              child: Text('${index + 1}', style: const TextStyle(color: _gold)),
            ),
            const Spacer(),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        ...children,
      ],
    ),
  );

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      decoration: _decoration(label),
    ),
  );

  Widget _numberField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: _decoration(label),
        ),
      );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFFFFCF8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: _gold, width: 1.5),
    ),
  );

  Widget _addButton(String label, VoidCallback onPressed) =>
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded),
        label: Text(label),
      );

  Widget _filePicker() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F5F0),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x66BF7A16)),
    ),
    child: Column(
      children: [
        OutlinedButton.icon(
          onPressed: _saving ? null : _pickFiles,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Upload Bills or Receipts'),
        ),
        const Text(
          'Select one or multiple files in any format.',
          style: TextStyle(color: Color(0xFF77716A), fontSize: 12),
        ),
        for (var index = 0; index < _files.length; index++)
          ListTile(
            dense: true,
            leading: const Icon(Icons.insert_drive_file_outlined, color: _gold),
            title: Text(_files[index].name),
            trailing: IconButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _files.removeAt(index)),
              icon: const Icon(Icons.close),
            ),
          ),
      ],
    ),
  );

  Widget _historyView() {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    if (_history.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadHistory,
        color: _gold,
        child: ListView(
          children: const [
            SizedBox(height: 90),
            Icon(Icons.receipt_long_outlined, size: 58, color: _gold),
            SizedBox(height: 12),
            Center(child: Text('No expense sheets have been created yet.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: _gold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (_, index) => _historyCard(_history[index]),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final status = item['status']?.toString().trim();
    final total = num.tryParse('${item['total']}');
    final materials = item['materials'] as List? ?? const [];
    final others = item['otherExpenses'] as List? ?? const [];
    final files = item['files'] as List? ?? const [];
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x44BF7A16)),
      ),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF8E7CB),
          foregroundColor: _gold,
          child: Icon(Icons.receipt_long_outlined),
        ),
        title: Text(
          item['name']?.toString() ?? 'Expense Sheet',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${_displayDate(item['date'])}${status == null || status.isEmpty ? '' : ' • $status'}',
        ),
        trailing: Text(
          total == null ? '—' : '₹${total.toStringAsFixed(2)}',
          style: const TextStyle(color: _gold, fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          const Divider(),
          _historyLine('Created by', item['createdBy']),
          _historyLine('Materials', materials.length),
          _historyLine('Other expenses', others.length),
          _historyLine('Files', files.length),
          for (final raw in files)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file_rounded, color: _gold),
              title: Text(
                '${(raw as Map)['name'] ?? 'File'}.${raw['extension'] ?? ''}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyLine(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF77716A))),
        ),
        Text(value?.toString() ?? '—'),
      ],
    ),
  );

  String _displayDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return value?.toString() ?? '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _actions() => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: const BoxDecoration(
      color: Color(0xFFFFFBF5),
      border: Border(top: BorderSide(color: Color(0x22BF7A16))),
    ),
    child: Row(
      children: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, _changed),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : () => _save(false),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving…' : 'Save Draft'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: _saving ? null : () => _save(true),
            style: FilledButton.styleFrom(backgroundColor: _gold),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_saving ? 'Processing…' : 'Submit'),
          ),
        ),
      ],
    ),
  );
}

class _MaterialRow {
  final item = TextEditingController();
  final description = TextEditingController();
  final brand = TextEditingController();
  final quantity = TextEditingController();
  final rate = TextEditingController();

  double get total =>
      (double.tryParse(quantity.text) ?? 0) * (double.tryParse(rate.text) ?? 0);
  Map<String, dynamic> get data => {
    'item': item.text,
    'description': description.text,
    'brand': brand.text,
    'quantity': quantity.text,
    'rate': rate.text,
    'amount': total,
  };
  void dispose() {
    item.dispose();
    description.dispose();
    brand.dispose();
    quantity.dispose();
    rate.dispose();
  }
}

class _OtherExpenseRow {
  final description = TextEditingController();
  final amount = TextEditingController();
  Map<String, dynamic> get data => {
    'description': description.text,
    'amount': amount.text,
  };
  void dispose() {
    description.dispose();
    amount.dispose();
  }
}
