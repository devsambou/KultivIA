class LanguagePack {
  const LanguagePack({
    required this.code,
    required this.name,
    required this.greeting,
    required this.cameraWords,
    required this.cameraReply,
    required this.spokenStyleHint,
    required this.usesCloudVoice,
  });

  final String code;
  final String name;
  final String greeting;
  final List<String> cameraWords;
  final String cameraReply;
  final String spokenStyleHint;
  final bool usesCloudVoice;
}
