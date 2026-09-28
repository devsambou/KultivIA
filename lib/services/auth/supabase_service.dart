// Service d'authentification Supabase
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/diagnosis.dart';
import '../../models/user_profile.dart';

/// Regroupe l'authentification Supabase et la persistance.
class SupabaseService {
  SupabaseService({GoTrueClient? auth, SupabaseClient? client})
      : _authOverride = auth,
        _clientOverride = client;

  final GoTrueClient? _authOverride;
  final SupabaseClient? _clientOverride;

  GoTrueClient get _auth => _authOverride ?? Supabase.instance.client.auth;
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  bool get isReady => true;
  User? get currentUser => isReady ? _auth.currentUser : null;
  Stream<AuthState> get authState => isReady ? _auth.onAuthStateChange : const Stream.empty();

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> registerWithEmail(String email, String password) async {
    return await _auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signInWithGoogle() async {
    final googleClientId = dotenv.env['GOOGLE_CLIENT_ID'];
    if (googleClientId == null || googleClientId.isEmpty) {
      throw Exception('GOOGLE_CLIENT_ID not found in .env');
    }

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: googleClientId,
    );
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign in cancelled');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) {
      throw Exception('No access token from Google');
    }

    return await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken!,
      accessToken: accessToken,
    );
  }

  Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    return await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken ?? '',
      accessToken: credential.authorizationCode,
    );
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(dynamic e) onError,
  }) async {
    try {
      await _auth.signInWithOtp(
        phone: phoneNumber,
      );
      onCodeSent(phoneNumber);
    } catch (e) {
      onError(e);
    }
  }

  Future<AuthResponse> confirmPhoneCode({
    required String phoneNumber,
    required String smsCode,
  }) async {
    return await _auth.verifyOTP(
      phone: phoneNumber,
      token: smsCode,
      type: OtpType.sms,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<UserProfile?> fetchProfile() async {
    if (currentUser == null) return null;
    final response = await _client
        .from('users')
        .select()
        .eq('id', currentUser!.id)
        .single();
    return UserProfile.fromJson(response);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _client.from('users').upsert(profile.toJson());
  }

  Future<void> saveDiagnosis(Diagnosis d) async {
    if (currentUser == null) return;
    await _client.from('diagnoses').insert(d.toJson());
  }

  Stream<List<Diagnosis>> watchDiagnoses() {
    if (currentUser == null) return const Stream.empty();
    return _client
        .from('diagnoses')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser!.id)
        .map((data) => data.map((json) => Diagnosis.fromJson(json)).toList());
  }

  Future<List<Map<String, dynamic>>> fetchNearbyVendors() {
    throw UnimplementedError('Vendors query not implemented for Supabase yet');
  }
}
