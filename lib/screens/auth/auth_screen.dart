import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../services/auth/firebase_service.dart';
import '../../core/theme/theme.dart';

/// Écran de connexion / inscription, branché sur Firebase Auth.
/// Nécessite `flutterfire configure` + Firebase.initializeApp() dans
/// main.dart, et les fournisseurs Email/Google/Apple/Téléphone activés
/// dans la console Firebase.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _registerMode = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Erreur d\'authentification (${e.code})');
    } catch (e) {
      _showError('Erreur : ${e.runtimeType}. Vérifiez que Firebase est configuré (flutterfire configure).');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _emailAction() async {
    final fb = context.read<FirebaseService>();
    final email = _emailController.text.trim();
    final pwd = _passwordController.text;
    if (email.isEmpty || pwd.length < 6) {
      _showError('Email valide et mot de passe (6+ caractères) requis.');
      return;
    }
    await _run(() => _registerMode
        ? fb.registerWithEmail(email, pwd).then((_) {})
        : fb.signInWithEmail(email, pwd).then((_) {}));
  }

  Future<void> _phoneFlow() async {
    final fb = context.read<FirebaseService>();
    final phoneController = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Numéro de téléphone'),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '+221 77 123 45 67'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, phoneController.text.trim()), child: const Text('Envoyer le code')),
        ],
      ),
    );
    if (phone == null || phone.isEmpty || !mounted) return;

    setState(() => _loading = true);
    await fb.verifyPhoneNumber(
      phoneNumber: phone,
      onCodeSent: (verificationId) async {
        if (!mounted) return;
        setState(() => _loading = false);
        final code = await _askSmsCode();
        if (code == null || code.isEmpty || !mounted) return;
        await _run(() => fb.confirmPhoneCode(verificationId: verificationId, smsCode: code).then((_) {}));
      },
      onError: (e) {
        if (mounted) setState(() => _loading = false);
        _showError(e.message ?? 'Erreur d\'envoi du SMS');
      },
    );
  }

  Future<String?> _askSmsCode() {
    final codeController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code reçu par SMS'),
        content: TextField(controller: codeController, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, codeController.text.trim()), child: const Text('Valider')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.read<FirebaseService>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.eco, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('KultivIA',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _emailAction,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_registerMode ? "S'inscrire avec email" : 'Continuer avec email'),
              ),
              TextButton(
                onPressed: _loading ? null : () => setState(() => _registerMode = !_registerMode),
                child: Text(_registerMode ? 'Déjà un compte ? Se connecter' : 'Pas de compte ? Créer un compte'),
              ),
              const SizedBox(height: 12),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(padding: EdgeInsets.symmetric(horizontal: KSpace.sm), child: Text('ou')),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _run(() => fb.signInWithGoogle().then((_) {})),
                icon: Image.asset('assets/images/google_logo.png', height: 24),
                label: const Text('Continuer avec Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[800],
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: SignInWithAppleButton(
                  onPressed: _loading ? () {} : () => _run(() => fb.signInWithApple().then((_) {})),
                  text: 'Continuer avec Apple',
                  height: 48,
                  style: SignInWithAppleButtonStyle.black,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _phoneFlow,
                icon: const Icon(Icons.phone_android),
                label: const Text('Continuer avec un numéro de téléphone'),
              ),
              const SizedBox(height: 24),
              Text(
                'Avec un numéro de téléphone, vous recevrez un code de vérification par SMS.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}