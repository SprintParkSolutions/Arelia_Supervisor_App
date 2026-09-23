import 'package:flutter/material.dart';

import '../services/api_service.dart';

Future<bool> showProjectEditor(
  BuildContext context, {
  required String projectId,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990E0B08),
      builder: (_) => _ProjectEditPanel(projectId: projectId),
    ) ??
    false;

class _ProjectEditPanel extends StatefulWidget {
  const _ProjectEditPanel({required this.projectId});

  final String projectId;

  @override
  State<_ProjectEditPanel> createState() => _ProjectEditPanelState();
}

class _ProjectEditPanelState extends State<_ProjectEditPanel> {
  static const _gold = Color(0xFFBF7A16);
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _initialValues = <String, String>{};
  List<Map<String, dynamic>> _fields = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final fields = await ApiService.getEditableProjectDetails(
        widget.projectId,
      );
      if (!mounted) return;
      for (final field in fields) {
        final key = field['key'].toString();
        _controllers[key] = TextEditingController(
          text: field['value']?.toString() ?? '',
        );
        _initialValues[key] = field['value']?.toString() ?? '';
      }
      setState(() {
        _fields = fields;
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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final values = <String, dynamic>{};
      for (final field in _fields) {
        final key = field['key'].toString();
        final type = field['type']?.toString();
        final text = _controllers[key]!.text.trim();
        if (text == (_initialValues[key] ?? '').trim()) continue;
        values[key] = switch (type) {
          'boolean' => text == 'true',
          'currency' || 'double' || 'percent' =>
            text.isEmpty ? null : num.parse(text.replaceAll(',', '')),
          'int' => text.isEmpty ? null : int.parse(text),
          _ => text.isEmpty ? null : text,
        };
      }
      if (values.isEmpty) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Project details were changed.')),
        );
        return;
      }
      await ApiService.updateProjectDetails(
        projectId: widget.projectId,
        values: values,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project details updated in Salesforce.'),
          backgroundColor: Color(0xFF2D873B),
        ),
      );
      Navigator.pop(context, true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _chooseDate(Map<String, dynamic> field) async {
    final key = field['key'].toString();
    final controller = _controllers[key]!;
    final current = DateTime.tryParse(controller.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      controller.text = selected.toIso8601String().split('T').first;
    }
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
                if (_saving)
                  const LinearProgressIndicator(
                    color: _gold,
                    backgroundColor: Color(0xFFF8E7CB),
                  ),
                Expanded(child: _content()),
                if (!_loading && _fields.isNotEmpty) _actions(),
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
          child: Icon(Icons.edit_outlined),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Project Details',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Changes are saved directly to Salesforce.',
                style: TextStyle(fontSize: 12, color: Color(0xFF77716A)),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    if (_fields.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error ?? 'Salesforce did not expose any editable Project fields.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
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
          for (final field in _fields) ...[
            _field(field),
            const SizedBox(height: 15),
          ],
        ],
      ),
    );
  }

  Widget _field(Map<String, dynamic> field) {
    final key = field['key'].toString();
    final type = field['type']?.toString();
    final label = '${field['label']}${field['required'] == true ? ' *' : ''}';
    final values = List<String>.from(field['picklistValues'] as List);
    final controller = _controllers[key]!;
    if (type == 'picklist' && values.isNotEmpty) {
      if (controller.text.isNotEmpty && !values.contains(controller.text)) {
        values.insert(0, controller.text);
      }
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        decoration: _decoration(label),
        items: values
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: _saving ? null : (value) => controller.text = value ?? '',
      );
    }
    if (type == 'boolean') {
      return SwitchListTile(
        value: controller.text == 'true',
        title: Text(label),
        activeThumbColor: _gold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: Colors.white,
        onChanged: _saving
            ? null
            : (value) => setState(() => controller.text = '$value'),
      );
    }
    final isDate = type == 'date' || type == 'datetime';
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      readOnly: isDate,
      onTap: isDate ? () => _chooseDate(field) : null,
      keyboardType:
          const {'currency', 'double', 'percent', 'int'}.contains(type)
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: _decoration(label).copyWith(
        suffixIcon: isDate ? const Icon(Icons.calendar_month_outlined) : null,
      ),
      validator: (value) =>
          field['required'] == true && (value?.trim().isEmpty ?? true)
          ? '${field['label']} is required.'
          : null,
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x335D5148)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _gold, width: 1.5),
    ),
  );

  Widget _actions() => Container(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0x1A000000))),
    ),
    child: FilledButton.icon(
      onPressed: _saving ? null : _save,
      style: FilledButton.styleFrom(
        backgroundColor: _gold,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: _saving
          ? const SizedBox.square(
              dimension: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined),
      label: Text(_saving ? 'Saving...' : 'Save Project Details'),
    ),
  );
}
