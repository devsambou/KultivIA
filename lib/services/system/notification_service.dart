// Service de notifications push. Issue GitHub : #TODO
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Notifications push (Firebase Cloud Messaging).
class NotificationService {
  static const alertsTopic = 'alerts';

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  Future<bool> enable(String uid) {
    throw UnimplementedError();
  }

  Future<void> disable() {
    throw UnimplementedError();
  }

  Stream<String> get foregroundTexts {
    throw UnimplementedError();
  }
}
