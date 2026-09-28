import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/k_components.dart';
import '../core/theme/theme.dart';

/// Fonctionnalité 5.3 : marketplace intégré (ODD 8). Met en relation un
/// agriculteur diagnostiqué (culture saine) avec un acheteur.
///
/// Schéma Firestore (collection `marketplace`) :
///   sellerId, cropName, quantityKg, pricePerKg, location, createdAt, status
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  Future<void> _openCreateListingSheet() async {
    final cropController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mettre en vente une récolte', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(controller: cropController, decoration: const InputDecoration(labelText: 'Culture (ex. Tomate)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité (kg)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix au kg (FCFA)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null || cropController.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection('marketplace').add({
                  'sellerId': uid,
                  'cropName': cropController.text.trim(),
                  'quantityKg': num.tryParse(qtyController.text) ?? 0,
                  'pricePerKg': num.tryParse(priceController.text) ?? 0,
                  'status': 'disponible',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Publier l\'annonce'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateListingSheet,
        icon: const Icon(Icons.add),
        label: const Text('Vendre'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('marketplace')
            .where('status', isEqualTo: 'disponible')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Erreur : ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Aucune annonce pour le moment.'));

          return ListView.builder(
            padding: const EdgeInsets.all(KSpace.md),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              return KCard(
                child: ListTile(
                  leading: const Icon(Icons.agriculture),
                  title: Text('${d['cropName']} · ${d['quantityKg']} kg'),
                  subtitle: Text('${d['pricePerKg']} FCFA / kg'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
