import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/system/app_state.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().historyList;

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des diagnostics')),
      body: history.isEmpty
          ? const Center(child: Text('Aucun diagnostic pour le moment.'))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, i) {
                final d = history[i];
                return ListTile(
                  leading: const Icon(Icons.eco),
                  title: Text(d.disease),
                  subtitle: Text('${d.date.day}/${d.date.month}/${d.date.year} · confiance ${(d.confidence * 100).round()}%'),
                  onTap: () => Navigator.of(context).pushNamed('/result', arguments: d),
                );
              },
            ),
    );
  }
}
