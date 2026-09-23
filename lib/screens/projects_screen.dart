import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../widgets/notification_bell.dart';
import 'leads_screen.dart';
import 'opportunities_screen.dart';
import 'project_details_screen.dart';
import 'vendor_assignments_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  static const _gold = Color(0xFFC28B3C);
  static const _pageSize = 10;
  final _search = TextEditingController();
  List<dynamic> _projects = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _status = 'All';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projects = await ApiService.getProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
        _page = 1;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.toString();
      });
    }
  }

  List<dynamic> get _filtered => _projects.where((project) {
    if (_status != 'All' && _text(project['_status']) != _status) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      project['Name'],
      project['_code'],
      project['_status'],
      project['Owner']?['Name'],
    ].any((value) => _text(value).toLowerCase().contains(query));
  }).toList();

  List<String> get _statuses {
    final values =
        _projects
            .map((project) => _text(project['_status']))
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  int get _pageCount => math.max(1, (_filtered.length / _pageSize).ceil());
  List<dynamic> get _visible => _filtered
      .skip((math.min(_page, _pageCount) - 1) * _pageSize)
      .take(_pageSize)
      .toList();

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
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
                colors: [
                  Color(0x12FFFFFF),
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
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _hero()),
                  SliverToBoxAdapter(child: _controls()),
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
                      child: _MessageState(
                        icon: Icons.cloud_off_outlined,
                        message: 'Unable to load projects',
                        action: _load,
                      ),
                    )
                  else if (_visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MessageState(
                        icon: Icons.work_outline_rounded,
                        message: 'No projects found',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      sliver: SliverList.builder(
                        itemCount: _visible.length,
                        itemBuilder: (_, index) {
                          final project = _visible[index];
                          return _ProjectCard(
                            project: project,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProjectDetailsScreen(
                                    projectId: project['Id'].toString(),
                                  ),
                                ),
                              );
                              if (mounted) await _load();
                            },
                          );
                        },
                      ),
                    ),
                  SliverToBoxAdapter(child: _pagination()),
                  const SliverToBoxAdapter(child: SizedBox(height: 112)),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomNavigation(),
    ),
  );

  Widget _hero() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
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
        const SizedBox(height: 18),
        const Text(
          'Project Management',
          style: TextStyle(color: Color(0xFF56504A), fontSize: 16),
        ),
        const Text(
          'Projects',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          'Monitor active interior projects and their delivery pathway.',
          style: TextStyle(color: Color(0xFF5E5852), height: 1.45),
        ),
      ],
    ),
  );

  Widget _controls() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() {
                  _query = value;
                  _page = 1;
                }),
                decoration: InputDecoration(
                  hintText: 'Search projects...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xEFFFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0x66C7964D)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xEFFFFFFF),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x66C7964D)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _status,
                  icon: const Icon(Icons.filter_alt_outlined),
                  items: _statuses
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: SizedBox(
                            width: 72,
                            child: Text(
                              value == 'All' ? 'All Status' : value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _status = value ?? 'All';
                    _page = 1;
                  }),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text('Total Projects', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Text(
              '${_filtered.length}',
              style: const TextStyle(
                color: _gold,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _pagination() => _filtered.length <= _pageSize
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                onPressed: _page > 1 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text('Page $_page of $_pageCount'),
              ),
              IconButton.outlined(
                onPressed: _page < _pageCount
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        );

  Widget _bottomNavigation() => SafeArea(
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
          _Nav(
            icon: Icons.people_alt_outlined,
            label: 'Leads',
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LeadsScreen()),
            ),
          ),
          _Nav(
            icon: Icons.trending_up_rounded,
            label: 'Opportunities',
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OpportunitiesScreen()),
            ),
          ),
          const _Nav(
            icon: Icons.work_outline_rounded,
            label: 'Projects',
            selected: true,
          ),
          _Nav(
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

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});
  final dynamic project;
  final VoidCallback onTap;
  String value(dynamic value) =>
      value?.toString().trim().isNotEmpty == true ? value.toString() : '—';

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: const Color(0xF5FFFFFF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x55C7964D)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 31,
                backgroundColor: Color(0xFFF8E7CB),
                child: Icon(
                  Icons.apartment_rounded,
                  color: Color(0xFFC28B3C),
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value(project['Name']),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Code  ${value(project['_code'])}',
                      style: const TextStyle(color: Color(0xFF6C665F)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Owner  ${value(project['Owner']?['Name'])}',
                      style: const TextStyle(color: Color(0xFF6C665F)),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _StatusBadge(value(project['_status'])),
                  const SizedBox(height: 14),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF77716A),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0x162D873B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x332D873B)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF2D873B),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Nav extends StatelessWidget {
  const _Nav({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected ? const Color(0xFFBF7A16) : const Color(0xFF77716A),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: selected
                  ? const Color(0xFFBF7A16)
                  : const Color(0xFF77716A),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: const Color(0xFFC28B3C)),
        const SizedBox(height: 12),
        Text(message),
        if (action != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: action,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ],
    ),
  );
}
