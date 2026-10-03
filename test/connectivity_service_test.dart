import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kultivia/core/theme/theme.dart';
import 'package:kultivia/services/system/connectivity_service.dart';
import 'package:kultivia/widgets/offline_banner.dart';
import 'package:provider/provider.dart';

/// Sonde contrôlable : le plugin `connectivity_plus` n'existe pas en test.
class FakeProbe implements ConnectivityProbe {
  FakeProbe({required this.initial, this.failFirstCheck = false, this.gate});

  /// État renvoyé par [check].
  final List<ConnectivityResult> initial;

  /// Fait échouer [check], pour prouver qu'un échec ne déclare pas de panne.
  final bool failFirstCheck;

  /// Maintient [check] en attente, pour observer l'état « pas encore connu ».
  final Completer<void>? gate;

  final StreamController<List<ConnectivityResult>> _changes =
      StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> check() async {
    if (gate != null) await gate!.future;
    if (failFirstCheck) throw StateError('plugin indisponible');
    return initial;
  }

  @override
  Stream<List<ConnectivityResult>> get changes => _changes.stream;

  void emit(List<ConnectivityResult> results) => _changes.add(results);

  Future<void> close() => _changes.close();
}

/// Laisse au flux le temps d'atteindre l'abonné.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('ConnectivityService', () {
    test('avant la première lecture, rien n\'est encore connu', () {
      final s = ConnectivityService(
        probe: FakeProbe(initial: const [ConnectivityResult.wifi]),
      );

      expect(s.isKnown, isFalse);
      expect(s.isOnline, isTrue, reason: 'optimiste tant que rien n\'est connu');

      s.dispose();
    });

    test('une liste vide signifie hors connexion', () async {
      final s = ConnectivityService(probe: FakeProbe(initial: const []));
      await s.initialised;

      expect(s.isKnown, isTrue);
      expect(s.isOnline, isFalse);

      s.dispose();
    });

    test('ConnectivityResult.none seul signifie hors connexion', () async {
      final s = ConnectivityService(
        probe: FakeProbe(initial: const [ConnectivityResult.none]),
      );
      await s.initialised;

      expect(s.isOnline, isFalse);

      s.dispose();
    });

    test('WiFi et 4G ensemble comptent comme en ligne', () async {
      final s = ConnectivityService(
        probe: FakeProbe(
          initial: const [ConnectivityResult.wifi, ConnectivityResult.mobile],
        ),
      );
      await s.initialised;

      expect(s.isOnline, isTrue);

      s.dispose();
    });

    test('panne puis retour : une notification chacun', () async {
      final probe = FakeProbe(initial: const [ConnectivityResult.wifi]);
      final s = ConnectivityService(probe: probe);
      await s.initialised;

      var notified = 0;
      s.addListener(() => notified++);

      probe.emit(const []);
      await _settle();
      expect(s.isOnline, isFalse);
      expect(notified, 1);

      probe.emit(const [ConnectivityResult.mobile]);
      await _settle();
      expect(s.isOnline, isTrue);
      expect(notified, 2);

      s.dispose();
      await probe.close();
    });

    test('un état inchangé ne notifie pas', () async {
      final probe = FakeProbe(initial: const [ConnectivityResult.wifi]);
      final s = ConnectivityService(probe: probe);
      await s.initialised;

      var notified = 0;
      s.addListener(() => notified++);

      probe.emit(const [ConnectivityResult.mobile]); // toujours en ligne
      await _settle();
      expect(notified, 0);

      s.dispose();
      await probe.close();
    });

    test('une lecture initiale ratée ne déclare pas de panne', () async {
      final s = ConnectivityService(
        probe: FakeProbe(initial: const [], failFirstCheck: true),
      );
      await s.initialised;

      expect(s.isKnown, isFalse);
      expect(s.isOnline, isTrue, reason: 'un échec de lecture ne prouve rien');

      s.dispose();
    });

    test('après dispose, une émission ne notifie plus', () async {
      final probe = FakeProbe(initial: const [ConnectivityResult.wifi]);
      final s = ConnectivityService(probe: probe);
      await s.initialised;

      var notified = 0;
      s.addListener(() => notified++);
      s.dispose();

      probe.emit(const []);
      await _settle();
      expect(notified, 0);

      await probe.close();
    });
  });

  group('OfflineHost', () {
    Future<void> pump(WidgetTester tester, ConnectivityService service) =>
        tester.pumpWidget(
          ChangeNotifierProvider<ConnectivityService>.value(
            value: service,
            child: MaterialApp(
              theme: KultivTheme.light(),
              home: const Scaffold(body: OfflineHost(child: SizedBox())),
            ),
          ),
        );

    testWidgets('aucun bandeau en ligne', (tester) async {
      final s = ConnectivityService(
        probe: FakeProbe(initial: const [ConnectivityResult.wifi]),
      );
      await pump(tester, s);
      await s.initialised;
      await tester.pumpAndSettle();

      expect(find.text(OfflineBanner.message), findsNothing);

      s.dispose();
    });

    testWidgets('le bandeau apparaît hors connexion', (tester) async {
      final s = ConnectivityService(probe: FakeProbe(initial: const []));
      await pump(tester, s);
      await s.initialised;
      await tester.pumpAndSettle();

      expect(find.text(OfflineBanner.message), findsOneWidget);

      s.dispose();
    });

    testWidgets('le bandeau disparaît au retour du réseau', (tester) async {
      final probe = FakeProbe(initial: const [ConnectivityResult.wifi]);
      final s = ConnectivityService(probe: probe);
      await pump(tester, s);
      await s.initialised;
      await tester.pumpAndSettle();
      expect(find.text(OfflineBanner.message), findsNothing);

      probe.emit(const []);
      await tester.pumpAndSettle();
      expect(find.text(OfflineBanner.message), findsOneWidget);

      probe.emit(const [ConnectivityResult.mobile]);
      await tester.pumpAndSettle();
      expect(find.text(OfflineBanner.message), findsNothing);

      s.dispose();
      await probe.close();
    });

    testWidgets('pas de clignotement avant la première lecture', (tester) async {
      final gate = Completer<void>();
      final probe = FakeProbe(initial: const [], gate: gate);
      final s = ConnectivityService(probe: probe);
      await pump(tester, s);
      await tester.pump();

      // Le réseau est en réalité coupé, mais on ne le sait pas encore :
      // afficher « hors connexion » sur la première frame ferait clignoter
      // une application qui, elle, fonctionne.
      expect(find.text(OfflineBanner.message), findsNothing);

      gate.complete();
      await s.initialised;
      await tester.pumpAndSettle();
      expect(find.text(OfflineBanner.message), findsOneWidget);

      s.dispose();
      await probe.close();
    });
  });
}