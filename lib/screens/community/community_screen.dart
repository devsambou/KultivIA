// Écran communautaire (signalements partagés). Issue GitHub : #TODO
import 'package:flutter/material.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.prefillDisease});
  final String? prefillDisease;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CommunityScreen')),
      body: const Center(child: Text('CommunityScreen - à implémenter')),
    );
  }
}
