/// Profil renseigné à la première connexion (stocké dans `users/{uid}`).
import 'package:flutter/material.dart';

class UserProfile {
  const UserProfile({
    required this.displayName,
    this.photoUrl,
    this.role = 'farmer',
    this.locality = '',
    this.crops = const [],
    this.languageCode = 'fr',
    this.aiLanguageCode = 'fr',
    this.notificationsEnabled = false,
    this.voiceReplies = false,
    this.themeMode = ThemeMode.system,
    this.completed = false,
  });

  static const roles = <String, String>{
    'farmer': 'Agriculteur',
    'vendor': "Vendeur d'intrants",
    'advisor': 'Conseiller agricole',
  };

  final String displayName;
  final String? photoUrl;
  final String role;
  final String locality;
  final List<String> crops;
  final String languageCode;
  final String aiLanguageCode;
  final bool notificationsEnabled;

  /// L'avatar lit ses réponses à voix haute (pour ceux qui lisent difficilement).
  final bool voiceReplies;
  final ThemeMode themeMode;
  final bool completed;

  String get roleLabel => roles[role] ?? roles['farmer']!;

  String get firstName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    String? role,
    String? locality,
    List<String>? crops,
    String? languageCode,
    String? aiLanguageCode,
    bool? notificationsEnabled,
    bool? voiceReplies,
    ThemeMode? themeMode,
    bool? completed,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      locality: locality ?? this.locality,
      crops: crops ?? this.crops,
      languageCode: languageCode ?? this.languageCode,
      aiLanguageCode: aiLanguageCode ?? this.aiLanguageCode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      voiceReplies: voiceReplies ?? this.voiceReplies,
      themeMode: themeMode ?? this.themeMode,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'photoUrl': photoUrl,
        'role': role,
        'locality': locality,
        'crops': crops,
        'languageCode': languageCode,
        'aiLanguageCode': aiLanguageCode,
        'notificationsEnabled': notificationsEnabled,
        'voiceReplies': voiceReplies,
        'themeMode': themeMode.index,
        'profileCompleted': completed,
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) {
    return UserProfile(
      displayName: (m['displayName'] as String?) ?? '',
      photoUrl: m['photoUrl'] as String?,
      role: (m['role'] as String?) ?? 'farmer',
      locality: (m['locality'] as String?) ?? '',
      crops: List<String>.from((m['crops'] as List?) ?? const []),
      languageCode: (m['languageCode'] as String?) ?? 'fr',
      aiLanguageCode: (m['aiLanguageCode'] as String?) ?? 'fr',
      notificationsEnabled: m['notificationsEnabled'] == true,
      voiceReplies: m['voiceReplies'] == true,
      themeMode: ThemeMode.values[(m['themeMode'] as int?) ?? 0],
      completed: m['profileCompleted'] == true,
    );
  }

  // Aliases for Supabase compatibility
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
