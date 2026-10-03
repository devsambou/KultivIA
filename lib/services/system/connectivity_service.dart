// Détection du réseau pour le mode hors-ligne. Issue GitHub : #C6
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Source du signal réseau, injectable pour les tests.
abstract class ConnectivityProbe {
  /// Lecture ponctuelle de l'état au démarrage.
  Future<List<ConnectivityResult>> check();

  /// Émissions suivantes. Une liste vide = plus aucun transport disponible.
  Stream<List<ConnectivityResult>> get changes;
}

/// Adaptateur sur le plugin `connectivity_plus`.
class PluginConnectivityProbe implements ConnectivityProbe {
  PluginConnectivityProbe([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> check() => _connectivity.checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get changes => _connectivity.onConnectivityChanged;
}

/// État du réseau partagé par toute l'application.
///
/// L'issue C6 prévoyait un `Stream<bool> onlineChanges`. On expose plutôt un
/// [ChangeNotifier] : le bandeau n'a ainsi qu'un `context.select` à écrire au
/// lieu d'un `StreamBuilder` qui imbriquerait un second widget. Le contrat
/// observable (`isOnline`) est identique.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({ConnectivityProbe? probe})
      : _probe = probe ?? PluginConnectivityProbe() {
    initialised = _firstRead();
    _listen();
  }

  final ConnectivityProbe _probe;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _disposed = false;

  bool _isOnline = true;
  bool _isKnown = false;

  /// Complète une fois la lecture initiale terminée — réussie **ou** ratée.
  /// Prévu pour les tests : on peut attendre un état stable sans `Timer`.
  late final Future<void> initialised;

  /// `false` tant que la toute première lecture n'a pas abouti.
  ///
  /// Tant que c'est le cas, le bandeau reste caché : afficher « hors
  /// connexion » pendant la première frame ferait clignoter une application
  /// qui, elle, fonctionne.
  bool get isKnown => _isKnown;

  /// `true` si au moins un transport (WiFi, mobile, Ethernet) est présent.
  bool get isOnline => _isOnline;

  Future<void> _firstRead() async {
    try {
      _apply(await _probe.check());
    } catch (e) {
      // Un échec de lecture ne prouve pas une panne réseau : on garde
      // l'état par défaut et on attend la prochaine émission.
      debugPrint('ConnectivityService : lecture initiale impossible ($e)');
    }
  }

  void _listen() {
    // Depuis `connectivity_plus` v6 le flux émet `List<ConnectivityResult>`
    // et non plus `bool` : un téléphone peut être en WiFi et en 4G en même
    // temps. La liste n'est vide que lorsqu'aucun transport ne reste.
    _sub = _probe.changes.listen(
      _apply,
      onError: (Object e) => debugPrint('ConnectivityService : flux interrompu ($e)'),
    );
  }

  void _apply(List<ConnectivityResult> results) {
    if (_disposed) return;

    final online = results.any((r) => r != ConnectivityResult.none);
    if (_isKnown && online == _isOnline) return;

    _isOnline = online;
    _isKnown = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}