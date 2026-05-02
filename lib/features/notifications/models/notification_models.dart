// Modèle de notification locale — stockée dans SharedPreferences (JSON).
//
// Les notifications reçues via FCM sont converties en LocalNotification et
// persistées localement pour alimenter le centre de notifications (écran 27).
// Le champ [isRead] est mutable pour supporter le marquage "lu".

class LocalNotification {
  LocalNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.type,
    this.orderId,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final String? type;      // ex: 'order_status'
  final String? orderId;   // ID commande si type == 'order_status'
  final DateTime createdAt;
  bool isRead;

  factory LocalNotification.fromJson(Map<String, dynamic> json) =>
      LocalNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: json['type'] as String?,
        orderId: json['orderId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'orderId': orderId,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };
}
