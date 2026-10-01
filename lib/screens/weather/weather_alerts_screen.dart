// Écran alertes météo. Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/theme.dart';
import '../../services/external/weather_service.dart';
import '../../widgets/k_components.dart';

class WeatherAlertsScreen extends StatefulWidget {
  const WeatherAlertsScreen({super.key});

  @override
  State<WeatherAlertsScreen> createState() => _WeatherAlertsScreenState();
}

class _WeatherAlertsScreenState extends State<WeatherAlertsScreen> {
  final WeatherService _weatherService = WeatherService();

  WeatherOutlook? _outlook;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final position = await _getUserPosition();

      if (position == null) {
        throw Exception('Permission de localisation refusée');
      }

      final outlook = await _weatherService.fetchOutlook(
        lat: position.latitude,
        lng: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _outlook = outlook;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _outlook = null;
        _errorMessage = _cleanErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<Position?> _getUserPosition() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Service de localisation désactivé');
    }

    return Geolocator.getCurrentPosition();
  }

  String _cleanErrorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes météo'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _loadWeather,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    final outlook = _outlook;

    if (outlook == null) {
      return _buildError(
        message: 'Impossible de récupérer les prévisions météo.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWeather,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFungalBanner(outlook),
          const SizedBox(height: 12),
          _buildHeatBanner(outlook),
          const SizedBox(height: 24),
          const Text(
            'Prévisions 3 jours',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildForecastRows(outlook),
        ],
      ),
    );
  }

  Widget _buildFungalBanner(WeatherOutlook outlook) {
    final status = KultivTheme.status(context);

    if (outlook.highFungalRisk) {
      return StatusBanner(
        tone: status.danger,
        icon: Icons.warning_amber_rounded,
        title: 'Risque élevé de maladie fongique',
        subtitle:
        'Humidité et pluie élevées prévues plusieurs jours : surveillez vos cultures (mildiou, rouille...).',
      );
    }

    return StatusBanner(
      tone: status.success,
      icon: Icons.check_circle_outline,
      title: 'Pas de risque élevé détecté',
      subtitle:
      'Conditions météo actuellement peu favorables aux maladies fongiques.',
    );
  }

  Widget _buildHeatBanner(WeatherOutlook outlook) {
    if (!outlook.heatStressRisk) {
      return const SizedBox.shrink();
    }

    final status = KultivTheme.status(context);

    return StatusBanner(
      tone: status.warning,
      icon: Icons.wb_sunny_outlined,
      title: 'Forte chaleur annoncée',
      subtitle:
      'Arrosez tôt le matin ou en fin de journée pour éviter le stress hydrique.',
    );
  }

  List<Widget> _buildForecastRows(WeatherOutlook outlook) {
    final days = _forecastLength(outlook);

    return List.generate(
      days,
          (index) => _buildForecastRow(outlook, index),
    );
  }

  int _forecastLength(WeatherOutlook outlook) {
    return [
      outlook.maxTempC.length,
      outlook.humidityPct.length,
      outlook.precipitationProbabilityPct.length,
    ].reduce((a, b) => a < b ? a : b).clamp(0, 3);
  }

  Widget _buildForecastRow(WeatherOutlook outlook, int index) {
    final temperature = outlook.maxTempC[index];
    final humidity = outlook.humidityPct[index];
    final rain = outlook.precipitationProbabilityPct[index];

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _weatherIcon(rain),
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Jour ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _ForecastValue(
              icon: Icons.thermostat_outlined,
              value: '${temperature.toStringAsFixed(0)} °C',
              tooltip: 'Température maximale',
            ),
            const SizedBox(width: 12),
            _ForecastValue(
              icon: Icons.water_drop_outlined,
              value: '${humidity.toStringAsFixed(0)} %',
              tooltip: 'Humidité maximale',
            ),
            const SizedBox(width: 12),
            _ForecastValue(
              icon: Icons.umbrella_outlined,
              value: '$rain %',
              tooltip: 'Probabilité de pluie',
            ),
          ],
        ),
      ),
    );
  }

  IconData _weatherIcon(int rainProbability) {
    if (rainProbability >= 60) {
      return Icons.cloudy_snowing;
    }

    if (rainProbability >= 30) {
      return Icons.cloud_outlined;
    }

    return Icons.wb_sunny_outlined;
  }

  Widget _buildError({String? message}) {
    final text =
        message ??
            _errorMessage ??
            'Une erreur est survenue lors du chargement des données météo.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _loadWeather,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastValue extends StatelessWidget {
  const _ForecastValue({
    required this.icon,
    required this.value,
    required this.tooltip,
  });

  final IconData icon;
  final String value;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(value),
        ],
      ),
    );
  }
}