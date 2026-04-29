// Provider Appointments — charge et expose la liste des rendez-vous du client.
//
// Instancié en factory sur la route /profile/appointments (pas au niveau app)
// car il n'est utilisé que dans cet unique écran. Le load() est déclenché
// depuis l'initState de AppointmentsScreen.
//
// Tri appliqué après chargement :
//   1. À venir (scheduled + scheduledFrom futur) — chronologique croissant
//   2. Passés (completed) — chronologique croissant
//   3. Annulés (cancelled) — chronologique croissant

import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../models/appointment_models.dart';
import '../repositories/appointment_repository.dart';

class AppointmentsProvider extends ChangeNotifier {
  AppointmentsProvider({required AppointmentRepository repository})
      : _repository = repository;

  final AppointmentRepository _repository;

  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _error;

  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge les rendez-vous depuis l'API, trie le résultat et notifie l'UI.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final raw = await _repository.listAppointments();
      _appointments = _sort(raw);
    } on ApiException catch (e) {
      _error = e.message;
    } on Exception catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[AppointmentsProvider] load error: $e\n$stack');
      }
      _error = 'Impossible de charger les rendez-vous.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Trie : à venir (0) → passés (1) → annulés (2), chronologique dans chaque groupe.
  static List<Appointment> _sort(List<Appointment> list) {
    int priority(Appointment a) {
      if (a.status == AppointmentStatus.cancelled) return 2;
      if (a.isUpcoming) return 0;
      return 1;
    }

    return list
      ..sort((a, b) {
        final p = priority(a).compareTo(priority(b));
        if (p != 0) return p;
        return a.scheduledFrom.compareTo(b.scheduledFrom);
      });
  }
}
