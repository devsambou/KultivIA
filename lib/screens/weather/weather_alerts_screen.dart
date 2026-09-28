// Écran alertes météo. Issue GitHub : #TODO
import 'package:flutter/material.dart';

class WeatherAlertsScreen extends StatefulWidget {
  const WeatherAlertsScreen({super.key});

  @override
  State<WeatherAlertsScreen> createState() => _WeatherAlertsScreenState();
}

class _WeatherAlertsScreenState extends State<WeatherAlertsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WeatherAlertsScreen')),
      body: const Center(child: Text('WeatherAlertsScreen - à implémenter')),
    );
  }
}
