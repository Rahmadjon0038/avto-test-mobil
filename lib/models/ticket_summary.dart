class TicketSummary {
  TicketSummary({
    required this.id,
    required this.title,
    required this.locked,
  });

  final String id;
  final String title;
  final bool locked;

  factory TicketSummary.fromJson(Map<String, dynamic> json) {
    return TicketSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      locked: json['locked'] == true,
    );
  }
}
