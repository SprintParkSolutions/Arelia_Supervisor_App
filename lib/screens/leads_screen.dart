import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/notification_bell.dart';
import 'lead_details_screen.dart';
import 'opportunities_screen.dart';
import 'projects_screen.dart';
import 'vendor_assignments_screen.dart';
import 'supervisor_profile_screen.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  static const _gold = Color(0xFFC28B3C);
  static const _ink = Color(0xFF1E1D1B);
  static const _pageSize = 10;

  final _searchController = TextEditingController();
  List<dynamic> _leads = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _status = 'All';
  String _sort = 'Recent';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    // Start on sign-in, independently of building or opening the inbox bell.
    unawaited(NotificationService.instance.start());
    unawaited(PushNotificationService.instance.start());
    _loadLeads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLeads() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.getLeads();
      if (!mounted) return;
      setState(() {
        _leads = result;
        _loading = false;
        _page = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<dynamic> get _filteredLeads {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = _leads.where((lead) {
      final statusMatches =
          _status == 'All' || _text(lead['Status']) == _status;
      if (!statusMatches) return false;
      if (normalizedQuery.isEmpty) return true;

      return [
        lead['Name'],
        lead['Company'],
        lead['Phone'],
        lead['Email'],
        lead['Owner']?['Name'],
      ].any((value) => _text(value).toLowerCase().contains(normalizedQuery));
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case 'Name A–Z':
          return _text(
            a['Name'],
          ).toLowerCase().compareTo(_text(b['Name']).toLowerCase());
        case 'Status':
          return _text(
            a['Status'],
          ).toLowerCase().compareTo(_text(b['Status']).toLowerCase());
        case 'Oldest':
          return _dateOf(a).compareTo(_dateOf(b));
        default:
          return _dateOf(b).compareTo(_dateOf(a));
      }
    });
    return filtered;
  }

  int get _pageCount => math.max(1, (_filteredLeads.length / _pageSize).ceil());

  List<dynamic> get _visibleLeads {
    final filtered = _filteredLeads;
    final safePage = math.min(_page, _pageCount);
    final start = (safePage - 1) * _pageSize;
    return filtered.skip(start).take(_pageSize).toList();
  }

  List<String> get _statuses {
    final values =
        _leads
            .map((lead) => _text(lead['Status']))
            .where((status) => status.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static DateTime _dateOf(dynamic lead) =>
      DateTime.tryParse(_text(lead['CreatedDate'])) ?? DateTime(1970);

  void _openLead(dynamic lead) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadDetailsScreen(leadId: _text(lead['Id'])),
      ),
    );
  }

  void _showFilterSheet() {
    var selectedStatus = _status;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFFBF6),
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter leads',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Show leads by their current status.',
                  style: TextStyle(color: Color(0xFF77716A)),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _statuses.map((status) {
                    return ChoiceChip(
                      label: Text(status),
                      selected: selectedStatus == status,
                      selectedColor: const Color(0xFFEED9B7),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selectedStatus == status
                            ? _gold
                            : const Color(0xFFE7D8C4),
                      ),
                      onSelected: (_) {
                        setSheetState(() => selectedStatus = status);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _status = selectedStatus;
                        _page = 1;
                      });
                      Navigator.pop(sheetContext);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Apply filter',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleLeads = _visibleLeads;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFFFFBF6),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBF8F3),
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/arelia_leads_background.png',
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
                    Color(0xD8FCF8F2),
                    Color(0xFFFBF8F3),
                  ],
                  stops: [0, 0.35, 0.58],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: _gold,
                onRefresh: _loadLeads,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHero()),
                    SliverToBoxAdapter(child: _buildSearchAndControls()),
                    if (_loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(color: _gold),
                        ),
                      )
                    else if (_error != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _ErrorState(onRetry: _loadLeads),
                      )
                    else if (visibleLeads.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                        sliver: SliverList.builder(
                          itemCount: visibleLeads.length,
                          itemBuilder: (context, index) {
                            final lead = visibleLeads[index];
                            return _LeadCard(
                              lead: lead,
                              onTap: () => _openLead(lead),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildPagination()),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 112)),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Image.asset(
                    'assets/images/arelia_logo.webp',
                    width: 100,
                    height: 92,
                    fit: BoxFit.contain,
                    semanticLabel: 'Arelia Space',
                  ),
                  const _SpaceWordmark(),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const NotificationBell(),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Supervisor profile',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupervisorProfileScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.account_circle_outlined, size: 30),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome back,',
            style: TextStyle(color: Color(0xFF4E4A45), fontSize: 17),
          ),
          const SizedBox(height: 3),
          const Text(
            'Supervisor!',
            style: TextStyle(
              color: _ink,
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Manage and track your\ninterior project leads seamlessly.',
            style: TextStyle(
              color: Color(0xFF504C47),
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                      _page = 1;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search name, phone or email...',
                    hintStyle: const TextStyle(
                      color: Color(0xFFAAA49D),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF85817B),
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _page = 1;
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: const Color(0xEFFFFFFF),
                    contentPadding: const EdgeInsets.symmetric(vertical: 17),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: Color(0x66C7964D)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: Color(0x66C7964D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: _gold, width: 1.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _showFilterSheet,
                icon: const Icon(Icons.filter_alt_outlined, size: 21),
                label: const Text('Filter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4B4844),
                  backgroundColor: const Color(0xEFFFFFFF),
                  side: BorderSide(
                    color: _status == 'All' ? const Color(0x66C7964D) : _gold,
                  ),
                  minimumSize: const Size(94, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ],
          ),
          if (_status != 'All') ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text(_status),
                avatar: const Icon(Icons.check, size: 17),
                onDeleted: () => setState(() {
                  _status = 'All';
                  _page = 1;
                }),
                backgroundColor: const Color(0xFFEED9B7),
                side: const BorderSide(color: Color(0x66C7964D)),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'Total Leads',
                style: TextStyle(color: Color(0xFF4A4743), fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                '${_filteredLeads.length}',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Text(
                'Sort by:',
                style: TextStyle(color: Color(0xFF615D58), fontSize: 14),
              ),
              const SizedBox(width: 3),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sort,
                  borderRadius: BorderRadius.circular(14),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  items: const ['Recent', 'Oldest', 'Name A–Z', 'Status']
                      .map(
                        (sort) =>
                            DropdownMenuItem(value: sort, child: Text(sort)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _sort = value;
                      _page = 1;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    if (_filteredLeads.length <= _pageSize) return const SizedBox.shrink();
    final pageCount = _pageCount;
    final startPage = math.max(1, math.min(_page - 1, pageCount - 2));
    final displayedPages = List.generate(
      math.min(3, pageCount),
      (index) => startPage + index,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        children: [
          Text(
            'Page $_page of $pageCount',
            style: const TextStyle(color: Color(0xFF77716A), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PageButton(
                icon: Icons.chevron_left,
                enabled: _page > 1,
                onTap: () => setState(() => _page--),
              ),
              for (final page in displayedPages) ...[
                const SizedBox(width: 8),
                _PageButton(
                  label: '$page',
                  selected: _page == page,
                  onTap: () => setState(() => _page = page),
                ),
              ],
              const SizedBox(width: 8),
              _PageButton(
                icon: Icons.chevron_right,
                enabled: _page < pageCount,
                onTap: () => setState(() => _page++),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: const Color(0xF7FFFBF6),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0x55C7964D)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.people_alt_outlined,
              label: 'Leads',
              selected: true,
              onTap: () {},
            ),
            _NavItem(
              icon: Icons.trending_up_rounded,
              label: 'Opportunities',
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const OpportunitiesScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.work_outline_rounded,
              label: 'Projects',
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ProjectsScreen()),
              ),
            ),
            _NavItem(
              icon: Icons.handshake_outlined,
              label: 'Vendor Assignment',
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const VendorAssignmentsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead, required this.onTap});

  final dynamic lead;
  final VoidCallback onTap;

  static const _gold = Color(0xFFC28B3C);

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _createdDate(dynamic value) {
    final date = DateTime.tryParse(_value(value));
    if (date == null) return 'Date unavailable';
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

  @override
  Widget build(BuildContext context) {
    final status = _value(lead['Status']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 17, 13, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x55C7964D)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C6B4C23),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF7E8D2), Color(0xFFEAD0A7)],
                        ),
                        border: Border.all(color: const Color(0x44C7964D)),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF24211E),
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _value(lead['Name']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF22211F),
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _InfoRow(
                        icon: Icons.business_outlined,
                        label: 'Company',
                        value: _value(lead['Company']),
                      ),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: _value(lead['Phone']),
                      ),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: _value(lead['Email']),
                      ),
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Owner',
                        value: _value(lead['Owner']?['Name']),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: _gold,
                            size: 16,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Created on ${_createdDate(lead['CreatedDate'])}',
                              style: const TextStyle(
                                color: Color(0xFF97918A),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF77726C),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFC28B3C), size: 17),
          const SizedBox(width: 9),
          SizedBox(
            width: 63,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF77726C), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF373431),
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (background, foreground, border) = switch (normalized) {
      'qualified' => (
        const Color(0xFFDDF4DF),
        const Color(0xFF268A36),
        const Color(0xFFBCE7C2),
      ),
      'new' => (
        const Color(0xFFDCEAFF),
        const Color(0xFF1357B8),
        const Color(0xFFA7C9FF),
      ),
      'working' => (
        const Color(0xFFFFECD1),
        const Color(0xFFA9600B),
        const Color(0xFFF2CC94),
      ),
      'closed' => (
        const Color(0xFFFBE0DE),
        const Color(0xFFB83D35),
        const Color(0xFFF0B9B5),
      ),
      _ => (
        const Color(0xFFEDE9E4),
        const Color(0xFF625D57),
        const Color(0xFFD9D2CA),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    this.label,
    this.icon,
    this.selected = false,
    this.enabled = true,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFC28B3C) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x55C7964D)),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  color: enabled
                      ? const Color(0xFF5C5751)
                      : const Color(0xFFCFC9C1),
                )
              : Text(
                  label!,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF5C5751),
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFB87918) : const Color(0xFF77736E);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceWordmark extends StatelessWidget {
  const _SpaceWordmark();

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: Divider(color: Color(0xFF28241F), thickness: 0.7),
    );
    return const SizedBox(
      width: 108,
      child: Row(
        children: [
          line,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              'S P A C E',
              style: TextStyle(
                color: Color(0xFF28241F),
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 52, color: Color(0xFFC28B3C)),
            SizedBox(height: 14),
            Text(
              'No leads found',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Try changing your search or filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF77716A)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 50,
              color: Color(0xFFC28B3C),
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load leads',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
