import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:kultivia/services/external/weather_service.dart';

/// Client HTTP factice qui renvoie une réponse programmée.
class _FakeClient extends BaseClient {
  _FakeClient(this._streamedResponse);
  final StreamedResponse _streamedResponse;

  @override
  Future<StreamedResponse> send(BaseRequest request) async => _streamedResponse;
}

StreamedResponse _okJsonStream(Map<String, dynamic> daily) => StreamedResponse(
      Stream.value(jsonEncode({'daily': daily}).codeUnits),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  // ---------- highFungalRisk ----------

  group('highFungalRisk', () {
    test('liste vide → faux', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [],
        humidityPct: [],
        maxTempC: [],
      );
      expect(o.highFungalRisk, isFalse);
    });

    test('humidité 79 % (en dessous du seuil) → faux', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [70, 70, 70],
        humidityPct: [79, 79, 79],
        maxTempC: [30, 30, 30],
      );
      expect(o.highFungalRisk, isFalse);
    });

    test('humidité 80 % et pluie 60 % sur 2 jours → vrai', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [60, 60, 60],
        humidityPct: [80, 80, 80],
        maxTempC: [30, 30, 30],
      );
      expect(o.highFungalRisk, isTrue);
    });

    test('humidité 80 % et pluie 60 % sur 1 seul jour → faux', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [60, 30, 30],
        humidityPct: [80, 70, 70],
        maxTempC: [30, 30, 30],
      );
      expect(o.highFungalRisk, isFalse);
    });

    test('pluie 59 % (en dessous du seuil) → faux', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [59, 59, 59],
        humidityPct: [80, 80, 80],
        maxTempC: [30, 30, 30],
      );
      expect(o.highFungalRisk, isFalse);
    });

    test('listes de longueurs différentes → utilise le minimum', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [60, 60],
        humidityPct: [80, 80, 80, 80],
        maxTempC: [30],
      );
      expect(o.highFungalRisk, isTrue); // 2 jours sur 2 → vrai
    });
  });

  // ---------- heatStressRisk ----------

  group('heatStressRisk', () {
    test('liste vide → faux', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [],
        humidityPct: [],
        maxTempC: [],
      );
      expect(o.heatStressRisk, isFalse);
    });

    test('température 37 °C (en dessous du seuil) → faux', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [10, 10, 10],
        humidityPct: [50, 50, 50],
        maxTempC: [37, 37, 37],
      );
      expect(o.heatStressRisk, isFalse);
    });

    test('température 38 °C et pluie ≤ 20 % sur 2 jours → vrai', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [20, 20, 20],
        humidityPct: [50, 50, 50],
        maxTempC: [38, 38, 38],
      );
      expect(o.heatStressRisk, isTrue);
    });

    test('température 38 °C mais pluie 21 % → faux', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [21, 21, 21],
        humidityPct: [50, 50, 50],
        maxTempC: [38, 38, 38],
      );
      expect(o.heatStressRisk, isFalse);
    });

    test('1 seul jour chaud → faux', () {
      final o = WeatherOutlook(
        precipitationProbabilityPct: [10, 50, 50],
        humidityPct: [50, 50, 50],
        maxTempC: [38, 30, 30],
      );
      expect(o.heatStressRisk, isFalse);
    });
  });

  // ---------- fetchOutlook (avec faux client HTTP) ----------

  group('fetchOutlook', () {
    test('réponse 200 → WeatherOutlook', () async {
      final client = _FakeClient(_okJsonStream({
        'precipitation_probability_max': [60, 70, 80],
        'relative_humidity_2m_max': [80, 85, 90],
        'temperature_2m_max': [30, 35, 38],
      }));
      final service = WeatherService(client);
      final outlook = await service.fetchOutlook(lat: 14.67, lng: -17.43);

      expect(outlook.precipitationProbabilityPct, [60, 70, 80]);
      expect(outlook.humidityPct, [80, 85, 90]);
      expect(outlook.maxTempC, [30, 35, 38]);
    });

    test('réponse 200 avec highFungalRisk → vrai', () async {
      final client = _FakeClient(_okJsonStream({
        'precipitation_probability_max': [60, 60, 60],
        'relative_humidity_2m_max': [80, 80, 80],
        'temperature_2m_max': [30, 30, 30],
      }));
      final service = WeatherService(client);
      final outlook = await service.fetchOutlook(lat: 14, lng: -17);
      expect(outlook.highFungalRisk, isTrue);
    });

    test('erreur 500 → lance une exception', () async {
      final client = _FakeClient(
        StreamedResponse(Stream.value(''.codeUnits), 500),
      );
      final service = WeatherService(client);
      expect(
        service.fetchOutlook(lat: 14, lng: -17),
        throwsA(isA<Exception>()),
      );
    });
  });
}
