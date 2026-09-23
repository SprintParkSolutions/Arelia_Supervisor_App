import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../widgets/notification_bell.dart';
import '../services/storage_service.dart';
import 'leads_screen.dart';
import 'opportunities_screen.dart';
import 'projects_screen.dart';

class VendorAssignmentsScreen extends StatefulWidget {
  const VendorAssignmentsScreen({super.key});

  @override
  State<VendorAssignmentsScreen> createState() =>
      _VendorAssignmentsScreenState();
}

class _VendorAssignmentsScreenState extends State<VendorAssignmentsScreen> {
  static const _gold = Color(0xFFC28B3C);
  final _search = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _items = const [];
  String _statusFilter = 'All';
  String _projectFilter = 'All';
  String _vendorFilter = 'All';
  int _page = 0;
  static const int _pageSize = 10;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiService.getVendorAssignments();
      if (!mounted) return;
      setState(() {
        _items = items;
        _page = 0;
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

  List<Map<String, dynamic>> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return _items.where((item) {
      final matchesQuery =
          query.isEmpty ||
          [
            item['name'],
            item['vendor'],
            item['project'],
            item['status'],
          ].any((value) => '${value ?? ''}'.toLowerCase().contains(query));
      return matchesQuery &&
          (_statusFilter == 'All' ||
              '${item['status'] ?? ''}' == _statusFilter) &&
          (_projectFilter == 'All' ||
              '${item['project'] ?? ''}' == _projectFilter) &&
          (_vendorFilter == 'All' ||
              '${item['vendor'] ?? ''}' == _vendorFilter);
    }).toList();
  }

  List<Map<String, dynamic>> get _pageItems {
    final start = _page * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = start + _pageSize > _filtered.length
        ? _filtered.length
        : start + _pageSize;
    return _filtered.sublist(start, end);
  }

  int get _pageCount =>
      _filtered.isEmpty ? 1 : ((_filtered.length + _pageSize - 1) ~/ _pageSize);

  List<String> _options(String key) {
    final values =
        _items
            .map((item) => item[key]?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: const Color(0xFFFBF8F3),
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/arelia_leads_background.png',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x22FFFFFF),
                  Color(0xEEFCF8F2),
                  Color(0xFFFBF8F3),
                ],
                stops: [0, .35, .58],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: _gold,
              onRefresh: _load,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _hero()),
                  SliverToBoxAdapter(child: _searchBox()),
                  if (!_loading && _error == null)
                    SliverToBoxAdapter(child: _filterBar()),
                  if (_loading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: _gold),
                      ),
                    )
                  else if (_error != null)
                    SliverFillRemaining(
                      child: _message(Icons.cloud_off_outlined, _error!),
                    )
                  else if (_filtered.isEmpty)
                    SliverFillRemaining(
                      child: _message(
                        Icons.handshake_outlined,
                        'No vendor assignments found.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      sliver: SliverList.builder(
                        itemCount: _pageItems.length,
                        itemBuilder: (_, index) => _card(_pageItems[index]),
                      ),
                    ),
                  if (!_loading && _error == null && _filtered.isNotEmpty)
                    SliverToBoxAdapter(child: _pagination()),
                  const SliverToBoxAdapter(child: SizedBox(height: 112)),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _navigation(),
    ),
  );

  Widget _hero() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset(
              'assets/images/arelia_logo.webp',
              width: 102,
              height: 102,
            ),
            const NotificationBell(),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Vendor Operations',
          style: TextStyle(color: Color(0xFF56504A)),
        ),
        const Text(
          'Vendor Assignments',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        const Text(
          'Track vendor work, assigned tasks and project delivery status.',
          style: TextStyle(color: Color(0xFF5E5852), height: 1.4),
        ),
      ],
    ),
  );

  Widget _searchBox() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
    child: TextField(
      controller: _search,
      onChanged: (_) => setState(() => _page = 0),
      decoration: InputDecoration(
        hintText: 'Search vendor, project or status...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: const Color(0xEFFFFFFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0x66C7964D)),
        ),
      ),
    ),
  );

  int get _activeFilterCount => [
    _statusFilter,
    _projectFilter,
    _vendorFilter,
  ].where((value) => value != 'All').length;

  Widget _filterBar() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${_filtered.length} assignment${_filtered.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Color(0xFF625C55),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _showFilters,
          icon: Badge(
            isLabelVisible: _activeFilterCount > 0,
            label: Text('$_activeFilterCount'),
            child: const Icon(Icons.tune_rounded),
          ),
          label: const Text('Filters'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _gold,
            side: const BorderSide(color: Color(0x77C28B3C)),
          ),
        ),
      ],
    ),
  );

  Future<void> _showFilters() async {
    var status = _statusFilter;
    var project = _projectFilter;
    var vendor = _vendorFilter;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFBF5),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filter Assignments',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _filterDropdown(
                label: 'Status',
                value: status,
                options: _options('status'),
                onChanged: (value) => setSheetState(() => status = value),
              ),
              const SizedBox(height: 12),
              _filterDropdown(
                label: 'Project',
                value: project,
                options: _options('project'),
                onChanged: (value) => setSheetState(() => project = value),
              ),
              const SizedBox(height: 12),
              _filterDropdown(
                label: 'Vendor',
                value: vendor,
                options: _options('vendor'),
                onChanged: (value) => setSheetState(() => vendor = value),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        status = 'All';
                        project = 'All';
                        vendor = 'All';
                        Navigator.pop(sheetContext, true);
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: FilledButton.styleFrom(backgroundColor: _gold),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        _statusFilter = status;
        _projectFilter = project;
        _vendorFilter = vendor;
        _page = 0;
      });
    }
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: options.contains(value) ? value : 'All',
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    items: options
        .map(
          (option) => DropdownMenuItem(
            value: option,
            child: Text(option, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (selected) => onChanged(selected ?? 'All'),
  );

  Widget _pagination() {
    final first = _page * _pageSize + 1;
    final last = first + _pageItems.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xF5FFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x55C7964D)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous page',
              onPressed: _page == 0 ? null : () => _goToPage(_page - 1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Page ${_page + 1} of $_pageCount',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '$first–$last of ${_filtered.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF77716A),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: _page + 1 >= _pageCount
                  ? null
                  : () => _goToPage(_page + 1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        300.clamp(0, _scrollController.position.maxScrollExtent).toDouble(),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _card(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Material(
      color: const Color(0xF5FFFFFF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VendorAssignmentDetailsScreen(
                assignmentId: item['id'].toString(),
              ),
            ),
          );
          if (mounted) await _load();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x55C7964D)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFFF8E7CB),
                foregroundColor: _gold,
                child: Icon(Icons.engineering_outlined, size: 30),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['vendor'] ?? 'Vendor Work Assignment'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${item['project'] ?? 'Project not specified'}',
                      style: const TextStyle(color: Color(0xFF5E5852)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _status('${item['status'] ?? 'Not Started'}'),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right_rounded, color: _gold),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _status(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0x18BF7A16),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      status,
      style: const TextStyle(
        color: _gold,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _message(IconData icon, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: _gold),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _navigation() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(18, 0, 18, 10),
    child: Container(
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xF7FFFBF6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0x55C7964D)),
      ),
      child: Row(
        children: [
          _VendorNav(
            Icons.people_alt_outlined,
            'Leads',
            () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LeadsScreen()),
            ),
          ),
          _VendorNav(
            Icons.trending_up_rounded,
            'Opportunities',
            () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OpportunitiesScreen()),
            ),
          ),
          _VendorNav(
            Icons.work_outline_rounded,
            'Projects',
            () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProjectsScreen()),
            ),
          ),
          const _VendorNav(
            Icons.handshake_outlined,
            'Vendor Assignment',
            null,
            selected: true,
          ),
        ],
      ),
    ),
  );
}

class _VendorNav extends StatelessWidget {
  const _VendorNav(this.icon, this.label, this.onTap, {this.selected = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected ? const Color(0xFFC28B3C) : const Color(0xFF77716A),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected
                  ? const Color(0xFFC28B3C)
                  : const Color(0xFF77716A),
            ),
          ),
        ],
      ),
    ),
  );
}

class VendorAssignmentDetailsScreen extends StatefulWidget {
  const VendorAssignmentDetailsScreen({super.key, required this.assignmentId});
  final String assignmentId;
  @override
  State<VendorAssignmentDetailsScreen> createState() =>
      _VendorAssignmentDetailsScreenState();
}

class _VendorAssignmentDetailsScreenState
    extends State<VendorAssignmentDetailsScreen> {
  static const _gold = Color(0xFFBF7A16);
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _tasks = const [];
  bool _loading = true;
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        ApiService.getVendorAssignmentDetails(widget.assignmentId),
        ApiService.getVendorAssignmentTasks(
          widget.assignmentId,
        ).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as Map<String, dynamic>;
        _tasks = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get _normalizedStatus => _value(
    _data?['status'],
  ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool get _workStarted =>
      _normalizedStatus == 'inprogress' ||
      _normalizedStatus == 'completed' ||
      _normalizedStatus == 'replaced' ||
      _normalizedStatus == 'abscond';

  bool get _absconded => _normalizedStatus == 'abscond';

  bool get _tasksCompleted =>
      _tasks.isNotEmpty &&
      _tasks.every(
        (task) =>
            task['Status']?.toString().toLowerCase().replaceAll(
              RegExp(r'[^a-z0-9]'),
              '',
            ) ==
            'completed',
      );

  Future<void> _statusAction(bool abscond) async {
    setState(() => _updating = true);
    try {
      await ApiService.updateVendorAssignmentStatus(
        assignmentId: widget.assignmentId,
        abscond: abscond,
      );
      await _load();
      if (!mounted) return;
      setState(() => _updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            abscond
                ? 'Vendor status updated to Abscond.'
                : 'Vendor work started.',
          ),
          backgroundColor: const Color(0xFF2D873B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updating = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFBF8F3),
    appBar: AppBar(
      title: const Text(
        'Vendor Assignment',
        style: TextStyle(fontFamily: 'serif'),
      ),
      backgroundColor: const Color(0xFFFFFBF5),
      bottom: _updating
          ? const PreferredSize(
              preferredSize: Size.fromHeight(3),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: _gold,
                backgroundColor: Color(0xFFF8E7CB),
              ),
            )
          : null,
      actions: [
        IconButton(
          tooltip: 'Reload vendor assignment',
          onPressed: _loading ? null : _load,
          icon: _loading
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
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: _gold))
        : _error != null && _data == null
        ? Center(child: Text(_error!, textAlign: TextAlign.center))
        : RefreshIndicator(
            color: _gold,
            onRefresh: _load,
            child: SafeArea(
              top: false,
              bottom: true,
              minimum: const EdgeInsets.only(bottom: 20),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  72 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  _summary(),
                  if (_error != null) _errorCard(),
                  _pathway(),
                  _details(),
                  for (final related
                      in _data?['relatedLists'] as List<dynamic>? ?? const [])
                    _related(related as Map<String, dynamic>),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
  );

  BoxDecoration _decoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0x44BF7A16)),
    boxShadow: const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 5)),
    ],
  );
  String _value(dynamic value) =>
      value == null || value.toString().trim().isEmpty ? '—' : value.toString();

  String _fieldValue(List<String> candidates) {
    final wanted = candidates
        .map(
          (value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
        )
        .toSet();
    for (final raw in _data?['fields'] as List<dynamic>? ?? const []) {
      final field = raw as Map;
      final label = '${field['label']}'.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      final apiName = '${field['apiName']}'.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      if (wanted.contains(label) || wanted.contains(apiName)) {
        final value = field['value']?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return '';
  }

  Widget _summary() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: _decoration(),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: Color(0xFFF8E7CB),
          foregroundColor: _gold,
          child: Icon(Icons.engineering_outlined, size: 31),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _value(
                  _fieldValue(['Vendor', 'Vendor Name']).isNotEmpty
                      ? _fieldValue(['Vendor', 'Vendor Name'])
                      : 'Vendor Work Assignment',
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              if (_fieldValue(['Project', 'Project Name']).isNotEmpty)
                Text(
                  _fieldValue(['Project', 'Project Name']),
                  style: const TextStyle(color: Color(0xFF625C55)),
                ),
              Text(
                _value(_data?['status']),
                style: const TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _errorCard() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEEE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(_error!, style: const TextStyle(color: Color(0xFFC43C34))),
  );

  Widget _pathway() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: _decoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vendor Work Pathway',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _vendorPathTile(
          number: 1,
          icon: Icons.play_arrow_rounded,
          title: 'Start Vendor Works',
          subtitle: 'Begin assigned vendor work',
          completed: _workStarted,
          active: !_workStarted,
          onTap: _confirmStartVendorWorks,
        ),
        _vendorPathTile(
          number: 2,
          icon: Icons.task_alt_outlined,
          title: 'Assign/Edit Tasks',
          subtitle:
              '${_tasks.length} task${_tasks.length == 1 ? '' : 's'} assigned',
          completed: _tasksCompleted,
          active: _workStarted && !_tasksCompleted && !_absconded,
          onTap: _showTasks,
        ),
        _vendorPathTile(
          number: 3,
          icon: Icons.person_off_outlined,
          title: 'Update Status to Abscond',
          subtitle: 'Mark this vendor assignment as absconded',
          completed: _absconded,
          active: false,
          danger: true,
          onTap: _confirmAbscond,
        ),
      ],
    ),
  );

  Widget _vendorPathTile({
    required int number,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool completed,
    required bool active,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = completed
        ? const Color(0xFF3F8E28)
        : active
        ? _gold
        : danger
        ? const Color(0xFFC43C34)
        : const Color(0xFF77716A);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: active ? const Color(0xFFFFF5E5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _updating ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: .45)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: completed || active
                      ? color
                      : color.withValues(alpha: .1),
                  foregroundColor: completed || active ? Colors.white : color,
                  child: completed
                      ? const Icon(Icons.check_rounded)
                      : Text(
                          '$number',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .1),
                  foregroundColor: color,
                  child: Icon(icon),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF77716A),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  completed
                      ? 'Completed'
                      : active
                      ? 'In Progress'
                      : 'Action',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmStartVendorWorks() async {
    if (_workStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor work has already been started.')),
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
            const SizedBox(width: 11),
            const Expanded(
              child: Text(
                'Start Vendor Works',
                style: TextStyle(fontFamily: 'serif'),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to start vendor work? This will update the assignment in Salesforce.',
              style: TextStyle(fontSize: 15, height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    _value(_data?['status']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded, color: _gold),
                  ),
                  const Text(
                    'In-Progress',
                    style: TextStyle(color: _gold, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
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
    if (proceed == true && mounted) await _statusAction(false);
  }

  Future<void> _confirmAbscond() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update to Abscond?'),
            content: const Text(
              'This will update the Vendor Assignment in Salesforce and run its existing automation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC43C34),
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await _statusAction(true);
  }

  Future<void> _showTasks() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VendorTaskPanel(assignmentId: widget.assignmentId),
    );
    if (mounted) await _load();
  }

  Widget _details() {
    final fields = (_data?['fields'] as List<dynamic>? ?? const []).where((
      field,
    ) {
      final item = field as Map;
      final name = '${item['apiName']}';
      final normalized = name.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      const hidden = {
        'id',
        'name',
        'isdeleted',
        'createddate',
        'createdbyid',
        'lastmodifieddate',
        'lastmodifiedbyid',
        'systemmodstamp',
        'lastactivitydate',
        'lastvieweddate',
        'lastreferenceddate',
        'currencyisocode',
      };
      return !hidden.contains(normalized) &&
          item['value'] != null &&
          item['value'].toString().trim().isNotEmpty &&
          !(name.endsWith('Id') && item['type'] != 'reference');
    }).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _decoration(),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.info_outline_rounded, color: _gold),
        title: const Text(
          'Assignment Details',
          style: TextStyle(fontFamily: 'serif', fontSize: 20),
        ),
        children: [
          for (final raw in fields)
            Builder(
              builder: (_) {
                final field = raw as Map<String, dynamic>;
                return ListTile(
                  title: Text(
                    _value(field['label']),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF77716A),
                    ),
                  ),
                  subtitle: Text(
                    _value(field['value']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _related(Map<String, dynamic> related) {
    final labels = List<dynamic>.from(related['fields'] as List? ?? const []);
    final records = List<dynamic>.from(related['records'] as List? ?? const []);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _decoration(),
      child: ExpansionTile(
        leading: const Icon(Icons.account_tree_outlined, color: _gold),
        title: Text(
          _value(related['label']),
          style: const TextStyle(fontFamily: 'serif', fontSize: 19),
        ),
        subtitle: Text('${records.length} records'),
        children: records.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No related records.'),
                ),
              ]
            : [
                for (final record in records)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFAF3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        for (
                          var i = 0;
                          i < labels.length && i < (record as List).length;
                          i++
                        )
                          if (!labels[i].toString().toLowerCase().contains(
                            'id',
                          ))
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    labels[i].toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF77716A),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _value(record[i]),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
              ],
      ),
    );
  }
}

class _VendorTaskPanel extends StatefulWidget {
  const _VendorTaskPanel({required this.assignmentId});
  final String assignmentId;

  @override
  State<_VendorTaskPanel> createState() => _VendorTaskPanelState();
}

class _VendorTaskPanelState extends State<_VendorTaskPanel> {
  static const _gold = Color(0xFFBF7A16);
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _dueDate = TextEditingController();
  final _startDate = TextEditingController();
  final _assignedPercentage = TextEditingController();
  final _scrollController = ScrollController();
  final _files = <PlatformFile>[];
  List<Map<String, dynamic>> _tasks = const [];
  String _status = 'Not Started';
  String _priority = 'Normal';
  String? _editingId;
  int _step = 0;
  bool _draftLoaded = false;
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
    _subject.dispose();
    _description.dispose();
    _dueDate.dispose();
    _startDate.dispose();
    _assignedPercentage.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        ApiService.getVendorAssignmentTasks(widget.assignmentId),
        if (!_draftLoaded)
          StorageService.getVendorTaskDraft(widget.assignmentId)
        else
          Future<Map<String, dynamic>?>.value(null),
      ]);
      if (!mounted) return;
      final draft = results[1] as Map<String, dynamic>?;
      if (draft != null) {
        _subject.text = draft['subject']?.toString() ?? '';
        _description.text = draft['description']?.toString() ?? '';
        _dueDate.text = draft['dueDate']?.toString() ?? '';
        _startDate.text = draft['startDate']?.toString() ?? '';
        _assignedPercentage.text =
            draft['assignedPercentage']?.toString() ?? '';
        _status = draft['status']?.toString() ?? 'Not Started';
        _priority = draft['priority']?.toString() ?? 'Normal';
        for (final raw in draft['files'] as List<dynamic>? ?? const []) {
          final item = raw as Map;
          final path = item['path']?.toString();
          if (path != null && File(path).existsSync()) {
            _files.add(
              PlatformFile(
                name: item['name']?.toString() ?? path.split('/').last,
                size: File(path).lengthSync(),
                path: path,
              ),
            );
          }
        }
      }
      setState(() {
        _tasks = results[0] as List<Map<String, dynamic>>;
        _loading = false;
        _draftLoaded = true;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _edit(Map<String, dynamic> task) {
    final taskId = task['Id']?.toString();
    if (taskId == null || taskId.isEmpty) {
      setState(() => _error = 'This Salesforce Task could not be opened.');
      return;
    }
    const statuses = {
      'Not Started',
      'In Progress',
      'Completed',
      'Waiting on someone else',
      'Deferred',
    };
    const priorities = {'Low', 'Normal', 'High'};
    final taskStatus = task['Status']?.toString() ?? 'Not Started';
    final taskPriority = task['Priority']?.toString() ?? 'Normal';
    setState(() {
      _editingId = taskId;
      _subject.text = task['Subject']?.toString() ?? '';
      _description.text = task['Description']?.toString() ?? '';
      _dueDate.text = task['ActivityDate']?.toString() ?? '';
      _startDate.text = task['_startDate']?.toString() ?? '';
      _assignedPercentage.text = task['_assignedPercentage']?.toString() ?? '';
      _status = statuses.contains(taskStatus) ? taskStatus : 'Not Started';
      _priority = priorities.contains(taskPriority) ? taskPriority : 'Normal';
      _files.clear();
      _error = null;
      _step = 0;
    });
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _clear() => setState(() {
    _editingId = null;
    _subject.clear();
    _description.clear();
    _dueDate.clear();
    _startDate.clear();
    _assignedPercentage.clear();
    _status = 'Not Started';
    _priority = 'Normal';
    _files.clear();
    _step = 0;
  });

  Future<void> _saveDraft() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await StorageService.saveVendorTaskDraft(widget.assignmentId, {
        'subject': _subject.text,
        'description': _description.text,
        'startDate': _startDate.text,
        'assignedPercentage': _assignedPercentage.text,
        'dueDate': _dueDate.text,
        'status': _status,
        'priority': _priority,
        'files': _files
            .map((file) => {'name': file.name, 'path': file.path})
            .toList(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved. Continue it any time.')),
      );
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Unable to save draft: $exception';
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;
    setState(() {
      _files.addAll(result.files.where((file) => file.path != null));
    });
  }

  Future<void> _save() async {
    if (_subject.text.trim().isEmpty) {
      setState(() => _error = 'Task subject is required.');
      return;
    }
    final assignedPercentage = _assignedPercentage.text.trim().isEmpty
        ? null
        : num.tryParse(_assignedPercentage.text.trim());
    if (assignedPercentage == null &&
        _assignedPercentage.text.trim().isNotEmpty) {
      setState(() => _error = 'Assigned percentage must be a number.');
      return;
    }
    if (assignedPercentage != null &&
        (assignedPercentage < 0 || assignedPercentage > 100)) {
      setState(() => _error = 'Assigned percentage must be from 0 to 100.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.saveVendorAssignmentTask(
        assignmentId: widget.assignmentId,
        taskId: _editingId,
        subject: _subject.text,
        status: _status,
        priority: _priority,
        startDate: _startDate.text,
        dueDate: _dueDate.text,
        assignedPercentage: assignedPercentage,
        description: _description.text,
        files: _files.map((file) => File(file.path!)).toList(),
      );
      await StorageService.deleteVendorTaskDraft(widget.assignmentId);
      final wasEditing = _editingId != null;
      _clear();
      await _load();
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasEditing
                  ? 'Task updated in Salesforce.'
                  : 'Task created in Salesforce.',
            ),
          ),
        );
      }
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = exception.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      controller.text = selected.toIso8601String().split('T').first;
    }
  }

  Widget _stepDot(int step, String label, IconData icon) {
    final selected = _step >= step;
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: selected ? _gold : const Color(0xFFE8E2DB),
          foregroundColor: selected ? Colors.white : const Color(0xFF77716A),
          child: Icon(icon, size: 18),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: selected ? _gold : const Color(0xFF77716A),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int beforeStep) => Expanded(
    child: Container(
      height: 2,
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 14),
      color: _step > beforeStep ? _gold : const Color(0xFFE1DAD2),
    ),
  );

  Widget _reviewTask() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x44BF7A16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Task Data',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _reviewRow('Subject', _subject.text),
        _reviewRow('Status', _status),
        _reviewRow('Priority', _priority),
        _reviewRow('Start Date', _startDate.text),
        _reviewRow('Due Date', _dueDate.text),
        _reviewRow(
          'Assigned Percentage',
          _assignedPercentage.text.trim().isEmpty
              ? ''
              : '${_assignedPercentage.text.trim()}%',
        ),
        _reviewRow('Description', _description.text),
        _reviewRow('Related To', 'Current Vendor Assignment'),
      ],
    ),
  );

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF77716A))),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '—' : value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _attachmentsStep() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8ED),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x66BF7A16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Supporting Attachments (optional)',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'Files will be uploaded and linked to this Salesforce Task.',
          style: TextStyle(fontSize: 11, color: Color(0xFF77716A)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saving ? null : _pickFiles,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Choose Files'),
        ),
        for (final file in _files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined, color: _gold),
            title: Text(file.name, overflow: TextOverflow.ellipsis),
            subtitle: Text('${(file.size / 1024).toStringAsFixed(0)} KB'),
            trailing: IconButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _files.remove(file)),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        if (_files.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: Text('No files selected.')),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    bottom: true,
    minimum: const EdgeInsets.only(bottom: 12),
    child: FractionallySizedBox(
      heightFactor: .94,
      child: Material(
        color: const Color(0xFFFFFBF5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Assign / Edit Tasks',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_saving)
              const LinearProgressIndicator(
                color: _gold,
                backgroundColor: Color(0xFFF8E7CB),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  _stepDot(0, 'Details', Icons.edit_note_rounded),
                  _stepLine(0),
                  _stepDot(1, 'Review', Icons.fact_check_outlined),
                  _stepLine(1),
                  _stepDot(2, 'Attach', Icons.attach_file_rounded),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  120 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  if (_editingId != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5EC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x55368B45)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_note_rounded,
                            color: Color(0xFF2D873B),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Editing “${_subject.text}”\nChange its status or details and update Salesforce.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _saving ? null : _clear,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_step == 0) ...[
                    TextField(
                      controller: _subject,
                      decoration: const InputDecoration(
                        labelText: 'Task Subject *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_status),
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          const [
                                'Not Started',
                                'In Progress',
                                'Completed',
                                'Waiting on someone else',
                                'Deferred',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                              () => _status = value ?? 'Not Started',
                            ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_priority),
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: const ['Low', 'Normal', 'High']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _priority = value ?? 'Normal'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _startDate,
                      readOnly: true,
                      onTap: () => _pickDate(_startDate),
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _dueDate,
                      readOnly: true,
                      onTap: () => _pickDate(_dueDate),
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _assignedPercentage,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,3}(\.\d{0,2})?'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Assigned Percentage',
                        suffixText: '%',
                        hintText: '0–100',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.link_rounded, color: _gold),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Related To: Current Vendor Assignment\nAssigned To: Current Salesforce user',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_step == 1) ...[
                    _reviewTask(),
                  ] else ...[
                    _attachmentsStep(),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFC43C34)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_editingId != null && _step == 0) ...[
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2D873B),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_done_outlined),
                      label: Text(
                        _saving
                            ? 'Updating Task…'
                            : 'Update Task in Salesforce',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _saveDraft,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: const Color(0xFF355D91),
                      side: const BorderSide(color: Color(0xFF6B7B90)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.pause_circle_outline_rounded),
                    label: Text(
                      _saving ? 'Saving Draft…' : 'Save Draft & Continue Later',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (_step > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _step--),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving
                              ? null
                              : _step < 2
                              ? () {
                                  if (_step == 0 &&
                                      _subject.text.trim().isEmpty) {
                                    setState(
                                      () =>
                                          _error = 'Task subject is required.',
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _error = null;
                                    _step++;
                                  });
                                }
                              : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _step < 2
                                      ? Icons.arrow_forward_rounded
                                      : Icons.save_outlined,
                                ),
                          label: Text(
                            _step < 2
                                ? 'Continue'
                                : _editingId == null
                                ? 'Assign Task'
                                : 'Update Task',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Assigned Tasks',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: _gold))
                  else if (_tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: Text('No tasks assigned yet.')),
                    )
                  else
                    for (final task in _tasks)
                      Card(
                        child: ListTile(
                          onTap: () => _edit(task),
                          leading: Icon(
                            task['Status'] == 'Completed'
                                ? Icons.check_circle
                                : Icons.task_alt_outlined,
                            color: task['Status'] == 'Completed'
                                ? const Color(0xFF2D873B)
                                : _gold,
                          ),
                          title: Text('${task['Subject'] ?? 'Task'}'),
                          subtitle: Text(
                            '${task['Status'] ?? 'Not Started'}'
                            '${task['ActivityDate'] == null ? '' : ' • Due ${task['ActivityDate']}'}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Edit this task',
                            onPressed: _saving ? null : () => _edit(task),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
