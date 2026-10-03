import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kultivia/models/diagnosis.dart';
import 'package:kultivia/models/user_profile.dart';
import 'package:kultivia/repositories/diagnosis_repository.dart';
import 'package:kultivia/repositories/mirrored_diagnosis_repository.dart';
import 'package:kultivia/services/sync/supabase_mirror.dart';

/// Garantie centrale de la double écriture : **Firestore reste la source de
/// vérité**. Si la réplication Supabase échoue, l'utilisateur ne doit pas le
/// remarquer.
///
/// Ces tests ne vérifient pas que Supabase reçoit les données — c'est fait par
/// `tools/verif-sync.mjs` contre la vraie base. Ils vérifient que l'échec de la
/// réplication est sans conséquence.
void main() {
  const profile = UserProfile(
    displayName: 'Awa Diop',
    locality: 'Thiès',
    crops: ['mangue'],
  );

  final diagnosis = Diagnosis(
    id: '1700000000000000',
    date: DateTime.utc(2026, 1, 15, 10),
    inputText: 'les feuilles jaunissent',
    disease: 'mouche des fruits',
    confidence: 0.82,
    advice: 'ramasser les fruits tombés',
    rawAiResponse: '{}',
  );

  group('SupabaseMirror ne lève jamais', () {
    test('un client HTTP qui lève est absorbé', () async {
      final mirror = SupabaseMirror(
        client: _ThrowingClient(),
        idToken: () async => 'jeton-valide',
      );

      expect(await mirror.mirrorUser(profile.toMap()), isFalse);
    });

    test('une réponse en erreur HTTP est absorbée', () async {
      final mirror = SupabaseMirror(
        client: _StubClient(http.Response('nope', 500)),
        idToken: () async => 'jeton-valide',
      );

      expect(await mirror.mirrorUser(profile.toMap()), isFalse);
    });

    test('une réponse 200 malformée est absorbée', () async {
      final mirror = SupabaseMirror(
        client: _StubClient(http.Response('pas du json', 200)),
        idToken: () async => 'jeton-valide',
      );

      expect(await mirror.mirrorUser(profile.toMap()), isFalse);
    });

    test('une écriture ignorée par la règle de conflit n\'est pas une erreur',
        () async {
      final body = jsonEncode({'ok': true, 'written': false, 'ignored': true});

      final mirror = SupabaseMirror(
        client: _StubClient(http.Response(body, 200)),
        idToken: () async => 'jeton-valide',
      );

      // last-write-wins a rejeté une écriture plus ancienne : la source reste
      // valide, la réplication a fait son travail.
      expect(await mirror.mirrorUser(profile.toMap()), isTrue);
    });

    test('l\'absence de jeton est un non-fatal', () async {
      final mirror = SupabaseMirror(
        client: _ThrowingClient(),
        idToken: () async => null,
      );

      expect(await mirror.mirrorUser(profile.toMap()), isFalse);
    });

    test('un serveur muet est abandonné après le délai', () async {
      final mirror = SupabaseMirror(
        client: _HangingClient(),
        idToken: () async => 'jeton-valide',
        timeout: const Duration(milliseconds: 80),
      );

      // Le miroir abandonne au lieu de retenir l'appelant indéfiniment.
      expect(await mirror.mirrorUser(profile.toMap()), isFalse);
    });
  });

  group('MirroredDiagnosisRepository', () {
    test('écrit dans Firestore avant de répliquer', () async {
      final delegate = _RecordingRepository();
      final mirror = _RecordingMirror();

      await MirroredDiagnosisRepository(delegate: delegate, mirror: mirror)
          .saveDiagnosis(diagnosis);

      expect(delegate.saved, [diagnosis.id]);
      expect(mirror.mirrored, hasLength(1));
    });

    test('un échec Firestore interdit la réplication', () async {
      final delegate = _RecordingRepository(failOnSave: true);
      final mirror = _RecordingMirror();

      await expectLater(
        MirroredDiagnosisRepository(delegate: delegate, mirror: mirror)
            .saveDiagnosis(diagnosis),
        throwsA(isA<StateError>()),
      );

      // Répliquer une écriture que Firestore n'a pas acceptée créerait dans le
      // réplica une ligne absente de la source.
      expect(mirror.mirrored, isEmpty);
    });

    test('un miroir défaillant ne fait pas échouer l\'écriture', () async {
      final delegate = _RecordingRepository();

      await MirroredDiagnosisRepository(
        delegate: delegate,
        mirror: _RecordingMirror(fail: true),
      ).saveDiagnosis(diagnosis);

      // L'écriture principale a réussi malgré l'incident de réplication.
      expect(delegate.saved, [diagnosis.id]);
    });

    test('la lecture et la suppression restent celles du délégué', () async {
      final delegate = _RecordingRepository();
      final repo = MirroredDiagnosisRepository(
        delegate: delegate,
        mirror: _RecordingMirror(),
      );

      expect(repo.watchDiagnoses(), same(delegate.stream));

      await repo.deleteDiagnosis('abc');
      expect(delegate.deleted, ['abc']);

      await repo.dispose();
      expect(delegate.disposed, isTrue);
    });
  });

  group('UserProfile.toMap', () {
    test('inclut updatedAt, nécessaire au last-write-wins', () {
      final data = profile.toMap();

      expect(data['updatedAt'], isA<String>());
      expect(() => DateTime.parse(data['updatedAt'] as String), returnsNormally);
    });

    test('updatedAt est régénéré à chaque écriture', () async {
      final first = profile.toMap()['updatedAt'] as String;

      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(profile.toMap()['updatedAt'], isNot(first));
    });

    test('depuis Firestore, updatedAt est ignoré proprement', () {
      // Un document Firestore contient cette clé : le modèle doit la tolérer
      // au lieu d'échouer à la relecture.
      expect(UserProfile.fromMap(profile.toMap()).displayName, 'Awa Diop');
    });
  });
}

/// Client qui renvoie toujours la même réponse, sans accès réseau.
class _StubClient extends http.BaseClient {
  _StubClient(this._response);

  final http.Response _response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(_response.body)),
      _response.statusCode,
    );
  }
}

/// Simule un réseau coupé.
class _ThrowingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future.error(const SocketException('réseau indisponible'));
}

/// Simule un serveur qui ne répond jamais : force le délai dépassé du miroir.
class _HangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

/// Miroir d'enregistrement. [fail] simule un réplica indisponible.
class _RecordingMirror implements SupabaseMirror {
  _RecordingMirror({this.fail = false});

  final bool fail;
  final List<Map<String, dynamic>> mirrored = [];

  @override
  Future<bool> mirrorUser(Map<String, dynamic> data) async {
    if (fail) return false;

    mirrored.add(data);

    return true;
  }

  @override
  Future<bool> mirrorDiagnosis(Map<String, dynamic> data) async {
    if (fail) return false;

    mirrored.add(data);

    return true;
  }
}

class _RecordingRepository implements DiagnosisRepository {
  _RecordingRepository({this.failOnSave = false});

  final bool failOnSave;
  final List<String> saved = [];
  final List<String> deleted = [];
  bool disposed = false;

  final stream = const Stream<List<Diagnosis>>.empty();

  @override
  Future<void> saveDiagnosis(Diagnosis diagnosis) async {
    if (failOnSave) throw StateError('Firestore indisponible');

    saved.add(diagnosis.id);
  }

  @override
  Stream<List<Diagnosis>> watchDiagnoses() => stream;

  @override
  Future<void> deleteDiagnosis(String diagnosisId) async {
    deleted.add(diagnosisId);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}