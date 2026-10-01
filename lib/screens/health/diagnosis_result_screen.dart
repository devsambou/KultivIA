import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/diagnosis.dart';
import '../../services/system/app_state.dart';
import '../../services/ui/voice_service.dart';
import '../../screens/community/community_screen.dart';
import '../../screens/market/marketplace_screen.dart';
import 'health_dashboard_screen.dart';
import '../../widgets/k_components.dart';
import '../../core/theme/theme.dart';

class DiagnosisResultScreen extends StatelessWidget {
  DiagnosisResultScreen({super.key, required this.diagnosis});
  final Diagnosis diagnosis;
  final _voice = VoiceService();

  @override
  Widget build(BuildContext context) {
    final confidencePct = (diagnosis.confidence * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Résultat du diagnostic')),
      body: ListView(
        padding: const EdgeInsets.all(KSpace.lg),
        children: [
          if (diagnosis.imagePath != null)
            ClipRRect(
              borderRadius: KRadius.sm,
              child: Image.file(File(diagnosis.imagePath!), height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          const SizedBox(height: 16),
          Text(diagnosis.disease,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(
              label: 'Confiance : $confidencePct %',
              tone: KultivTheme.status(context).forConfidence(diagnosis.confidence),
              icon: Icons.verified,
            ),
          ),
          const SizedBox(height: 20),
          KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Traitement conseillé', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(diagnosis.advice.isEmpty ? 'Aucun conseil disponible.' : diagnosis.advice),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              final text = diagnosis.advice.isEmpty ? diagnosis.disease : diagnosis.advice;
              _voice.speak(text, languageCode: context.read<AppState>().languageCode);
            },
            icon: const Icon(Icons.volume_up),
            label: const Text('Écouter le conseil'),
          ),
          const SizedBox(height: 24),
          Text('Aller plus loin', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.storefront,
            title: "Points de vente d'intrants à proximité",
            subtitle: 'Carte géolocalisée par distance',
            onTap: () => Navigator.of(context).pushNamed('/vendors'),
          ),
          _ActionTile(
            icon: Icons.cloud_outlined,
            title: 'Alertes météo pour cette maladie',
            subtitle: 'Prévention en amont des symptômes',
            onTap: () => Navigator.of(context).pushNamed('/weather'),
          ),
          _ActionTile(
            icon: Icons.groups_outlined,
            title: 'Signalements proches de chez vous',
            subtitle: 'Partage communautaire',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CommunityScreen(prefillDisease: diagnosis.disease)),
            ),
          ),
          _ActionTile(
            icon: Icons.storefront_outlined,
            title: 'Vendre ma récolte',
            subtitle: 'Marketplace acheteur/vendeur',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MarketplaceScreen()),
            ),
          ),
          _ActionTile(
            icon: Icons.dashboard_outlined,
            title: "Score de santé de l'exploitation",
            subtitle: 'Vue d\'ensemble de vos diagnostics',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HealthDashboardScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}