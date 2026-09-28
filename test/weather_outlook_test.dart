import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/services/weather_service.dart';

WeatherOutlook outlook({required List<int> rain, required List<num> humidity, required List<num> temp}) =>
    WeatherOutlook(precipitationProbabilityPct: rain, humidityPct: humidity, maxTempC: temp);

void main() {
  group('WeatherOutlook', () {
    test('risque fongique : 2 jours humides et pluvieux', () {
      final o = outlook(rain: [70, 80, 10], humidity: [85, 90, 50], temp: [30, 31, 32]);
      expect(o.highFungalRisk, isTrue);
      expect(o.heatStressRisk, isFalse);
    });

    test('un seul jour à risque ne suffit pas', () {
      final o = outlook(rain: [70, 10, 10], humidity: [85, 60, 50], temp: [30, 31, 32]);
      expect(o.highFungalRisk, isFalse);
    });

    test('stress hydrique : 2 jours très chauds et secs', () {
      final o = outlook(rain: [5, 10, 50], humidity: [30, 30, 40], temp: [39, 41, 30]);
      expect(o.heatStressRisk, isTrue);
      expect(o.highFungalRisk, isFalse);
    });

    test('un jour de chaleur seulement : pas d\'alerte', () {
      final o = outlook(rain: [5, 10, 50], humidity: [30, 30, 40], temp: [39, 30, 30]);
      expect(o.heatStressRisk, isFalse);
    });
  });
}
