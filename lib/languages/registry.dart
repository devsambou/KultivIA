import 'en.dart';
import 'fr.dart';
import 'ln.dart';
import 'wo.dart';
import 'language_pack.dart';

const languagePacks = [
  frenchPack,
  englishPack,
  wolofPack,
  lingalaPack,
];

LanguagePack languagePackFor(String code) {
  for (final pack in languagePacks) {
    if (pack.code == code) {
      return pack;
    }
  }

  return frenchPack;
}
