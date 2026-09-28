/// Profil renseigné à la première connexion (stocké dans `users/{uid}`).
class UserProfile {
  const UserProfile({
    required this.displayName,
    this.role = 'farmer',
    this.locality = '',
    this.crops = const [],
    this.languageCode = 'fr',
    this.notificationsEnabled = false,
    this.voiceReplies = false,
    this.completed = false,
  });

  static const roles = <String, String>{
    'farmer': 'Agriculteur',
    'vendor': "Vendeur d'intrants",
    'advisor': 'Conseiller agricole',
  };

  final String displayName;
  final String role;
  final String locality;
  final List<String> crops;
  final String languageCode;
  final bool notificationsEnabled;

  /// L'avatar lit ses réponses à voix haute (pour ceux qui lisent difficilement).
  final bool voiceReplies;
  final bool completed;

  String get roleLabel => roles[role] ?? roles['farmer']!;

  String get firstName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  UserProfile copyWith({
    String? displayName,
    String? role,
    String? locality,
    List<String>? crops,
    String? languageCode,
    bool? notificationsEnabled,
    bool? voiceReplies,
    bool? completed,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      locality: locality ?? this.locality,
      crops: crops ?? this.crops,
      languageCode: languageCode ?? this.languageCode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      voiceReplies: voiceReplies ?? this.voiceReplies,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'role': role,
        'locality': locality,
        'crops': crops,
        'languageCode': languageCode,
        'notificationsEnabled': notificationsEnabled,
        'voiceReplies': voiceReplies,
        'profileCompleted': completed,
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) {
    return UserProfile(
      displayName: (m['displayName'] as String?) ?? '',
      role: (m['role'] as String?) ?? 'farmer',
      locality: (m['locality'] as String?) ?? '',
      crops: List<String>.from((m['crops'] as List?) ?? const []),
      languageCode: (m['languageCode'] as String?) ?? 'fr',
      notificationsEnabled: m['notificationsEnabled'] == true,
      voiceReplies: m['voiceReplies'] == true,
      completed: m['profileCompleted'] == true,
    );
  }
}
