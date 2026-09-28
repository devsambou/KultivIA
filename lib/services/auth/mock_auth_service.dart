import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Service d'authentification mock qui simule Firebase Auth en local (en mémoire).
/// Utilisé quand Firebase n'est pas configuré (pas de google-services.json).
/// N'implémente que l'API minimale nécessaire à l'app.
class MockAuthService {
  static final MockAuthService _instance = MockAuthService._internal();
  factory MockAuthService() => _instance;
  MockAuthService._internal();

  final Map<String, _MockUser> _users = {}; // email -> user
  _MockUser? _currentUser;

  /// Simule `FirebaseAuth.instance.currentUser`
  fb_auth.User? get currentUser => _currentUser;

  /// Simule `FirebaseAuth.instance.authStateChanges()`
  Stream<fb_auth.User?> get authStateChanges => Stream.value(_currentUser);

  /// Inscription email/password
  Future<fb_auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_users.containsKey(email)) {
      throw fb_auth.FirebaseAuthException(code: 'email-already-in-use', message: 'Email déjà utilisé');
    }
    if (password.length < 6) {
      throw fb_auth.FirebaseAuthException(code: 'weak-password', message: 'Mot de passe trop court (min 6 caractères)');
    }
    final user = _MockUser(uid: 'mock_${DateTime.now().millisecondsSinceEpoch}', email: email);
    _users[email] = user;
    _currentUser = user;
    return _MockUserCredential(user: user);
  }

  /// Connexion email/password
  Future<fb_auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = _users[email];
    if (user == null) {
      throw fb_auth.FirebaseAuthException(code: 'user-not-found', message: 'Utilisateur non trouvé');
    }
    // En mock, on ne vérifie pas le password (simplification)
    _currentUser = user;
    return _MockUserCredential(user: user);
  }

  /// Déconnexion
  Future<void> signOut() async {
    _currentUser = null;
  }

  /// Vérifie si un utilisateur est connecté
  bool get isSignedIn => _currentUser != null;

  /// Récupère l'UID de l'utilisateur courant
  String? get currentUid => _currentUser?.uid;

  /// Réinitialise le mock (pour tests)
  void reset() {
    _users.clear();
    _currentUser = null;
  }
}

/// Mock UserCredential minimal
class _MockUserCredential implements fb_auth.UserCredential {
  _MockUserCredential({required this.user});

  @override
  final fb_auth.User user;

  @override
  fb_auth.AdditionalUserInfo? get additionalUserInfo => null;

  @override
  fb_auth.AuthCredential? get credential => null;
}

/// Mock User minimal - implémente seulement ce dont l'app a besoin
class _MockUser implements fb_auth.User {
  _MockUser({required this.uid, required this.email});

  @override
  final String uid;

  @override
  final String? email;

  @override
  String? get displayName => email?.split('@').first;

  @override
  String? get photoURL => null;

  @override
  String? get phoneNumber => null;

  @override
  bool get isAnonymous => false;

  @override
  bool get emailVerified => true;

  @override
  fb_auth.UserMetadata get metadata => _MockUserMetadata();

  @override
  List<fb_auth.UserInfo> get providerData => [];

  @override
  fb_auth.MultiFactor get multiFactor => throw UnimplementedError();

  @override
  String get refreshToken => 'mock_refresh_token_$uid';

  // Méthodes non utilisées par l'app - implémentations minimales
  @override
  Future<void> delete() async {}

  @override
  Future<fb_auth.UserCredential> reauthenticateWithCredential(fb_auth.AuthCredential credential) async => throw UnimplementedError();

  @override
  Future<void> reload() async {}

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'mock_token_$uid';

  @override
  Future<fb_auth.IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async => _MockIdTokenResult(token: 'mock_token_$uid');

  @override
  Future<void> sendEmailVerification([fb_auth.ActionCodeSettings? actionCodeSettings]) async {}

  @override
  Future<fb_auth.User> unlink(String providerId) async => throw UnimplementedError();

  @override
  Future<fb_auth.UserCredential> updateEmail(String newEmail) async => throw UnimplementedError();

  @override
  Future<fb_auth.UserCredential> updatePassword(String newPassword) async => throw UnimplementedError();

  @override
  Future<fb_auth.UserCredential> updatePhoneNumber(fb_auth.PhoneAuthCredential credential) async => throw UnimplementedError();

  @override
  Future<fb_auth.UserCredential> updateProfile({String? displayName, String? photoURL}) async => throw UnimplementedError();

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail, [fb_auth.ActionCodeSettings? actionCodeSettings]) async => throw UnimplementedError();

  @override
  String get tenantId => '';

  @override
  Future<fb_auth.UserCredential> linkWithCredential(fb_auth.AuthCredential credential) async => throw UnimplementedError();

  @override
  Future<fb_auth.UserCredential> linkWithProvider(fb_auth.AuthProvider provider) async => throw UnimplementedError();

  @override
  Future<fb_auth.UserCredential> linkWithPopup(fb_auth.AuthProvider provider) async => throw UnimplementedError();

  @override
  Future<fb_auth.UserCredential> reauthenticateWithProvider(fb_auth.AuthProvider provider) async => throw UnimplementedError();

  @override
  Future<fb_auth.UserCredential> reauthenticateWithPopup(fb_auth.AuthProvider provider) async => throw UnimplementedError();

  // unlinkProvider and updatePhoneNumberCredential don't exist in fb_auth.User interface
  Future<void> unlinkProvider(String providerId) async => throw UnimplementedError();

  Future<fb_auth.UserCredential> updatePhoneNumberCredential(fb_auth.PhoneAuthCredential credential) async => throw UnimplementedError();

  // Nouveaux membres requis par firebase_auth 5.x
  @override
  Future<fb_auth.ConfirmationResult> linkWithPhoneNumber(String phoneNumber, [fb_auth.RecaptchaVerifier? recaptchaVerifier]) async => throw UnimplementedError();

  @override
  Future<void> linkWithRedirect(fb_auth.AuthProvider provider) async => throw UnimplementedError();

  @override
  Future<void> reauthenticateWithRedirect(fb_auth.AuthProvider provider) async => throw UnimplementedError();

  @override
  Future<void> updateDisplayName(String? displayName) async => throw UnimplementedError();

  @override
  Future<void> updatePhotoURL(String? photoURL) async => throw UnimplementedError();
}

class _MockUserMetadata implements fb_auth.UserMetadata {
  @override
  DateTime? get creationTime => DateTime.now();

  @override
  DateTime? get lastSignInTime => DateTime.now();
}

class _MockIdTokenResult implements fb_auth.IdTokenResult {
  _MockIdTokenResult({required this.token});

  @override
  final String token;

  @override
  DateTime get expirationTime => DateTime.now().add(const Duration(hours: 1));

  @override
  DateTime get issuedAtTime => DateTime.now();

  @override
  Map<String, Object?> get claims => {};

  @override
  String? get signInProvider => 'password';

  // signInSecondFactor and isMultiFactor don't exist in fb_auth.IdTokenResult interface
  String? get signInSecondFactor => null;

  bool get isMultiFactor => false;

  @override
  DateTime? get authTime => DateTime.now();
}