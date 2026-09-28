import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/k_components.dart';
import '../core/theme/theme.dart';

/// Fonctionnalité 5.2 : partage communautaire. Un agriculteur peut voir si
/// d'autres utilisateurs proches ont signalé la même maladie récemment
/// (alerte d'épidémie locale), et publier son propre signalement.
///
/// Schéma Firestore (collection `signalements`) :
///   authorId, disease, description, latitude, longitude, createdAt
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.prefillDisease});
  final String? prefillDisease;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _diseaseController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.prefillDisease != null) _diseaseController.text = widget.prefillDisease!;
  }

  Future<void> _publish() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour publier un signalement.')),
      );
      return;
    }
    if (_diseaseController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('signalements').add({
      'authorId': uid,
      'disease': _diseaseController.text.trim(),
      'description': _descController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      // TODO(équipe) : ajouter latitude/longitude (via geolocator) pour
      // permettre le filtrage "proches de chez moi".
    });

    _diseaseController.clear();
    _descController.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signalements de la communauté')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('signalements')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur : ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Aucun signalement pour le moment.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(KSpace.md),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    return KCard(
                      child: ListTile(
                        leading: const Icon(Icons.report_gmailerrorred_outlined),
                        title: Text(d['disease']?.toString() ?? ''),
                        subtitle: Text(d['description']?.toString() ?? ''),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(KSpace.md),
              child: Column(
                children: [
                  TextField(
                    controller: _diseaseController,
                    decoration: const InputDecoration(labelText: 'Maladie observée', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Détails (optionnel)', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(onPressed: _publish, icon: const Icon(Icons.send), label: const Text('Publier')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
