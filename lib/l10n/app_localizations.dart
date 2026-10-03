import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ln.dart';
import 'app_localizations_wo.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('ln'),
    Locale('wo')
  ];

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'KultivIA'**
  String get appName;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @appLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'application'**
  String get appLanguage;

  /// No description provided for @aiLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'assistant IA'**
  String get aiLanguage;

  /// No description provided for @appearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get appearance;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSystem;

  /// No description provided for @themeLightDesc.
  ///
  /// In fr, this message translates to:
  /// **'Toujours utiliser le thème clair'**
  String get themeLightDesc;

  /// No description provided for @themeDarkDesc.
  ///
  /// In fr, this message translates to:
  /// **'Toujours utiliser le thème sombre'**
  String get themeDarkDesc;

  /// No description provided for @themeSystemDesc.
  ///
  /// In fr, this message translates to:
  /// **'Suivre le réglage du téléphone'**
  String get themeSystemDesc;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Alertes météo et signalements'**
  String get notificationsDesc;

  /// No description provided for @voiceReplies.
  ///
  /// In fr, this message translates to:
  /// **'Écouter les réponses'**
  String get voiceReplies;

  /// No description provided for @voiceRepliesDesc.
  ///
  /// In fr, this message translates to:
  /// **'L\'assistant vous parle à voix haute'**
  String get voiceRepliesDesc;

  /// No description provided for @profile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @role.
  ///
  /// In fr, this message translates to:
  /// **'Rôle'**
  String get role;

  /// No description provided for @farmer.
  ///
  /// In fr, this message translates to:
  /// **'Agriculteur'**
  String get farmer;

  /// No description provided for @vendor.
  ///
  /// In fr, this message translates to:
  /// **'Vendeur d\'intrants'**
  String get vendor;

  /// No description provided for @advisor.
  ///
  /// In fr, this message translates to:
  /// **'Conseiller agricole'**
  String get advisor;

  /// No description provided for @cityRegion.
  ///
  /// In fr, this message translates to:
  /// **'Ville / Région'**
  String get cityRegion;

  /// No description provided for @cityHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Thiès'**
  String get cityHint;

  /// No description provided for @detectCity.
  ///
  /// In fr, this message translates to:
  /// **'Détecter ma ville'**
  String get detectCity;

  /// No description provided for @phone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get phone;

  /// No description provided for @phoneNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get phoneNumber;

  /// No description provided for @phoneHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. 77 123 45 67'**
  String get phoneHint;

  /// No description provided for @countryCode.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif pays'**
  String get countryCode;

  /// No description provided for @crops.
  ///
  /// In fr, this message translates to:
  /// **'Cultures'**
  String get crops;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement...'**
  String get saving;

  /// No description provided for @saved.
  ///
  /// In fr, this message translates to:
  /// **'Profil mis à jour'**
  String get saved;

  /// No description provided for @saveError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de sauvegarder : '**
  String get saveError;

  /// No description provided for @photoUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil mise à jour'**
  String get photoUpdated;

  /// No description provided for @photoError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur upload : '**
  String get photoError;

  /// No description provided for @nameHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom'**
  String get nameHint;

  /// No description provided for @history.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get history;

  /// No description provided for @farmHealth.
  ///
  /// In fr, this message translates to:
  /// **'Santé exploitation'**
  String get farmHealth;

  /// No description provided for @weatherAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes météo'**
  String get weatherAlerts;

  /// No description provided for @inputVendors.
  ///
  /// In fr, this message translates to:
  /// **'Points de vente d\'intrants'**
  String get inputVendors;

  /// No description provided for @community.
  ///
  /// In fr, this message translates to:
  /// **'Communauté'**
  String get community;

  /// No description provided for @marketplace.
  ///
  /// In fr, this message translates to:
  /// **'Marketplace'**
  String get marketplace;

  /// No description provided for @newChat.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle conversation'**
  String get newChat;

  /// No description provided for @diagnosisResult.
  ///
  /// In fr, this message translates to:
  /// **'Résultat du diagnostic'**
  String get diagnosisResult;

  /// No description provided for @confidence.
  ///
  /// In fr, this message translates to:
  /// **'Confiance : '**
  String get confidence;

  /// No description provided for @treatment.
  ///
  /// In fr, this message translates to:
  /// **'Traitement conseillé'**
  String get treatment;

  /// No description provided for @noAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Aucun conseil disponible.'**
  String get noAdvice;

  /// No description provided for @listenAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Écouter le conseil'**
  String get listenAdvice;

  /// No description provided for @goFurther.
  ///
  /// In fr, this message translates to:
  /// **'Aller plus loin'**
  String get goFurther;

  /// No description provided for @nearbyVendors.
  ///
  /// In fr, this message translates to:
  /// **'Points de vente d\'intrants à proximité'**
  String get nearbyVendors;

  /// No description provided for @geoMap.
  ///
  /// In fr, this message translates to:
  /// **'Carte géolocalisée par distance'**
  String get geoMap;

  /// No description provided for @weatherAlertsDisease.
  ///
  /// In fr, this message translates to:
  /// **'Alertes météo pour cette maladie'**
  String get weatherAlertsDisease;

  /// No description provided for @prevention.
  ///
  /// In fr, this message translates to:
  /// **'Prévention en amont des symptômes'**
  String get prevention;

  /// No description provided for @nearbyReports.
  ///
  /// In fr, this message translates to:
  /// **'Signalements proches de chez vous'**
  String get nearbyReports;

  /// No description provided for @communitySharing.
  ///
  /// In fr, this message translates to:
  /// **'Partage communautaire'**
  String get communitySharing;

  /// No description provided for @sellHarvest.
  ///
  /// In fr, this message translates to:
  /// **'Vendre ma récolte'**
  String get sellHarvest;

  /// No description provided for @buyerSeller.
  ///
  /// In fr, this message translates to:
  /// **'Marketplace acheteur/vendeur'**
  String get buyerSeller;

  /// No description provided for @farmHealthScore.
  ///
  /// In fr, this message translates to:
  /// **'Score de santé de l\'exploitation'**
  String get farmHealthScore;

  /// No description provided for @overviewDiagnostics.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble de vos diagnostics'**
  String get overviewDiagnostics;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @error.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get error;

  /// No description provided for @permissionLocation.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez la localisation dans les réglages.'**
  String get permissionLocation;

  /// No description provided for @cityDetectError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de détecter la ville : '**
  String get cityDetectError;

  /// No description provided for @uploadPhotoError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur upload : '**
  String get uploadPhotoError;

  /// No description provided for @profileUpdateError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de sauvegarder : '**
  String get profileUpdateError;

  /// No description provided for @notificationsEnableError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier ce réglage pour le moment.'**
  String get notificationsEnableError;

  /// No description provided for @notificationsPermission.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez les notifications dans les réglages du téléphone.'**
  String get notificationsPermission;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'ln', 'wo'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'ln':
      return AppLocalizationsLn();
    case 'wo':
      return AppLocalizationsWo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
