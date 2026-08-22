// ignore_for_file: prefer_single_quotes
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/notification_service.dart';

// ══════════════════════════════════════════════════════════
// NOTIFICATIONS SCREEN
// ══════════════════════════════════════════════════════════
class NotificationsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const NotificationsScreen({super.key, required this.onBack});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await NotificationService.loadAll();
    if (mounted) setState(() { _notifs = list; _loading = false; });
  }

  Future<void> _markAllRead() async {
    HapticFeedback.lightImpact();
    await NotificationService.markAllRead();
    await _load();
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    await NotificationService.markRead(n.id);
    setState(() => n.isRead = true);
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifs.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 12, left: 16, right: 16,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppTheme.text),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Notificações',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text)),
                      if (unread > 0)
                        Text('$unread não lidas',
                            style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
                    ],
                  ),
                ),
                if (unread > 0)
                  GestureDetector(
                    onTap: _markAllRead,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text('Marcar todas lidas',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                    ),
                  ),
              ],
            ),
          ),

          // Corpo
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_rounded, size: 52, color: AppTheme.textLight),
                            const SizedBox(height: 12),
                            const Text('Nenhuma notificação',
                                style: TextStyle(fontSize: 15, color: AppTheme.textMuted)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _NotifCard(
                          notif: _notifs[i],
                          onTap: () => _markRead(_notifs[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;

  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: notif.isRead ? AppTheme.surface : AppTheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: notif.isRead ? AppTheme.border : AppTheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: notif.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(notif.icon, color: notif.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notif.title,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: notif.isRead ? AppTheme.text : AppTheme.text,
                            )),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(notif.body,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(notif.timeAgo,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
