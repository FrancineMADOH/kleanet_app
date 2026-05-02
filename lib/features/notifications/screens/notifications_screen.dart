// Centre de notifications — Écran 27 du plan.
//
// Affiche la liste des notifications reçues via FCM (stockées localement).
// En entrant dans cet écran, toutes les notifications sont marquées comme lues
// (badge 🔔 remis à zéro). En tapant une notification de type 'order_status',
// l'utilisateur est renvoyé vers le détail de la commande concernée.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../models/notification_models.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Marque tout comme lu dès que l'utilisateur ouvre l'écran.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      body: notifications.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, index) => _NotifTile(
                notif: notifications[index],
                onTap: () => _onTap(context, notifications[index]),
              ),
            ),
    );
  }

  void _onTap(BuildContext context, LocalNotification notif) {
    // Si la notification est liée à une commande, naviguer vers son détail.
    if (notif.type == 'order_status' && notif.orderId != null) {
      context.push(Routes.orderDetail(notif.orderId!));
    }
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notif, required this.onTap});
  final LocalNotification notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: notif.type == 'order_status' ? onTap : null,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: notif.isRead
              ? AppColors.surface
              : AppColors.accent1.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _iconForType(notif.type),
          color: notif.isRead ? AppColors.textSecondary : AppColors.accent1,
          size: 22,
        ),
      ),
      title: Text(
        notif.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            notif.body,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(notif.createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
      // Point bleu si non lue.
      trailing: notif.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent1,
                shape: BoxShape.circle,
              ),
            ),
    );
  }

  IconData _iconForType(String? type) {
    return switch (type) {
      'order_status' => Icons.local_laundry_service_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous serez notifié(e) des\nmises à jour de vos commandes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
