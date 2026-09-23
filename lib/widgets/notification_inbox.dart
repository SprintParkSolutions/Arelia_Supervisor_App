import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/push_backend.dart';

import '../services/notification_service.dart';
import '../models/email_recipients.dart';
import '../services/push_notification_service.dart';

const _ink = Color(0xFF20352E);
const _gold = Color(0xFFBA8843);
const _muted = Color(0xFF7B8078);
const _cream = Color(0xFFFAF7F1);

class NotificationInbox extends StatefulWidget {
  const NotificationInbox({super.key, required this.service});
  final NotificationService service;

  @override
  State<NotificationInbox> createState() => _NotificationInboxState();
}

class _NotificationInboxState extends State<NotificationInbox> {
  String _filter = 'All';
  static const _filters = {
    'All': null,
    'Unread': null,
    'Projects': 'Project',
    'Leads': 'Lead',
    'Opportunities': 'Opportunity',
    'Invoices': 'Proforma Invoice',
    'Vendors': 'Vendor Assignment',
    'Email': 'Email',
  };

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return DraggableScrollableSheet(
      initialChildSize: .86,
      minChildSize: .5,
      maxChildSize: .96,
      expand: false,
      builder: (context, scrollController) => Material(
        color: _cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: service,
            builder: (context, _) {
              final items = service.items.where((item) {
                if (_filter == 'Unread') return item['read'] != true;
                return _filter == 'All' || item['source'] == _filters[_filter];
              }).toList();
              return RefreshIndicator(
                color: _gold,
                onRefresh: service.refresh,
                child: CustomScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _header(service)),
                    SliverToBoxAdapter(child: _controls(service)),
                    if (service.busy)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: _gold,
                          backgroundColor: Color(0xFFEDE4D5),
                        ),
                      ),
                    SliverToBoxAdapter(child: _settings(service)),
                    if (items.isEmpty)
                      SliverFillRemaining(hasScrollBody: false, child: _empty())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                        sliver: SliverList.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final day = _day(item['time']);
                            final showDay =
                                index == 0 ||
                                day != _day(items[index - 1]['time']);
                            return Column(
                              key: ValueKey(item['id']),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showDay)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      18,
                                      4,
                                      12,
                                    ),
                                    child: Text(
                                      day.toUpperCase(),
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                _Arrival(
                                  animate: index < 8,
                                  child: Dismissible(
                                    key: ValueKey('notification-${item['id']}'),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) =>
                                        service.clear(item['id'] as String),
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 22),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4E0DA),
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFA45140),
                                      ),
                                    ),
                                    child: _NotificationCard(
                                      item: item,
                                      onClear: () =>
                                          service.clear(item['id'] as String),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(NotificationService service) => Container(
    padding: const EdgeInsets.fromLTRB(22, 10, 14, 24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF172D26), Color(0xFF304B3E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x25D9B778),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0x40D9B778)),
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFFE9CA94),
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'ARELIA • UPDATES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Color(0xFFDDCBA9),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh notifications',
              onPressed: service.busy ? null : service.refresh,
              icon: const Icon(Icons.refresh_rounded),
              color: Colors.white70,
              disabledColor: Colors.white24,
            ),
            IconButton(
              tooltip: 'Close notifications',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              color: Colors.white70,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Your notifications',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 30,
            height: 1.15,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Every update. All in one place.',
          style: TextStyle(fontSize: 13, color: Color(0xFFBAC9BF)),
        ),
        const SizedBox(height: 17),
        AnimatedSwitcher(
          duration: _duration(context, 220),
          child: Container(
            key: ValueKey(service.unreadCount),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0x22E6C993),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              service.unreadCount == 0
                  ? 'You’re all caught up'
                  : '${service.unreadCount} unread updates',
              style: const TextStyle(
                color: Color(0xFFF1DBB3),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _controls(NotificationService service) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 12, 2),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${service.items.length} updates',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Notification actions',
              icon: const Icon(Icons.more_horiz_rounded, color: _ink),
              onSelected: (action) {
                if (action == 'read') {
                  service.markRead();
                } else {
                  service.clearAll();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'read',
                  enabled: service.unreadCount > 0,
                  child: const Text('Mark all as read'),
                ),
                PopupMenuItem(
                  value: 'clear',
                  enabled: service.items.isNotEmpty,
                  child: const Text('Clear all notifications'),
                ),
              ],
            ),
          ],
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters.keys.elementAt(index);
              return ChoiceChip(
                label: Text(filter),
                selected: _filter == filter,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = filter),
                selectedColor: _ink,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: _filter == filter ? _ink : const Color(0xFFE5E3DA),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                labelStyle: TextStyle(
                  color: _filter == filter ? Colors.white : _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _configureEmails() async {
    final service = widget.service;
    String addressFor(String role) => service.emailRecipients.entries
        .where((entry) => entry.value.contains(role))
        .map((entry) => entry.key)
        .join('\n');
    var supervisorValue = addressFor('Supervisor');
    var managerValue = addressFor('Manager');
    final formKey = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email notifications'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add multiple addresses for each role, separated by commas, semicolons, or new lines. Saving also loads the last 30 days.',
                ),
                const SizedBox(height: 16),
                for (final entry in {
                  'Supervisor emails': supervisorValue,
                  'Manager emails': managerValue,
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      initialValue: entry.value,
                      onChanged: (value) {
                        if (entry.key == 'Supervisor emails') {
                          supervisorValue = value;
                        } else {
                          managerValue = value;
                        }
                      },
                      keyboardType: TextInputType.multiline,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: entry.key,
                        hintText: 'first@example.com, second@example.com',
                        alignLabelWithHint: true,
                        errorMaxLines: 3,
                      ),
                      validator: EmailRecipients.validate,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true && mounted) {
      try {
        await service.configureEmailRecipients(
          supervisor: supervisorValue,
          manager: managerValue,
        );
        if (mounted) setState(() => _filter = 'Email');
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
  }

  Future<void> _loadEmails(bool allHistory) async {
    try {
      await widget.service.loadEmailHistory(allHistory: allHistory);
      if (mounted) setState(() => _filter = 'Email');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _testPhonePopup({bool copyToken = false}) async {
    try {
      if (copyToken) {
        await PushNotificationService.instance.copyTestDeviceToken();
      } else {
        await PushNotificationService.instance.scheduleTestPopup();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copyToken
                ? 'Test device token copied.'
                : 'Test scheduled. Switch to another app. Requested for 30 seconds from now; the phone may delay it.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _settings(NotificationService service) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        dense: true,
        leading: Icon(
          service.errors.isEmpty
              ? Icons.tune_rounded
              : Icons.info_outline_rounded,
          size: 19,
          color: service.errors.isEmpty ? _muted : const Color(0xFFB26D2E),
        ),
        title: Text(
          service.errors.isEmpty
              ? 'Delivery & sound'
              : 'Delivery & sound · Check connection',
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Notification sound',
              style: TextStyle(fontSize: 14, color: _ink),
            ),
            activeTrackColor: _gold,
            value: service.soundEnabled,
            onChanged: service.setSound,
          ),
          ValueListenableBuilder<String>(
            valueListenable: PushNotificationService.instance.status,
            builder: (context, status, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: _muted,
                  ),
                ),
                TextButton(
                  onPressed: PushNotificationService.instance.start,
                  style: TextButton.styleFrom(foregroundColor: _ink),
                  child: const Text('Enable notifications'),
                ),
              ],
            ),
          ),
          if (kDebugMode)
            Wrap(
              children: [
                TextButton.icon(
                  onPressed: () => _testPhonePopup(),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Test phone popup'),
                ),
                if (PushBackend.testMode)
                  TextButton(
                    onPressed: () => _testPhonePopup(copyToken: true),
                    child: const Text('Copy Firebase test token'),
                  ),
              ],
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: service.busy ? null : _configureEmails,
                icon: const Icon(Icons.alternate_email_rounded, size: 18),
                label: const Text('Email settings'),
              ),
              PopupMenuButton<bool>(
                enabled: !service.busy && service.emailRecipients.isNotEmpty,
                tooltip: 'Load previous emails',
                onSelected: _loadEmails,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('Last 30 days')),
                  PopupMenuItem(
                    value: true,
                    child: Text('All recorded emails'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  child: Text(
                    'Load previous emails',
                    style: TextStyle(
                      color: service.emailRecipients.isEmpty ? _muted : _ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (service.emailHistoryMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                service.emailHistoryMessage!,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          if (service.emailRecipients.isEmpty)
            const Text(
              'Email alerts have not been configured for this account.',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          const SizedBox(height: 8),
          const Text(
            'Checks automatically every 15 seconds while Arelia is open. You do not need to open this inbox or refresh.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          if (service.errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                service.errors.values.join('\n'),
                style: const TextStyle(fontSize: 12, color: Color(0xFFAD4D3E)),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF0E7D8),
            border: Border.all(color: const Color(0xFFE5D6BB), width: 8),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: _gold,
            size: 38,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _filter == 'All' ? 'A little peace of mind' : 'Nothing here just yet',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'serif',
            color: _ink,
            fontSize: 23,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _filter == 'All'
              ? 'Your project and email updates will appear here.'
              : 'No ${_filter.toLowerCase()} notifications to show.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
        ),
      ],
    ),
  );

  String _day(dynamic time) {
    final date = DateTime.tryParse(time?.toString() ?? '')?.toLocal();
    if (date == null) return 'Updates';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Today';
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday';
    }
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }
}

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({required this.item, required this.onClear});
  final Map<String, dynamic> item;
  final VoidCallback onClear;
  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final unread = item['read'] != true;
    final (icon, color) = switch (item['source']) {
      'Email' => (Icons.mail_outline_rounded, const Color(0xFF82639B)),
      'Lead' => (Icons.person_outline_rounded, const Color(0xFF4D7C97)),
      'Opportunity' => (Icons.trending_up_rounded, const Color(0xFFB17A32)),
      'Proforma Invoice' => (
        Icons.receipt_long_rounded,
        const Color(0xFFB17A32),
      ),
      'Vendor Assignment' => (
        Icons.handshake_outlined,
        const Color(0xFFAB715B),
      ),
      _ => (Icons.work_outline_rounded, const Color(0xFF527662)),
    };
    final date = DateTime.tryParse(item['time']?.toString() ?? '')?.toLocal();
    final time = date == null
        ? ''
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(date),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    final body = item['body']?.toString() ?? '';
    return AnimatedContainer(
      duration: _duration(context, 220),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: unread ? const Color(0xFFDEC79F) : const Color(0xFFECE9E1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070E2019),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 8, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item['source']?.toString() ?? 'Update',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (unread)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 7),
                    decoration: const BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(time, style: const TextStyle(color: _muted, fontSize: 10)),
                IconButton(
                  tooltip: 'Clear notification',
                  onPressed: widget.onClear,
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  icon: const Icon(Icons.close_rounded, color: _muted),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 9, 9, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title']?.toString() ?? 'Update',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  AnimatedSize(
                    duration: _duration(context, 220),
                    alignment: Alignment.topLeft,
                    child: Text(
                      body,
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: Color(0xFF787E76),
                      ),
                    ),
                  ),
                  if (body.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _expanded ? 'Show less' : 'View details',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _gold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _expanded ? .5 : 0,
                              duration: _duration(context, 200),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 15,
                                color: _gold,
                              ),
                            ),
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
  }
}

Duration _duration(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class _Arrival extends StatelessWidget {
  const _Arrival({required this.child, required this.animate});
  final Widget child;
  final bool animate;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: animate && !MediaQuery.disableAnimationsOf(context) ? 0 : 1,
      end: 1,
    ),
    duration: _duration(context, 350),
    curve: Curves.easeOutCubic,
    builder: (_, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}
