import 'dart:convert';

import 'package:http/http.dart' as http;

/// Relevés météo réels via Open-Meteo (gratuit, sans clé API).
/// Documentation : https://open-meteo.com/en/docs

/// Règle simple, locale, sans appel IA : humidité élevée + pluie probable
/// sur au moins 2 des 3 prochains jours = risque élevé de maladie
/// fongique (mildiou, rouille...). Affinez ce seuil avec vos agronomes.
bool _highFungalRisk(List<int> precipPct, List<num> humidityPct) {
  var riskyDays = 0;
  for (var i = 0; i < humidityPct.length; i++) {
    final humid = humidityPct[i] >= 80;
    final rain = i < precipPct.length && precipPct[i] >= 60;
    if (humid && rain) riskyDays++;
  }
  return riskyDays >= 2;
}

/// Forte chaleur (38 °C et plus) avec très peu de pluie (20 % ou moins)
/// sur au moins 2 jours : risque de stress hydrique pour les cultures.
bool _heatStressRisk(List<int> precipPct, List<num> maxTempC) {
  var hotDryDays = 0;
  for (var i = 0; i < maxTempC.length; i++) {
    final hot = maxTempC[i] >= 38;
    final dry = i < precipPct.length && precipPct[i] <= 20;
    if (hot && dry) hotDryDays++;
  }
  return hotDryDays >= 2;
}

class WeatherService {
  final http.Client _client;

  WeatherService([http.Client? client]) : _client = client ?? http.Client();

  Future<WeatherOutlook> fetchOutlook({required double lat, required double lng}) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lng'
      '&daily=precipitation_probability_max,relative_humidity_2m_max,temperature_2m_max'
      '&forecast_days=3&timezone=auto',
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Erreur météo (${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    return WeatherOutlook(
      precipitationProbabilityPct: List<int>.from(daily['precipitation_probability_max'] ?? []),
      humidityPct: List<num>.from(daily['relative_humidity_2m_max'] ?? []),
      maxTempC: List<num>.from(daily['temperature_2m_max'] ?? []),
    );
  }
}

class WeatherOutlook {
  final List<int> precipitationProbabilityPct;
  final List<num> humidityPct;
  final List<num> maxTempC;

  WeatherOutlook({
    required this.precipitationProbabilityPct,
    required this.humidityPct,
    required this.maxTempC,
  });

  /// Risque élevé de maladie fongique.
  bool get highFungalRisk => _highFungalRisk(precipitationProbabilityPct, humidityPct);

  /// Risque de stress hydrique.
  bool get heatStressRisk => _heatStressRisk(precipitationProbabilityPct, maxTempC);
}
