// Étape 2/3 — choix du créneau pickup + notes/adresse.
//
// Contrainte backend : /appointments exige scheduled_from ≥ +2h.
// On refuse côté UI toute date avant minimumPickupTime.
// Les notes sont libres en V1 (adresse + instructions), la géoloc GPS
// sera ajoutée en ORDER-02.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../providers/order_draft_provider.dart';

class NewOrderPickupScreen extends StatefulWidget {
  const NewOrderPickupScreen({super.key});

  @override
  State<NewOrderPickupScreen> createState() => _NewOrderPickupScreenState();
}

class _NewOrderPickupScreenState extends State<NewOrderPickupScreen> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: context.read<OrderDraftProvider>().notes,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final draft = context.read<OrderDraftProvider>();
    final min = draft.minimumPickupTime;
    final initial = draft.pickupAt ?? min;

    // firstDate = le jour calendaire de minimumPickupTime (+2h).
    // Si on est à 23h, min pointe sur demain → aujourd'hui grisé.
    // Si on est à 10h, min pointe sur aujourd'hui → aujourd'hui sélectionnable.
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(min.year, min.month, min.day),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Jour de collecte',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Heure de collecte',
    );
    if (time == null || !mounted) return;

    final chosen = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // Garde-fou : si l'utilisateur a choisi aujourd'hui avec une heure
    // < +2h, on force à minimumPickupTime et on l'informe.
    if (chosen.isBefore(min)) {
      draft.setPickupAt(min);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Créneau ajusté — minimum 2h à partir de maintenant.'),
        ),
      );
    } else {
      draft.setPickupAt(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<OrderDraftProvider>();
    final pickupAt = draft.pickupAt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collecte'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Quand venons-nous collecter ?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule, color: AppColors.primary),
              title: Text(
                pickupAt == null
                    ? 'Choisir une date et heure'
                    : _formatPickup(pickupAt),
              ),
              subtitle: const Text(
                'Créneau de 2h. Minimum 2h à partir de maintenant.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDateTime,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Adresse & instructions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'Quartier, rue, point de repère, code portail, étage…',
              border: OutlineInputBorder(),
            ),
            onChanged: draft.setNotes,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: pickupAt == null
                  ? null
                  : () => context.push(Routes.newOrderSummary),
              child: const Text('Voir le récapitulatif'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
    );
  }

  static String _formatPickup(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final h = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '$d à $h';
  }
}
