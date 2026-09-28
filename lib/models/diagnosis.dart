/// Résultat d'un diagnostic (photo, texte ou vocal).
class Diagnosis {
  final String id;
  final DateTime date;
  final String? imagePath;
  final String inputText;
  final String disease;
  final double confidence; // 0.0 à 1.0
  final String advice;
  final String rawAiResponse;

  Diagnosis({
    required this.id,
    required this.date,
    this.imagePath,
    required this.inputText,
    required this.disease,
    required this.confidence,
    required this.advice,
    required this.rawAiResponse,
  });

  factory Diagnosis.fromAiJson(
    Map<String, dynamic> json, {
    required String inputText,
    String? imagePath,
    required String rawAiResponse,
  }) {
    return Diagnosis(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      imagePath: imagePath,
      inputText: inputText,
      disease: (json['maladie'] ?? json['disease'] ?? 'Indéterminé').toString(),
      confidence: _asDouble(json['confiance'] ?? json['confidence']),
      advice: (json['traitement'] ?? json['advice'] ?? '').toString(),
      rawAiResponse: rawAiResponse,
    );
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble().clamp(0.0, 1.0);
    return double.tryParse(v.toString())?.clamp(0.0, 1.0) ?? 0.0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'imagePath': imagePath,
        'inputText': inputText,
        'disease': disease,
        'confidence': confidence,
        'advice': advice,
      };

  // Aliases for Supabase compatibility
  factory Diagnosis.fromJson(Map<String, dynamic> json) {
    return Diagnosis(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      imagePath: json['imagePath'] as String?,
      inputText: json['inputText'] as String,
      disease: json['disease'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      advice: json['advice'] as String,
      rawAiResponse: json['rawAiResponse'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => toMap();
}

/// Un message dans la conversation avec l'avatar IA.
class ChatEntry {
  final bool fromUser;
  final String text;
  final String? imagePath;
  final Diagnosis? diagnosis; // carte « voir le diagnostic » sous la réponse

  ChatEntry({required this.fromUser, required this.text, this.imagePath, this.diagnosis});
}
