import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/diagnosis.dart';
import 'repositories/diagnosis_repository.dart';
import 'repositories/firebase_diagnosis_repository.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/health/diagnosis_result_screen.dart';
import 'screens/gate_screen.dart';
import 'screens/health/health_dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_ai_screen.dart';
import 'screens/settings/language_screen.dart';
import 'screens/market/marketplace_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/settings/profile_screen.dart';
import 'screens/setup/setup_controller.dart';
import 'screens/setup_screen.dart';
import 'screens/market/vendors_map_screen.dart';
import 'screens/weather/weather_alerts_screen.dart';
import 'services/system/app_state.dart';
import 'services/data/diagnosis_history.dart';
import 'services/auth/firebase_service.dart';
import 'services/system/notification_service.dart';
import 'services/ai/rodium_ai_service.dart';
import 'services/system/user_settings.dart';
import 'core/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Utilise google-services.json (Android) / GoogleService-Info.plist (iOS),
  // ajoutés par `flutterfire configure` — voir README. Si la config est
  // absente, l'app démarre quand même (onboarding) mais sans connexion.
  try {
    await Firebase.initializeApp();
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
        Provider<DiagnosisRepository>(
          create: (_) => FirebaseDiagnosisRepository(),
        ),
        ChangeNotifierProvider(
          create: (context) => DiagnosisHistory(
            context.read<DiagnosisRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AppState(
            settings: context.read<UserSettings>(),
            history: context.read<DiagnosisHistory>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SetupController(
            appState: context.read<AppState>(),
            firebaseService: context.read<FirebaseService>(),
            notificationService: context.read<NotificationService>(),
            diagnosisRepository: context.read<DiagnosisRepository>(),
          ),
        ),
        Provider<RodiumAiService>(create: (_) => RodiumAiService()),
        Provider<FirebaseService>(create: (_) => FirebaseService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'KultivIA',
        debugShowCheckedModeBanner: false,
        theme: KultivTheme.light(),
        darkTheme: KultivTheme.dark(),
        themeMode: ThemeMode.system,
        initialRoute: '/',
        routes: {
          '/': (_) => const GateScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
          '/auth': (_) => const AuthScreen(),
          '/setup': (_) => const SetupScreen(),
          '/language': (_) => const LanguageScreen(),
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
            return MaterialPageRoute(builder: (_) => DiagnosisResultScreen(diagnosis: diagnosis));
          }
          return null;
        },
      ),
    );
  }
}
