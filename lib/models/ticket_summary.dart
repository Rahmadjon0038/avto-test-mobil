class TicketSummary {
  TicketSummary({
    required this.id,
    required this.title,
    required this.locked,
    this.questionsCount,
  });

  final String id;
  final String title;
  final bool locked;
  final int? questionsCount;

  factory TicketSummary.fromJson(Map<String, dynamic> json) {
    return TicketSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      locked: json['locked'] == true,
      questionsCount: int.tryParse(json['questionsCount']?.toString() ?? ''),
    );
  }
}
