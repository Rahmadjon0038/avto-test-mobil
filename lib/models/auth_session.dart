class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.user,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final Map<String, dynamic> user;

  String get userName {
    final candidates = <String?>[
      user['fullName']?.toString(),
      user['full_name']?.toString(),
      user['fullname']?.toString(),
      user['name']?.toString(),
      user['firstName']?.toString(),
      user['first_name']?.toString(),
    ];
    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final phone = user['phone']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return 'Foydalanuvchi';
  }

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'user': user,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: json['refreshToken']?.toString(),
      user: Map<String, dynamic>.from(json['user'] as Map? ?? {}),
    );
  }
}
