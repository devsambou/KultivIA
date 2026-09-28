import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/external/weather_service.dart';
import '../widgets/k_components.dart';
import '../core/theme/theme.dart';

/// Fonctionnalité 5.2 : historique météo et alertes, à partir de vraies
/// données Open-Meteo (gratuit, sans clé) et de la position de l'utilisateur.
class WeatherAlertsScreen extends StatefulWidget {
  const WeatherAlertsScreen({super.key});

  @override
  State<WeatherAlertsScreen> createState() => _WeatherAlertsScreenState();
}

class _WeatherAlertsScreenState extends State<WeatherAlertsScreen> {
  final _service = WeatherService();
  WeatherOutlook? _outlook;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Permission de localisation refusée');
      }
      final pos = await Geolocator.getCurrentPosition();
      final outlook = await _service.fetchOutlook(lat: pos.latitude, lng: pos.longitude);
      setState(() {
        _outlook = outlook;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes météo'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpace.xl),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Réessayer')),
                    ]),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(KSpace.lg),
                  children: [
                    if (_outlook!.highFungalRisk)
                      StatusBanner(
                        tone: KultivTheme.status(context).danger,
                        icon: Icons.warning_amber_rounded,
                        title: 'Risque élevé de maladie fongique',
                        subtitle: 'Humidité et pluie élevées prévues plusieurs jours : surveillez vos cultures (mildiou, rouille...).',
                      )
                    else
                      if (!_outlook!.heatStressRisk)
                        StatusBanner(
                          tone: KultivTheme.status(context).success,
                          icon: Icons.check_circle_outline,
                          title: 'Pas de risque élevé détecté',
                          subtitle: 'Conditions météo actuellement peu favorables aux maladies fongiques.',
                        ),
                    if (_outlook!.heatStressRisk) ...[
                      if (_outlook!.highFungalRisk) const SizedBox(height: KSpace.md),
                      StatusBanner(
                        tone: KultivTheme.status(context).warning,
                        icon: Icons.wb_sunny_outlined,
                        title: 'Forte chaleur annoncée',
                        subtitle: 'Arrosez tôt le matin ou en fin de journée pour éviter le stress hydrique.',
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Prévisions 3 jours', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _outlook!.humidityPct.length; i++)
                      KCard(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today, size: 20),
                          title: Text('Jour ${i + 1}'),
                          subtitle: Text(
                            'Humidité ${_outlook!.humidityPct[i].round()}% · '
                            'Pluie ${i < _outlook!.precipitationProbabilityPct.length ? _outlook!.precipitationProbabilityPct[i] : "?"}% · '
                            'Max ${i < _outlook!.maxTempC.length ? _outlook!.maxTempC[i].round() : "?"}°C',
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
