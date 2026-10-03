import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/system/app_state.dart';
import '../../services/system/connectivity_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().historyList;

    // « Aucun diagnostic » et « pas encore chargé » ne se ressemblent pas
    // (issue C6) : hors ligne, l'historique peut simplement ne pas être
    // arrivé. Annoncer « aucun diagnostic » dans ce cas serait mentir, et le
    // paysan croirait avoir perdu son travail.
    final isOffline = context.select<ConnectivityService, bool>(
      (c) => c.isKnown && !c.isOnline,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des diagnostics')),
      body: history.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  isOffline
                      ? 'Hors connexion. Vos diagnostics s’afficheront au retour du réseau.'
                      : 'Aucun diagnostic pour le moment.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
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