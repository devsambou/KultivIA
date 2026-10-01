import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../widgets/k_components.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    this.prefillDisease,
  });

  final String? prefillDisease;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _diseaseController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _nearbyOnly = false;
  bool _isPublishing = false;
  Position? _userPosition;

  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      FirebaseFirestore.instance.collection('signalements');

  @override
  void initState() {
    super.initState();
    _diseaseController.text = widget.prefillDisease ?? '';
  }

  @override
  void dispose() {
    _diseaseController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<Position?> _requestUserPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userPosition = position;
        });
      }
      return position;
    } catch (_) {
      return null;
    }
  }

  Future<String> _getUserLocality(String uid) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final data = snapshot.data();
      final locality = (data?['locality'] as String?)?.trim();

      if (locality != null && locality.isNotEmpty) {
        return locality;
      }
    } catch (_) {
      // On garde une valeur de secours si le profil n'est pas disponible.
    }

    return 'votre zone';
  }

  Future<void> _toggleNearby(bool value) async {
    if (!value) {
      setState(() {
        _nearbyOnly = false;
      });
      return;
    }

    final position = _userPosition ?? await _requestUserPosition();

    if (position == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Votre position est nécessaire pour afficher les signalements proches.',
          ),
        ),
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      _nearbyOnly = true;
    });
  }

  Future<void> _publishReport() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Vous devez être connecté pour publier un signalement.'),
        ),
      );
      return;
    }

    final disease = _diseaseController.text.trim();
    final description = _descriptionController.text.trim();

    if (disease.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner la maladie observée.'),
        ),
      );
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final position = await _requestUserPosition();
      final locality = await _getUserLocality(user.uid);

      final data = <String, dynamic>{
        'authorId': user.uid,
        'disease': disease,
        'description': description,
        'locality': locality,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (position != null) {
        data['latitude'] = position.latitude;
        data['longitude'] = position.longitude;
      }

      await _reportsCollection.add(data);

      _diseaseController.clear();
      _descriptionController.clear();

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signalement publié avec succès.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de publier le signalement : $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  void _openPublishForm() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Publier un signalement',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _diseaseController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Maladie observée',
                      hintText: 'Ex. Mildiou',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Détails (optionnel)',
                      hintText:
                          'Décrivez brièvement ce que vous avez observé...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isPublishing
                        ? null
                        : () async {
                            setModalState(() {});
                            await _publishReport();
                            if (context.mounted) {
                              setModalState(() {});
                            }
                          },
                    icon: _isPublishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isPublishing ? 'Publication...' : 'Publier',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double? _distanceInKm(Map<String, dynamic> data) {
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();

    if (_userPosition == null || latitude == null || longitude == null) {
      return null;
    }

    final distance = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      latitude,
      longitude,
    );

    return distance / 1000;
  }

  bool _isWithinRadius(Map<String, dynamic> data) {
    final distance = _distanceInKm(data);

    // Sans coordonnées, on ne peut pas confirmer la proximité.
    if (distance == null) {
      return false;
    }

    return distance <= 50;
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) {
      return 'À l’instant';
    }

    final date = value.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _buildReportCard(
    Map<String, dynamic> data,
  ) {
    final disease = (data['disease'] as String?)?.trim() ?? 'Maladie inconnue';
    final description = (data['description'] as String?)?.trim() ?? '';
    final locality = (data['locality'] as String?)?.trim() ?? '';
    final distance = _distanceInKm(data);

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    disease,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(description),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (locality.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text(locality),
                    ],
                  ),
                if (distance != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text('${distance.toStringAsFixed(1)} km'),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 15),
                    const SizedBox(width: 4),
                    Text(_formatDate(data['createdAt'])),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signalements de la communauté'),
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Proches de chez moi'),
            subtitle: const Text(
                'Afficher uniquement les signalements dans un rayon de 50 km'),
            value: _nearbyOnly,
            onChanged: _toggleNearby,
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _reportsCollection
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Impossible de charger les signalements.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final reports = snapshot.data?.docs ?? [];

                final filteredReports = reports.where((doc) {
                  if (!_nearbyOnly) {
                    return true;
                  }

                  return _isWithinRadius(doc.data());
                }).toList();

                if (filteredReports.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _nearbyOnly
                            ? 'Aucun signalement trouvé dans un rayon de 50 km.'
                            : 'Aucun signalement pour le moment.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredReports.length,
                  itemBuilder: (context, index) {
                    return _buildReportCard(
                      filteredReports[index].data(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPublishForm,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Publier'),
      ),
    );
  }
}
