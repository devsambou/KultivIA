import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'models/diagnosis.dart';
import 'repositories/conversation_repository.dart';
import 'repositories/diagnosis_repository.dart';
import 'repositories/firebase_conversation_repository.dart';
import 'repositories/firebase_diagnosis_repository.dart';
import 'repositories/mirrored_diagnosis_repository.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/health/diagnosis_result_screen.dart';
import 'screens/gate/gate_screen.dart';
import 'screens/health/health_dashboard_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/home_ai/home_ai_screen.dart';
import 'screens/market/marketplace_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/settings/profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/setup/setup_controller.dart';
import 'screens/setup/setup_screen.dart';
import 'screens/market/vendors_map_screen.dart';
import 'screens/weather/weather_alerts_screen.dart';
import 'services/system/app_state.dart';
import 'services/data/conversation_history.dart';
import 'services/data/diagnosis_history.dart';
import 'services/auth/firebase_service.dart';
import 'services/auth/supabase_service.dart';
import 'services/sync/supabase_mirror.dart';
import 'services/system/notification_service.dart';
import 'services/system/connectivity_service.dart';
import 'services/ai/rodium_ai_service.dart';
import 'services/system/user_settings.dart';
import 'core/theme/theme.dart';
import 'widgets/offline_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? 'https://hyvhwsclfjnnbrpdsypt.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'sb_publishable_FrQ414tsGK01Da6to6RVmA_cbKN4goJ',
  );

  try {
    await Firebase.initializeApp();

    // Persistance hors-ligne (issue C6).
    //
    // Doit être posé APRÈS initializeApp() : `FirebaseFirestore.instance`
    // lève tant que l'application n'est pas initialisée. Et avant
    // `runApp`, car tout accès Firestore ultérieur ferait échouer l'assertion.
    //
    // Sans ce réglage le cache reste vide : en mode avion l'historique
    // affiche « aucun diagnostic » et le paysan perd tout son travail.
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
  } catch (e) {
    debugPrint('Firebase non initialisé : $e');
  }

  runApp(const KultivIaApp());
}

class KultivIaApp extends StatelessWidget {
  const KultivIaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserSettings()),

        // État réseau, lu par le bandeau hors-ligne (issue C6).
        ChangeNotifierProvider(create: (_) => ConnectivityService()),

        // Réplication Firestore → Supabase (Postgres).
        //
        // Firestore reste la source de vérité : le miroir ne fait qu'ajouter
        // une copie, en best-effort, après l'écriture Firestore confirmée.
        //
        // `SIMULTANEOUS_WRITES=false` (défaut) désactive tout : l'application
        // se comporte alors exactement comme avant, ce qui rend l'opération
        // réversible en changeant une seule ligne de `.env`.
        //
        // Voir plans/double-ecriture-supabase.md.
        Provider<SupabaseMirror>(
          create: (_) => SupabaseMirror(),
        ),

        Provider<DiagnosisRepository>(
          create: (context) {
            final firebase = FirebaseDiagnosisRepository();

            if (!AppConfig.simultaneousWrites) return firebase;

            return MirroredDiagnosisRepository(
              delegate: firebase,
              mirror: context.read<SupabaseMirror>(),
            );
          },
        ),

        ChangeNotifierProvider(
          create: (context) => DiagnosisHistory(
            context.read<DiagnosisRepository>(),
          ),
        ),

        // Historique des conversations avec l'avatar.
        //
        // Firestore seulement, comme le reste de l'application. La copie
        // Supabase reste limitée à `users` + `diagnoses` (voir
        // plans/double-ecriture-supabase.md) : ajouter ici une troisième
        // collection à répliquer élargirait la surface du miroir sans nécessité.
        Provider<ConversationRepository>(
          create: (_) => FirebaseConversationRepository(),
        ),

        ChangeNotifierProvider(
          create: (context) => ConversationHistory(
            context.read<ConversationRepository>(),
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => AppState(
            settings: context.read<UserSettings>(),
            history: context.read<DiagnosisHistory>(),
          ),
        ),

        Provider<FirebaseService>(
          create: (context) => FirebaseService(
            // `null` = pas de réplication, comportement historique.
            mirror: AppConfig.simultaneousWrites
                ? context.read<SupabaseMirror>()
                : null,
          ),
        ),
        Provider<SupabaseService>(create: (_) => SupabaseService()),
        Provider<NotificationService>(create: (_) => NotificationService()),

        Provider<RodiumAiService>(create: (_) => RodiumAiService()),

        ChangeNotifierProvider(
          create: (context) => SetupController(
            appState: context.read<AppState>(),
            firebaseService: context.read<FirebaseService>(),
            notificationService: context.read<NotificationService>(),
            diagnosisRepository: context.read<DiagnosisRepository>(),
          ),
        ),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'KultivIA',
            debugShowCheckedModeBanner: false,

            theme: KultivTheme.light(),
            darkTheme: KultivTheme.dark(),
            themeMode: appState.themeMode,

            // Flutter's built-in MaterialLocalizations/CupertinoLocalizations only support fr/en.
            // Custom translations for wo/ln are handled by AppLocalizations, but Material/Cupertino
            // only support fr/en. So we restrict supportedLocales to fr/en for the framework,
            // while AppLocalizations still provides custom translations for all 4 languages.
            locale: Locale(appState.languageCode),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('fr'), Locale('en')],

            // Bandeau hors-ligne au-dessus de toutes les routes (issue C6).
            // Posé ici et non dans chaque écran : le `builder` enveloppe le
            // `Navigator`, donc les 13 routes sont couvertes sans qu'un seul
            // écran ait à importer le bandeau.
            builder: (context, child) => OfflineHost(child: child!),

            initialRoute: '/',
            routes: {
              '/': (_) => const GateScreen(),
              '/onboarding': (_) => const OnboardingScreen(),
              '/auth': (_) => const AuthScreen(),
              '/setup': (_) => const SetupScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/home': (_) => const HomeAiScreen(),
              '/history': (_) => const HistoryScreen(),
              '/profile': (_) => const ProfileScreen(),
              '/vendors': (_) => const VendorsMapScreen(),
              '/weather': (_) => const WeatherAlertsScreen(),
              '/community': (_) => const CommunityScreen(),
              '/marketplace': (_) => const MarketplaceScreen(),
              '/health-dashboard': (_) => const HealthDashboardScreen(),
            },

            onGenerateRoute: (settings) {
              if (settings.name == '/result') {
                final diagnosis = settings.arguments as Diagnosis;
                return MaterialPageRoute(
                  builder: (_) => DiagnosisResultScreen(
                    diagnosis: diagnosis,
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}