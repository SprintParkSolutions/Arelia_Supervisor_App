import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../models/additional_budget_policy.dart';

Future<bool> showProjectAdditionalBudget(
  BuildContext context, {
  required String projectId,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990E0B08),
      builder: (_) => _AdditionalBudgetPanel(projectId: projectId),
    ) ??
    false;

class _AdditionalBudgetPanel extends StatefulWidget {
  const _AdditionalBudgetPanel({required this.projectId});

  final String projectId;

  @override
  State<_AdditionalBudgetPanel> createState() => _AdditionalBudgetPanelState();
}

class _AdditionalBudgetPanelState extends State<_AdditionalBudgetPanel> {
  static const _gold = Color(0xFFBF7A16);
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _files = <PlatformFile>[];
  bool _submitting = false;
  bool _checking = true;
  bool _blocked = true;
  bool get _canSubmit => !_submitting && !_checking && !_blocked;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    setState(() {
      _checking = true;
      _blocked = true;
      _error = null;
    });
    try {
      await ApiService.checkProjectAdditionalBudgetSubmission(widget.projectId);
      if (mounted) {
        setState(() {
          _checking = false;
          _blocked = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;
    setState(() {
      _files.addAll(result.files.where((file) => file.path != null));
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiService.submitProjectAdditionalBudget(
        projectId: widget.projectId,
        amount: num.parse(_amountController.text.replaceAll(',', '').trim()),
        reason: _reasonController.text,
        files: _files.map((file) => File(file.path!)).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Additional budget submitted. Salesforce automation has started.',
          ),
          backgroundColor: Color(0xFF2D873B),
        ),
      );
      Navigator.pop(context, true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _blocked = exception.toString().contains(
          AdditionalBudgetPolicy.pendingMessage,
        );
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _fileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboard),
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
                const Divider(height: 1, color: Color(0x1A000000)),
                if (_submitting || _checking)
                  const LinearProgressIndicator(
                    color: _gold,
                    backgroundColor: Color(0xFFF8E7CB),
                  ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                      children: [
                        if (_blocked && !_checking)
                          TextButton.icon(
                            onPressed: _checkEligibility,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Check request status again'),
                          ),
                        _amountField(),
                        const SizedBox(height: 18),
                        _reasonField(),
                        const SizedBox(height: 18),
                        _documents(),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
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
                        ],
                      ],
                    ),
                  ),
                ),
                _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 10, 13),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 27,
          backgroundColor: Color(0xFFF8E7CB),
          foregroundColor: _gold,
          child: Icon(Icons.add_card_outlined, size: 27),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Additional Budget Request',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF251E18),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Submit a revised budget request for this project.',
                style: TextStyle(fontSize: 12, color: Color(0xFF77716A)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: true,
    prefixIcon: Icon(icon, color: _gold),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0x335D5148)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: _gold, width: 1.5),
    ),
  );

  Widget _amountField() => TextFormField(
    controller: _amountController,
    enabled: _canSubmit,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
    decoration: _inputDecoration(
      label: 'Additional Budget *',
      hint: 'Enter the additional amount',
      icon: Icons.currency_rupee_rounded,
    ),
    validator: (value) {
      final amount = num.tryParse((value ?? '').replaceAll(',', '').trim());
      if (amount == null || amount <= 0) {
        return 'Enter an amount greater than zero.';
      }
      return null;
    },
  );

  Widget _reasonField() => TextFormField(
    controller: _reasonController,
    enabled: _canSubmit,
    minLines: 4,
    maxLines: 7,
    textCapitalization: TextCapitalization.sentences,
    decoration: _inputDecoration(
      label: 'Reason *',
      hint: 'Explain why the additional budget is required',
      icon: Icons.notes_rounded,
    ),
    validator: (value) => (value?.trim().isEmpty ?? true)
        ? 'Enter the reason for this request.'
        : null,
  );

  Widget _documents() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF9EF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x66BF7A16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.attach_file_rounded, color: _gold),
            SizedBox(width: 8),
            Text(
              'Supporting Documents (optional)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _canSubmit ? _pickFiles : null,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Choose Files'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _gold,
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: _gold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        if (_files.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final file in _files)
            Container(
              margin: const EdgeInsets.only(top: 7),
              padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, color: _gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(file.name, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    _fileSize(file.size),
                    style: const TextStyle(
                      color: Color(0xFF77716A),
                      fontSize: 11,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _files.remove(file)),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );

  Widget _actions() => Container(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0x1A000000))),
    ),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _submitting ? null : () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_submitting ? 'Submitting...' : 'Submit Request'),
          ),
        ),
      ],
    ),
  );
}
