// Repository Appointment — accès HTTP pour GET /appointments/.
//
// Retourne tous les rendez-vous du client courant (identifié par le JWT).
// Aucune logique de tri ici — le provider trie après réception pour
// séparer les responsabilités : accès réseau vs. logique de présentation.

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../models/appointment_models.dart';

class AppointmentRepository {
  AppointmentRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Charge tous les rendez-vous du client courant.
  /// L'API retourne une liste brute — on mappe chaque élément vers [Appointment].
  Future<List<Appointment>> listAppointments() async {
    final response =
        await _apiClient.get<List<dynamic>>(ApiEndpoints.appointments);
    return (response.data ?? <dynamic>[])
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
