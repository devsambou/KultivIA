// Service météo. Issue GitHub : #TODO

class WeatherService {
  Future<WeatherOutlook> fetchOutlook({required double lat, required double lng}) {
    throw UnimplementedError();
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

  bool get highFungalRisk {
    throw UnimplementedError();
  }

  bool get heatStressRisk {
    throw UnimplementedError();
  }
}
