import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'notification_inbox.dart';
import '../services/push_notification_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final service = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    service.start();
    PushNotificationService.instance.start();
    PushNotificationService.instance.openInboxRequested.addListener(
      _openPending,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
  }

  bool _inboxOpen = false;

  void _openPending() {
    if (!mounted ||
        !PushNotificationService.instance.openInboxRequested.value) {
      return;
    }
    PushNotificationService.instance.openInboxRequested.value = false;
    service.refresh();
    _openInbox();
  }

  Future<void> _openInbox() async {
    if (_inboxOpen || !mounted) return;
    _inboxOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x990D1715),
      builder: (_) => NotificationInbox(service: service),
    );
    _inboxOpen = false;
  }

  @override
  void dispose() {
    PushNotificationService.instance.openInboxRequested.removeListener(
      _openPending,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => IconButton(
      tooltip: 'Notifications',
      onPressed: _openInbox,
      icon: Badge(
        isLabelVisible: service.unreadCount > 0,
        label: Text(
          service.unreadCount > 99 ? '99+' : '${service.unreadCount}',
        ),
        child: const Icon(Icons.notifications_none_rounded, size: 27),
      ),
    ),
  );
}
