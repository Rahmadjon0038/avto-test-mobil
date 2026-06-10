class PasswordResetResponse {
  const PasswordResetResponse({
    required this.message,
    this.temporaryPassword,
    required this.sent,
  });

  final String message;
  final String? temporaryPassword;
  final bool sent;

  factory PasswordResetResponse.fromJson(Map<String, dynamic> json) {
    return PasswordResetResponse(
      message: (json['message'] ?? '').toString(),
      temporaryPassword: json['temporaryPassword']?.toString(),
      sent: json['sent'] == true,
    );
  }
}
