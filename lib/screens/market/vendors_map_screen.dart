// Écran carte des vendeurs d'intrants. Issue GitHub : #TODO
import 'package:flutter/material.dart';

class VendorsMapScreen extends StatefulWidget {
  const VendorsMapScreen({super.key});

  @override
  State<VendorsMapScreen> createState() => _VendorsMapScreenState();
}

class _VendorsMapScreenState extends State<VendorsMapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VendorsMapScreen')),
      body: const Center(child: Text('VendorsMapScreen - à implémenter')),
    );
  }
}
