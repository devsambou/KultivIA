// Écran carte des vendeurs d'intrants. Issue GitHub : #TODO
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/vendors_seed.dart';
import '../../services/auth/firebase_service.dart';
import '../../services/external/vendor_links.dart';

class VendorsMapScreen extends StatefulWidget {
  const VendorsMapScreen({super.key});

  @override
  State<VendorsMapScreen> createState() => _VendorsMapScreenState();
}

class _VendorsMapScreenState extends State<VendorsMapScreen> {
  static const _whatsappMessage =
      'Bonjour, je vous contacte depuis KultivIA. '
      'Avez-vous des produits pour soigner mes cultures ?';

  final FirebaseService _firebaseService = FirebaseService();

  List<Map<String, dynamic>> _vendors = [];
  Position? _position;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _position = null;
      _vendors = [];
    });

    final position = await _tryGetPosition();

    final merged = <String, Map<String, dynamic>>{};

    // Vendeurs intégrés à l'application.
    for (final vendor in vendorsSeed) {
      final name = _vendorName(vendor);

      if (name.isNotEmpty) {
        merged[name.toLowerCase()] = Map<String, dynamic>.from(vendor);
      }
    }

    // Vendeurs ajoutés dynamiquement dans Firestore.
    // Une erreur réseau ne doit pas empêcher l'affichage
    // des vendeurs locaux.
    try {
      final remoteVendors = await _firebaseService.fetchNearbyVendors();

      for (final vendor in remoteVendors) {
        final name = _vendorName(vendor);

        if (name.isNotEmpty) {
          merged[name.toLowerCase()] = Map<String, dynamic>.from(vendor);
        }
      }
    } catch (_) {
      // Erreur Firebase ignorée volontairement.
    }

    final vendors = merged.values.toList();

    // Si la position est disponible, calculer les distances.
    if (position != null) {
      for (final vendor in vendors) {
        final latitude = _doubleValue(vendor['latitude']);
        final longitude = _doubleValue(vendor['longitude']);

        if (latitude == null || longitude == null) {
          vendor['distanceKm'] = null;
          continue;
        }

        vendor['distanceKm'] =
            Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              latitude,
              longitude,
            ) /
                1000;
      }

      // Trier du plus proche au plus éloigné.
      vendors.sort((a, b) {
        final distanceA = _doubleValue(a['distanceKm']);
        final distanceB = _doubleValue(b['distanceKm']);

        if (distanceA == null && distanceB == null) {
          return 0;
        }

        if (distanceA == null) {
          return 1;
        }

        if (distanceB == null) {
          return -1;
        }

        return distanceA.compareTo(distanceB);
      });
    }

    if (!mounted) return;

    setState(() {
      _position = position;
      _vendors = vendors;
      _loading = false;
    });
  }

  Future<Position?> _tryGetPosition() async {
    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (_) {
      // La localisation est optionnelle pour E4.
      // La liste des vendeurs doit quand même être affichée.
      return null;
    }
  }

  String _vendorName(Map<String, dynamic> vendor) {
    return (vendor['name'] ?? '').toString().trim();
  }

  String? _vendorPhone(Map<String, dynamic> vendor) {
    final phone = vendor['phone']?.toString().trim();

    if (phone == null || phone.isEmpty) {
      return null;
    }

    return phone;
  }

  double? _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  Future<void> _openUri(Uri? uri) async {
    if (uri == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lien indisponible pour ce point de vente.'),
        ),
      );

      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d’ouvrir cette application.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir cette application.'),
        ),
      );
    }
  }

  Future<void> _callVendor(Map<String, dynamic> vendor) async {
    await _openUri(
      vendorTelUri(_vendorPhone(vendor)),
    );
  }

  Future<void> _openWhatsApp(Map<String, dynamic> vendor) async {
    await _openUri(
      vendorWhatsAppUri(
        _vendorPhone(vendor),
        message: _whatsappMessage,
      ),
    );
  }

  Future<void> _openDirections(Map<String, dynamic> vendor) async {
    await _openUri(
      vendorDirectionsUri(
        _doubleValue(vendor['latitude']),
        _doubleValue(vendor['longitude']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Points de vente d\'intrants'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _loadVendors,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_vendors.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadVendors,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(
              Icons.store_mall_directory_outlined,
              size: 56,
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Aucun point de vente disponible.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVendors,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _vendors.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          return _VendorCard(
            vendor: _vendors[index],
            hasPosition: _position != null,
            onCall: () => _callVendor(_vendors[index]),
            onWhatsApp: () => _openWhatsApp(_vendors[index]),
            onDirections: () => _openDirections(_vendors[index]),
          );
        },
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.hasPosition,
    required this.onCall,
    required this.onWhatsApp,
    required this.onDirections,
  });

  final Map<String, dynamic> vendor;
  final bool hasPosition;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onDirections;

  String get name {
    return (vendor['name'] ?? '').toString().trim();
  }

  String get address {
    return (vendor['address'] ?? '').toString().trim();
  }

  List<String> get products {
    final value = vendor['products'];

    if (value is Iterable) {
      return value
          .map((product) => product.toString().trim())
          .where((product) => product.isNotEmpty)
          .toList();
    }

    return [];
  }

  double? get distanceKm {
    final value = vendor['distanceKm'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = distanceKm;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (hasPosition && distance != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${distance.toStringAsFixed(1)} km',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),

            if (address.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(address),
                  ),
                ],
              ),
            ],

            if (products.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      products.join(' · '),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.phone_outlined),
                  label: const Text('Appeler'),
                ),
                OutlinedButton.icon(
                  onPressed: onWhatsApp,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
                OutlinedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Itinéraire'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}