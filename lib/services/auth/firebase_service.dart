// Service d'authentification Firebase. Issue GitHub : #TODO
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../models/diagnosis.dart';
import '../../models/user_profile.dart';

/// Regroupe l'authentification Firebase et la persistance Firestore.
class FirebaseService {
  FirebaseService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _authOverride = auth,
        _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;

  bool get isReady => Firebase.apps.isNotEmpty;
  User? get currentUser => isReady ? _auth.currentUser : null;
  Stream<User?> get authState => isReady ? _auth.authStateChanges() : const Stream.empty();

  Future<UserCredential> signInWithEmail(String email, String password) {
    throw UnimplementedError();
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    throw UnimplementedError();
  }

  Future<UserCredential> signInWithGoogle() {
    throw UnimplementedError();
  }

  Future<UserCredential> signInWithApple() {
    throw UnimplementedError();
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
  }) {
    throw UnimplementedError();
  }

  Future<UserCredential> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) {
    throw UnimplementedError();
  }

  Future<void> signOut() {
    throw UnimplementedError();
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<UserProfile?> fetchProfile() {
    throw UnimplementedError();
  }

  Future<void> saveProfile(UserProfile profile) {
    throw UnimplementedError();
  }

  CollectionReference<Map<String, dynamic>> _diagnosesCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('diagnoses');

  Future<void> saveDiagnosis(Diagnosis d) {
    throw UnimplementedError();
  }

  Stream<List<Diagnosis>> watchDiagnoses() {
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> fetchNearbyVendors() {
    throw UnimplementedError();
  }
}
