// Service d'authentification Firebase. Issue GitHub : #TODO
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'dart:async';

import '../../models/diagnosis.dart';
import '../../models/user_profile.dart';
import '../sync/supabase_mirror.dart';

/// Regroupe l'authentification Firebase et la persistance Firestore.
class FirebaseService {
  FirebaseService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    this.mirror,
  })  : _authOverride = auth,
        _firestoreOverride = firestore;

  /// Réplica Supabase. Null = aucune réplication, comportement historique.
  ///
  /// Injecté plutôt qu'instancié ici pour que le test puisse passer un double
  /// qui échoue, et pour que le dépôt reste testable sans réseau.
  final SupabaseMirror? mirror;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;

  bool get isReady => Firebase.apps.isNotEmpty;
  User? get currentUser => isReady ? _auth.currentUser : null;
  Stream<User?> get authState => isReady ? _auth.authStateChanges() : const Stream.empty();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Connexion Google annulée');
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithApple() async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
  }) async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onError,
      codeSent: (verificationId, forceResendingToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    await _auth.signOut();
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  Reference storageRef() => FirebaseStorage.instance.ref();

  Future<UserProfile?> fetchProfile() async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await _userDoc(uid).get();
    
    // Si le profil n'existe pas encore dans Firestore, le créer avec les infos de Firebase Auth
    if (!doc.exists) {
      final user = currentUser;
      if (user != null) {
        final newProfile = UserProfile(
          displayName: user.displayName ?? 'Utilisateur',
          photoUrl: user.photoURL,
        );
        await saveProfile(newProfile);
        return newProfile;
      }
      return null;
    }
    
    // Mettre à jour photoUrl depuis Firebase Auth si disponible
    final profileData = doc.data()!;
    final authPhotoUrl = currentUser?.photoURL;
    if (authPhotoUrl != null && authPhotoUrl.isNotEmpty) {
      profileData['photoUrl'] = authPhotoUrl;
    }
    
    return UserProfile.fromJson(profileData);
  }

  /// Point de sortie unique des écritures de profil.
  ///
  /// Les huit écrans qui modifient le profil (onboarding, réglages, photo,
  /// langue, thème...) passent tous par ici. C'est ce qui permet de répliquer
  /// vers Supabase en un seul endroit, sans toucher un seul écran.
  ///
  /// Firestore d'abord, réplique ensuite : la réplication est déclenchée après
  /// l'écriture confirmée, et son échec est absorbé par [SupabaseMirror].
  Future<void> saveProfile(UserProfile profile) async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    
    // S'assurer que photoUrl est inclus depuis Firebase Auth si non fourni
    final profileWithPhoto = profile.photoUrl != null
        ? profile
        : profile.copyWith(photoUrl: currentUser?.photoURL);

    // Une seule sérialisation : Firestore et le réplica doivent porter le même
    // `updatedAt`, sinon la règle last-write-wins arbitrerait sur une valeur
    // différente de celle de la source.
    final data = profileWithPhoto.toMap();

    await _userDoc(uid).set(data);

    if (mirror != null) {
      // `unawaited` : l'utilisateur n'a pas à attendre la copie Supabase.
      unawaited(mirror!.mirrorUser(data));
    }
  }

  CollectionReference<Map<String, dynamic>> _diagnosesCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('diagnoses');

  Future<void> saveDiagnosis(Diagnosis d) async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Utilisateur non connecté');
    await _diagnosesCol(uid).doc(d.id).set(d.toJson());
  }

  Stream<List<Diagnosis>> watchDiagnoses() {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _diagnosesCol(uid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Diagnosis.fromJson(doc.data())).toList();
    });
  }

  Future<List<Map<String, dynamic>>> fetchNearbyVendors() async {
    if (!isReady) {
      throw Exception('Firebase non initialisé. Exécutez: flutterfire configure');
    }
    final snapshot = await _firestore.collection('vendors').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
