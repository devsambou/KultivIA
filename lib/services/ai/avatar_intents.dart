import '../../languages/registry.dart';

bool looksLikeCameraRequest(String text) {
  final normalized = text.toLowerCase().trim();

  return languagePacks.any(
    (pack) => pack.cameraWords.any(
      (word) => normalized.contains(word.toLowerCase()),
    ),
  );
}

String cameraReply(String languageCode) {
  return languagePackFor(languageCode).cameraReply;
}
