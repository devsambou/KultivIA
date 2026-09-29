// Écran marketplace (vente/achat récoltes). Issue GitHub : #25

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/external/vendor_links.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _marketplaceStream {
    return _firestore
        .collection('marketplace')
        .where('status', isEqualTo: 'disponible')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _callSeller(String? phone) async {
    final uri = vendorTelUri(phone);

    if (uri == null) {
      _showMessage('Numéro de téléphone invalide.');
      return;
    }

    try {
      final launched = await launchUrl(uri);

      if (!launched && mounted) {
        _showMessage('Impossible d’ouvrir l’application téléphone.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Impossible d’ouvrir l’application téléphone.');
      }
    }
  }

  Future<void> _whatsappSeller({
    required String? phone,
    required String cropName,
  }) async {
    final uri = vendorWhatsAppUri(
      phone,
      message:
          'Bonjour, je suis intéressé(e) par votre annonce de $cropName sur KultivIA.',
    );

    if (uri == null) {
      _showMessage('Numéro WhatsApp invalide.');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage('Impossible d’ouvrir WhatsApp.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Impossible d’ouvrir WhatsApp.');
      }
    }
  }

  Future<void> _markAsSold(
    String documentId,
  ) async {
    try {
      await _firestore.collection('marketplace').doc(documentId).update({
        'status': 'vendue',
      });

      _showMessage('Annonce marquée comme vendue.');
    } catch (_) {
      _showMessage('Impossible de modifier l’annonce.');
    }
  }

  Future<void> _showSellSheet() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Vous devez être connecté pour publier une annonce.');
      return;
    }

    final cropController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final phoneController = TextEditingController(
      text: user.phoneNumber ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        bool isPublishing = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vendre une récolte',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: cropController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Culture',
                        hintText: 'Ex. Maïs',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Quantité (kg)',
                        hintText: 'Ex. 100',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Prix au kg (FCFA)',
                        hintText: 'Ex. 500',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        hintText: 'Ex. +242 06 123 45 67',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isPublishing
                            ? null
                            : () async {
// On récupère le Navigator avant le await
// pour ne plus utiliser sheetContext après
// une opération asynchrone.
                                final navigator = Navigator.of(sheetContext);

                                final crop = cropController.text.trim();
                                final quantityText =
                                    quantityController.text.trim();
                                final priceText = priceController.text.trim();
                                final phone = phoneController.text.trim();

                                final quantity = double.tryParse(quantityText);
                                final price = double.tryParse(priceText);

                                if (crop.isEmpty) {
                                  setSheetState(
                                    () => errorMessage =
                                        'Veuillez renseigner la culture.',
                                  );
                                  return;
                                }

                                if (quantity == null || quantity <= 0) {
                                  setSheetState(
                                    () => errorMessage =
                                        'La quantité doit être supérieure à 0.',
                                  );
                                  return;
                                }

                                if (price == null || price <= 0) {
                                  setSheetState(
                                    () => errorMessage =
                                        'Le prix doit être supérieur à 0.',
                                  );
                                  return;
                                }

                                if (vendorPhoneDigits(phone) == null) {
                                  setSheetState(
                                    () => errorMessage =
                                        'Veuillez renseigner un numéro valide.',
                                  );
                                  return;
                                }

                                setSheetState(() {
                                  isPublishing = true;
                                  errorMessage = null;
                                });

                                try {
                                  await _firestore
                                      .collection('marketplace')
                                      .add({
                                    'sellerId': user.uid,
                                    'cropName': crop,
                                    'quantityKg': quantity,
                                    'pricePerKg': price,
                                    'location': 'Non renseignée',
                                    'sellerPhone': phone,
                                    'status': 'disponible',
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                                  if (!mounted) return;

                                  navigator.pop();
                                  _showMessage(
                                    'Annonce publiée avec succès.',
                                  );
                                } catch (_) {
                                  if (!mounted) return;

                                  setSheetState(() {
                                    isPublishing = false;
                                    errorMessage =
                                        'Impossible de publier l’annonce.';
                                  });
                                }
                              },
                        child: isPublishing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Publier l’annonce'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    cropController.dispose();
    quantityController.dispose();
    priceController.dispose();
    phoneController.dispose();
  }

  Widget _buildMarketplaceCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final cropName = data['cropName']?.toString() ?? 'Culture inconnue';
    final quantity = data['quantityKg'];
    final price = data['pricePerKg'];
    final location = data['location']?.toString() ?? 'Localisation inconnue';
    final sellerPhone = data['sellerPhone']?.toString();
    final sellerId = data['sellerId']?.toString();

    final isOwner = sellerId == _auth.currentUser?.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$cropName · ${_formatNumber(quantity)} kg',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatNumber(price)} FCFA / kg',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(location),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _callSeller(sellerPhone),
                  icon: const Icon(Icons.phone),
                  label: const Text('Appeler'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _whatsappSeller(
                    phone: sellerPhone,
                    cropName: cropName,
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'sold') {
                        _markAsSold(document.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'sold',
                        child: Text('Marquer comme vendue'),
                      ),
                    ],
                    child: const Icon(Icons.more_vert),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';

    if (value is num) {
      if (value % 1 == 0) {
        return value.toInt().toString();
      }

      return value.toString();
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _marketplaceStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Impossible de charger les annonces.',
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return const Center(
              child: Text(
                'Aucune annonce disponible pour le moment.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              return _buildMarketplaceCard(documents[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSellSheet,
        icon: const Icon(Icons.add),
        label: const Text('Vendre'),
      ),
    );
  }
}
