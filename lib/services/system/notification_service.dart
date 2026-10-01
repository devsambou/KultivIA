import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Notifications push (Firebase Cloud Messaging).
///
/// Remplace le mode SMS : l'utilisateur s'abonne au topic `alerts` et reçoit
/// les alertes envoyées par les Cloud Functions (ex. nouveau signalement
/// communautaire) ou depuis la console Firebase (Messaging → nouvelle
/// campagne → topic « alerts »).
class NotificationService {
  static const alertsTopic = 'alerts';

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  String? _uid;

  /// Demande l'autorisation, s'abonne aux alertes et enregistre le jeton
  /// de l'appareil. Renvoie false si l'utilisateur refuse.
  Future<bool> enable(String uid) async {
    _uid = uid;
    final settings = await _fcm.requestPermission();
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) {
      _uid = null;
      return false;
    }

    // Ré-enregistrer le jeton s'il est rafraîchi (ex. réinstallation, expiration).
    _fcm.onTokenRefresh.listen((token) async {
      if (_uid != null) {
        final db =FirebaseFirestore.instance;
        await db
            .collection('users')
            .doc(_uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    });

    try {
      await _fcm.subscribeToTopic(alertsTopic);
      final token = await _fcm.getToken();
      if (token != null) {
        final db =FirebaseFirestore.instance;
        await db
            .collection('users')
            .doc(uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Abonnement notifications impossible : $e');
    }
    return true;
  }

  Future<void> disable() async {
    _uid = null;
    try {
      await _fcm.unsubscribeFromTopic(alertsTopic);
    } catch (e) {
      debugPrint('Désabonnement notifications impossible : $e');
    }
  }

  /// Notifications reçues pendant que l'app est ouverte (Android/iOS
  /// n'affichent rien automatiquement dans ce cas) : « titre — texte ».
  Stream<String> get foregroundTexts => FirebaseMessaging.onMessage
      .map((m) => [m.notification?.title, m.notification?.body].whereType<String>().join(' — '))
      .where((t) => t.isNotEmpty);
}