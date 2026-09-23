import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../widgets/notification_bell.dart';
import 'leads_screen.dart';
import 'opportunity_details_screen.dart';
import 'projects_screen.dart';
import 'vendor_assignments_screen.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  static const _gold = Color(0xFFC28B3C);
  static const _pageSize = 10;
  final searchController = TextEditingController();
  List<dynamic> opportunities = [];
  bool loading = true;
  String? error;
  String query = '';
  String stage = 'All';
  int page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ApiService.getOpportunities();
      if (!mounted) return;
      setState(() {
        opportunities = result;
        loading = false;
        page = 1;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = exception.toString();
      });
    }
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  List<dynamic> get filtered {
    final normalized = query.trim().toLowerCase();
    return opportunities.where((opportunity) {
      if (stage != 'All' && _text(opportunity['StageName']) != stage) {
        return false;
      }
      if (normalized.isEmpty) return true;
      return [
        opportunity['Name'],
        opportunity['Account']?['Name'],
        opportunity['Owner']?['Name'],
        opportunity['StageName'],
        opportunity['Type'],
        opportunity['Project_Request_Quotation_Type__c'],
      ].any((value) => _text(value).toLowerCase().contains(normalized));
    }).toList();
  }

  List<String> get stages {
    final values =
        opportunities
            .map((item) => _text(item['StageName']))
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  int get pageCount => math.max(1, (filtered.length / _pageSize).ceil());

  List<dynamic> get visible {
    final safePage = math.min(page, pageCount);
    return filtered.skip((safePage - 1) * _pageSize).take(_pageSize).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                  colors: [
                    Color(0x08FFFFFF),
                    Color(0xE8FCF8F2),
                    Color(0xFFFBF8F3),
                  ],
                  stops: [0, 0.35, 0.58],
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
                    if (loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(color: _gold),
                        ),
                      )
                    else if (error != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _ErrorState(onRetry: _load),
                      )
                    else if (visible.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        sliver: SliverList.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final opportunity = visible[index];
                            return _OpportunityCard(
                              opportunity: opportunity,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OpportunityDetailsScreen(
                                    opportunityId: opportunity['Id'],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(child: _pagination()),
                    ],
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
  }

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
              fit: BoxFit.contain,
            ),
            const NotificationBell(),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Sales Pipeline',
          style: TextStyle(color: Color(0xFF56504A), fontSize: 16),
        ),
        const SizedBox(height: 3),
        const Text(
          'Opportunities',
          style: TextStyle(
            color: Color(0xFF1E1D1B),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Track every opportunity from qualification through close.',
          style: TextStyle(
            color: Color(0xFF5E5852),
            fontSize: 14,
            height: 1.45,
          ),
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
                controller: searchController,
                onChanged: (value) => setState(() {
                  query = value;
                  page = 1;
                }),
                decoration: InputDecoration(
                  hintText: 'Search opportunities...',
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: _gold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xEFFFFFFF),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x66C7964D)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: stage,
                  icon: const Icon(Icons.filter_alt_outlined),
                  borderRadius: BorderRadius.circular(16),
                  items: stages
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: SizedBox(
                            width: 74,
                            child: Text(
                              value == 'All' ? 'All Stages' : value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      stage = value;
                      page = 1;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Total Opportunities',
              style: TextStyle(color: Color(0xFF4A4743), fontSize: 15),
            ),
            const SizedBox(width: 8),
            Text(
              '${filtered.length}',
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

  Widget _pagination() {
    if (filtered.length <= _pageSize) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.outlined(
            onPressed: page > 1 ? () => setState(() => page--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text('Page $page of $pageCount'),
          ),
          IconButton.outlined(
            onPressed: page < pageCount ? () => setState(() => page++) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavigation() => SafeArea(
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
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LeadsScreen()),
            ),
          ),
          _NavItem(
            icon: Icons.trending_up_rounded,
            label: 'Opportunities',
            selected: true,
            onTap: () {},
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

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity, required this.onTap});
  final dynamic opportunity;
  final VoidCallback onTap;

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _amount(dynamic value) {
    final amount = num.tryParse(_value(value));
    return amount == null ? 'Not specified' : '₹${amount.toStringAsFixed(0)}';
  }

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
                radius: 29,
                backgroundColor: Color(0xFFF3DDC0),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFFB87315),
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _value(opportunity['Name']),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF22211F),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StageBadge(stage: _value(opportunity['StageName'])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _line(
                      Icons.business_outlined,
                      _value(opportunity['Account']?['Name']),
                    ),
                    _line(Icons.currency_rupee, _amount(opportunity['Amount'])),
                    _line(
                      Icons.calendar_today_outlined,
                      _value(opportunity['CloseDate']),
                    ),
                    _line(
                      Icons.request_quote_outlined,
                      _value(opportunity['Project_Request_Quotation_Type__c']),
                    ),
                    _line(
                      Icons.person_outline,
                      _value(opportunity['Owner']?['Name']),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF77716A)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _line(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFC28B3C), size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF625D57), fontSize: 13),
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
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 92),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEED5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x55C28B3C)),
    ),
    child: Text(
      stage,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF9F5D08),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_rounded, color: Color(0xFFC28B3C), size: 52),
        SizedBox(height: 12),
        Text('No opportunities found', style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          color: Color(0xFFC28B3C),
          size: 52,
        ),
        const SizedBox(height: 12),
        const Text('Unable to load opportunities'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
