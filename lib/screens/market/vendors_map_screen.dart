import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/vendors_seed.dart';
import '../services/auth/firebase_service.dart';
import '../services/external/vendor_links.dart';
import '../core/theme/theme.dart';
import '../widgets/k_components.dart';

/// Fonctionnalité 5.2 : points de vente d'intrants agricoles proches, avec
/// contact direct (appel, WhatsApp) et itinéraire.
///
/// La liste vient de `vendors_seed.dart` (fonctionne sans réseau), complétée
/// par la collection Firestore `points_de_vente` si elle existe. Triée par
/// distance quand la position est disponible ; sinon la liste s'affiche
/// quand même, sans distances.
class VendorsMapScreen extends StatefulWidget {
  const VendorsMapScreen({super.key});

  @override
  State<VendorsMapScreen> createState() => _VendorsMapScreenState();
}

class _VendorsMapScreenState extends State<VendorsMapScreen> {
  static const _whatsappMessage =
      'Bonjour, je vous contacte depuis KultivIA. Avez-vous des produits pour soigner mes cultures ?';

  List<Map<String, dynamic>> _vendors = [];
  bool _loading = true;
  bool _hasPosition = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Position?> _locate() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fb = context.read<FirebaseService>();

    final position = await _locate();
    List<Map<String, dynamic>> remote = [];
    try {
      remote = await fb.fetchNearbyVendors();
    } catch (_) {
      // Pas de réseau ou Firebase non configuré : la liste intégrée suffit.
    }

    String key(Map<String, dynamic> v) => (v['name'] ?? '').toString().toLowerCase().trim();
    final merged = <String, Map<String, dynamic>>{
      for (final v in vendorsSeed) key(v): Map<String, dynamic>.from(v),
    };
    for (final v in remote) {
      merged.putIfAbsent(key(v), () => Map<String, dynamic>.from(v));
    }
    final vendors = merged.values.toList();

    if (position != null) {
      for (final v in vendors) {
        final lat = (v['latitude'] as num?)?.toDouble();
        final lng = (v['longitude'] as num?)?.toDouble();
        v['distanceKm'] = (lat != null && lng != null)
            ? Geolocator.distanceBetween(position.latitude, position.longitude, lat, lng) / 1000
            : null;
      }
      vendors.sort((a, b) {
        final da = a['distanceKm'] as double? ?? double.infinity;
        final db = b['distanceKm'] as double? ?? double.infinity;
        return da.compareTo(db);
      });
    }

    if (!mounted) return;
    setState(() {
      _vendors = vendors;
      _hasPosition = position != null;
      _loading = false;
    });
  }

  Future<void> _open(Uri? uri) async {
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir l'application.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Points de vente d'intrants"),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(KSpace.lg),
              children: [
                StatusBanner(
                  tone: KultivTheme.status(context).info,
                  icon: Icons.phone_in_talk_outlined,
                  title: 'Appelez avant de vous déplacer',
                  subtitle: _hasPosition
                      ? 'Confirmez que le produit est disponible.'
                      : "Confirmez que le produit est disponible. Activez la localisation pour voir les plus proches en premier.",
                ),
                const SizedBox(height: KSpace.md),
                for (final v in _vendors)
                  _VendorCard(
                    vendor: v,
                    onCall: () => _open(vendorTelUri(v['phone']?.toString())),
                    onWhatsApp: vendorWhatsAppUri(v['phone']?.toString(), message: _whatsappMessage) == null
                        ? null
                        : () => _open(vendorWhatsAppUri(v['phone']?.toString(), message: _whatsappMessage)),
                    onDirections: () => _open(
                      vendorDirectionsUri(v['latitude'] as num?, v['longitude'] as num?),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.onCall,
    required this.onWhatsApp,
    required this.onDirections,
  });

  final Map<String, dynamic> vendor;
  final VoidCallback onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final dist = vendor['distanceKm'] as double?;
    final products = List<String>.from((vendor['products'] as List?) ?? const []);
    final hasPhone = vendorTelUri(vendor['phone']?.toString()) != null;

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.storefront, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: KSpace.md),
                Expanded(
                  child: Text(vendor['name']?.toString() ?? 'Point de vente',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                if (dist != null) Text('${dist.toStringAsFixed(1)} km', style: TextStyle(color: KultivTheme.muted(context))),
              ],
            ),
            if ((vendor['address']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: KSpace.xs, left: 36),
                child: Text(vendor['address'].toString(), style: TextStyle(color: KultivTheme.muted(context))),
              ),
            if (products.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: KSpace.sm, left: 36),
                child: Text(products.join(' · ')),
              ),
            const SizedBox(height: KSpace.md),
            Wrap(
              spacing: KSpace.sm,
              runSpacing: KSpace.sm,
              children: [
                if (hasPhone)
                  FilledButton.icon(onPressed: onCall, icon: const Icon(Icons.call), label: const Text('Appeler')),
                if (onWhatsApp != null)
                  OutlinedButton.icon(onPressed: onWhatsApp, icon: const Icon(Icons.chat), label: const Text('WhatsApp')),
                OutlinedButton.icon(onPressed: onDirections, icon: const Icon(Icons.directions), label: const Text('Itinéraire')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
