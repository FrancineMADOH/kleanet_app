// Modèles Appointment — représente les rendez-vous de collecte et livraison.
// Renvoyé par GET /appointments/.
//
// Deux énumérations :
//   AppointmentType   : pickup (collecte) | delivery (livraison)
//   AppointmentStatus : scheduled | completed | cancelled

/// Type de rendez-vous — détermine l'icône et le libellé du badge.
enum AppointmentType {
  pickup,
  delivery;

  static AppointmentType fromJson(String raw) => switch (raw) {
        'pickup'   => AppointmentType.pickup,
        'delivery' => AppointmentType.delivery,
        _          => AppointmentType.pickup,
      };

  String get label => switch (this) {
        AppointmentType.pickup   => 'Collecte',
        AppointmentType.delivery => 'Livraison',
      };
}

/// Statut d'un rendez-vous — aligné sur l'enum Odoo `laundry.appointment.state`.
enum AppointmentStatus {
  scheduled,
  completed,
  cancelled;

  static AppointmentStatus fromJson(String raw) => switch (raw) {
        'scheduled' => AppointmentStatus.scheduled,
        'completed' => AppointmentStatus.completed,
        'cancelled' => AppointmentStatus.cancelled,
        _           => AppointmentStatus.scheduled,
      };

  String get label => switch (this) {
        AppointmentStatus.scheduled => 'Planifié',
        AppointmentStatus.completed => 'Effectué',
        AppointmentStatus.cancelled => 'Annulé',
      };
}

/// Rendez-vous de collecte ou livraison retourné par GET /appointments/.
class Appointment {
  const Appointment({
    required this.id,
    required this.reference,
    required this.type,
    required this.status,
    required this.scheduledFrom,
    this.orderId,
    this.notes,
  });

  final int id;
  final String reference;
  final AppointmentType type;
  final AppointmentStatus status;
  /// Date et heure planifiées, converties en heure locale de l'appareil.
  final DateTime scheduledFrom;
  /// Commande associée à ce rendez-vous — null si le lien n'est pas fourni.
  final int? orderId;
  final String? notes;

  /// true si le rendez-vous est encore à venir et non annulé.
  bool get isUpcoming =>
      status == AppointmentStatus.scheduled &&
      scheduledFrom.isAfter(DateTime.now());

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: (json['id'] as num).toInt(),
        reference: json['reference'] as String,
        type: AppointmentType.fromJson(json['type'] as String),
        status: AppointmentStatus.fromJson(json['status'] as String),
        scheduledFrom:
            DateTime.parse(json['scheduled_from'] as String).toLocal(),
        orderId: (json['order_id'] as num?)?.toInt(),
        notes: json['notes'] as String?,
      );
}
