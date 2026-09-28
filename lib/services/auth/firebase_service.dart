import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/diagnosis.dart';
import '../models/user_profile.dart';
import 'mock_auth_service.dart';

/// Regroupe l'authentification Firebase et la persistance Firestore.
///
/// Prérequis avant utilisation :
///   1. `flutterfire configure` (génère lib/firebase_options.dart)
///   2. Décommenter `Firebase.initializeApp(...)` dans main.dart
///   3. Activer les fournisseurs Email, Google et Apple dans la console
///      Firebase Authentication.
class FirebaseService {
  FirebaseService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _authOverride = auth,
        _firestoreOverride = firestore,
        _mockAuth = MockAuthService();

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final MockAuthService _mockAuth;

  // Accès paresseux : l'app démarre même si Firebase n'est pas (encore)
  // configuré, au lieu de planter à la construction du service.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;

  /// Vrai si `Firebase.initializeApp()` a réussi au démarrage.
  bool get isReady => Firebase.apps.isNotEmpty;

  /// Utilise le mock si Firebase pas prêt, sinon le vrai Firebase
  User? get currentUser => isReady ? _auth.currentUser : _mockAuth.currentUser;
  Stream<User?> get authState => isReady ? _auth.authStateChanges() : _mockAuth.authStateChanges;

  // ---------------------------------------------------------------------
  // Authentification
  // ---------------------------------------------------------------------

  Future<UserCredential> signInWithEmail(String email, String password) {
    if (isReady) {
      return _auth.signInWithEmailAndPassword(email: email, password: password);
    }
    return _mockAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    if (isReady) {
      return _auth.createUserWithEmailAndPassword(email: email, password: password);
    }
    return _mockAuth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(code: 'cancelled', message: 'Connexion Google annulée');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Connexion "iCloud" côté produit = Sign in with Apple côté technique.
  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    return _auth.signInWithCredential(oauthCredential);
  }

  /// Étape 1 du flux téléphone : envoie le code SMS.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: onError,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Étape 2 : valide le code reçu par SMS.
  Future<UserCredential> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (isReady) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      await _auth.signOut();
    } else {
      await _mockAuth.signOut();
    }
  }

  // ---------------------------------------------------------------------
  // Firestore — profil utilisateur (paramétrage de première connexion)
  // ---------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Renvoie null si l'utilisateur n'a pas encore de profil.
  Future<UserProfile?> fetchProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await _userDoc(uid).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return UserProfile.fromMap(data);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final uid = currentUser?.uid;
    if (uid == null) throw StateError('Utilisateur non connecté');
    await _userDoc(uid).set({
      ...profile.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------
  // Firestore — historique des diagnostics
  // ---------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _diagnosesCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('diagnoses');

  Future<void> saveDiagnosis(Diagnosis d) async {
    final uid = currentUser?.uid;
    if (uid == null) return; // pas connecté → on ne persiste pas
    await _diagnosesCol(uid).doc(d.id).set(d.toMap());
  }

  Stream<List<Diagnosis>> watchDiagnoses() {
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _diagnosesCol(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return Diagnosis(
                id: data['id'] as String,
                date: DateTime.parse(data['date'] as String),
                imagePath: data['imagePath'] as String?,
                inputText: data['inputText'] as String? ?? '',
                disease: data['disease'] as String? ?? 'Indéterminé',
                confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
                advice: data['advice'] as String? ?? '',
                rawAiResponse: '',
              );
            }).toList());
  }

  // ---------------------------------------------------------------------
  // Firestore — points de vente d'intrants (géolocalisation)
  // ---------------------------------------------------------------------

  /// Suppose une collection `points_de_vente` avec les champs :
  /// name, address, latitude, longitude, products (List<String>).
  /// À peupler manuellement ou via un script d'import pour la démo.
  Future<List<Map<String, dynamic>>> fetchNearbyVendors() async {
    final snap = await _firestore.collection('points_de_vente').limit(20).get();
    return snap.docs.map((d) => d.data()).toList();
  }
}
