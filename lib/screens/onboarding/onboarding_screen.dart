// Écran d'onboarding (slides de présentation). Issue GitHub : #TODO
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OnboardingScreen')),
      body: const Center(child: Text('OnboardingScreen - à implémenter')),
    );
  }
}
