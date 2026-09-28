// Écran marketplace (vente/achat récoltes). Issue GitHub : #TODO
import 'package:flutter/material.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MarketplaceScreen')),
      body: const Center(child: Text('MarketplaceScreen - à implémenter')),
    );
  }
}
