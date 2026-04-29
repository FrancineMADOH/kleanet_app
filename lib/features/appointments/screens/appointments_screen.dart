// Écran liste des rendez-vous (Écran 21 du plan).
//
// Route pushée depuis ProfileScreen (/profile/appointments).
// AppointmentsProvider est instancié en factory sur cette route dans
// app_router.dart — il est scopé à cet écran et libéré à la fermeture.
//
// Affichage :
//   - Spinner pendant le chargement
//   - Message d'erreur + retry
//   - Liste vide avec icône calendrier
//   - ListView de _AppointmentTile, triés par AppointmentsProvider :
//       1. À venir (planifiés + date future)  → badge vert
//       2. Passés (effectués)                 → badge gris
//       3. Annulés                            → badge rouge

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../models/appointment_models.dart';
import '../providers/appointments_provider.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  @override
  void initState() {
    super.initState();
    // Chargement initial déclenché post-frame — le provider est déjà dans l'arbre.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppointmentsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes rendez-vous'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppointmentsProvider>().load(),
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(AppointmentsProvider provider) {
    if (provider.isLoading && provider.appointments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.appointments.isEmpty) {
      return _buildError(provider.error!);
    }
    if (provider.appointments.isEmpty) {
      return _buildEmpty();
    }
    return _buildList(provider.appointments);
  }

  Widget _buildError(String message) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off, size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: () => context.read<AppointmentsProvider>().load(),
            child: const Text('Réessayer'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 80),
        Icon(
          Icons.calendar_month_outlined,
          size: 64,
          color: AppColors.textSecondary,
        ),
        SizedBox(height: 16),
        Text(
          'Aucun rendez-vous planifié',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Vos collectes et livraisons apparaîtront ici.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildList(List<Appointment> appointments) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _AppointmentTile(apt: appointments[i]),
    );
  }
}

// ----------------------------------------------------------------
// Tuile rendez-vous
// ----------------------------------------------------------------

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.apt});
  final Appointment apt;

  @override
  Widget build(BuildContext context) {
    final icon = apt.type == AppointmentType.pickup
        ? Icons.directions_bike
        : Icons.local_shipping_outlined;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent1.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.accent1),
        ),
        title: Text(
          '${apt.type.label} — ${_formatDate(apt.scheduledFrom)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          apt.reference,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: _StatusBadge(status: apt.status),
      ),
    );
  }

  /// Formate une date locale : "Jeu. 29 avr. à 14:30"
  static String _formatDate(DateTime dt) {
    const days = [
      'Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'
    ];
    const months = [
      'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'jui.',
      'juil.', 'aoû.', 'sep.', 'oct.', 'nov.', 'déc.'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]} à $h:$m';
  }
}

// ----------------------------------------------------------------
// Badge de statut
// ----------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AppointmentStatus.scheduled => (status.label, AppColors.success),
      AppointmentStatus.completed => (status.label, AppColors.textSecondary),
      AppointmentStatus.cancelled => (status.label, AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
