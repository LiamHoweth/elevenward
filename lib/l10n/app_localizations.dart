import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Elevenward'**
  String get appTitle;

  /// No description provided for @career.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get career;

  /// No description provided for @world.
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get world;

  /// No description provided for @life.
  ///
  /// In en, this message translates to:
  /// **'Life'**
  String get life;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @careerSlots.
  ///
  /// In en, this message translates to:
  /// **'Career slots'**
  String get careerSlots;

  /// No description provided for @careerSlotsIntro.
  ///
  /// In en, this message translates to:
  /// **'Two complete careers are free. Your progress stays on this device unless you choose cloud sync.'**
  String get careerSlotsIntro;

  /// No description provided for @newCareer.
  ///
  /// In en, this message translates to:
  /// **'New career'**
  String get newCareer;

  /// No description provided for @emptySlot.
  ///
  /// In en, this message translates to:
  /// **'Empty slot'**
  String get emptySlot;

  /// No description provided for @seasonWeek.
  ///
  /// In en, this message translates to:
  /// **'Season {season} · Week {week}'**
  String seasonWeek(int season, int week);

  /// No description provided for @createPlayer.
  ///
  /// In en, this message translates to:
  /// **'Create your player'**
  String get createPlayer;

  /// No description provided for @playerName.
  ///
  /// In en, this message translates to:
  /// **'Player name'**
  String get playerName;

  /// No description provided for @positionAndStyle.
  ///
  /// In en, this message translates to:
  /// **'Position & style'**
  String get positionAndStyle;

  /// No description provided for @nationalTeam.
  ///
  /// In en, this message translates to:
  /// **'National team'**
  String get nationalTeam;

  /// No description provided for @startingClub.
  ///
  /// In en, this message translates to:
  /// **'Starting club'**
  String get startingClub;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @startCareer.
  ///
  /// In en, this message translates to:
  /// **'Start career'**
  String get startCareer;

  /// No description provided for @story.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get story;

  /// No description provided for @professional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get professional;

  /// No description provided for @worldClass.
  ///
  /// In en, this message translates to:
  /// **'World class'**
  String get worldClass;

  /// No description provided for @chooseEdge.
  ///
  /// In en, this message translates to:
  /// **'Choose your edge.'**
  String get chooseEdge;

  /// No description provided for @weeklyFocusBody.
  ///
  /// In en, this message translates to:
  /// **'Your focus changes development, fitness, selection, and the odds when your moment comes.'**
  String get weeklyFocusBody;

  /// No description provided for @trainingLoad.
  ///
  /// In en, this message translates to:
  /// **'Training load'**
  String get trainingLoad;

  /// No description provided for @setFocus.
  ///
  /// In en, this message translates to:
  /// **'Set focus'**
  String get setFocus;

  /// No description provided for @nextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get nextMatch;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @away.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get away;

  /// No description provided for @leagueTable.
  ///
  /// In en, this message translates to:
  /// **'League table'**
  String get leagueTable;

  /// No description provided for @allCompetitions.
  ///
  /// In en, this message translates to:
  /// **'All competitions'**
  String get allCompetitions;

  /// No description provided for @nationalTeams.
  ///
  /// In en, this message translates to:
  /// **'National teams'**
  String get nationalTeams;

  /// No description provided for @majorTournament.
  ///
  /// In en, this message translates to:
  /// **'Major tournament every four seasons'**
  String get majorTournament;

  /// No description provided for @market.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle market'**
  String get market;

  /// No description provided for @relationships.
  ///
  /// In en, this message translates to:
  /// **'Relationships'**
  String get relationships;

  /// No description provided for @agent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agent;

  /// No description provided for @sponsors.
  ///
  /// In en, this message translates to:
  /// **'Sponsors'**
  String get sponsors;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get owned;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @notEnoughMoney.
  ///
  /// In en, this message translates to:
  /// **'Not enough money'**
  String get notEnoughMoney;

  /// No description provided for @permanentUpgrades.
  ///
  /// In en, this message translates to:
  /// **'Permanent cosmetic upgrades'**
  String get permanentUpgrades;

  /// No description provided for @extraCareerSlots.
  ///
  /// In en, this message translates to:
  /// **'Extra Career Slots'**
  String get extraCareerSlots;

  /// No description provided for @extraCareerSlotsBody.
  ///
  /// In en, this message translates to:
  /// **'Increase the device limit from two careers to five. No gameplay advantage.'**
  String get extraCareerSlotsBody;

  /// No description provided for @supporterPack.
  ///
  /// In en, this message translates to:
  /// **'Supporter Pack'**
  String get supporterPack;

  /// No description provided for @supporterPackBody.
  ///
  /// In en, this message translates to:
  /// **'Adds avatars, themes, archive layouts, and share-card designs only.'**
  String get supporterPackBody;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @analyticsConsent.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous gameplay analytics'**
  String get analyticsConsent;

  /// No description provided for @analyticsBody.
  ///
  /// In en, this message translates to:
  /// **'Optional first-party event counts help balance the game. No ads, tracking identifiers, contacts, or precise location.'**
  String get analyticsBody;

  /// No description provided for @accountAndCloud.
  ///
  /// In en, this message translates to:
  /// **'Account & cloud'**
  String get accountAndCloud;

  /// No description provided for @guestMode.
  ///
  /// In en, this message translates to:
  /// **'Playing offline as a guest'**
  String get guestMode;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {alias}'**
  String signedInAs(String alias);

  /// No description provided for @signInApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get signInApple;

  /// No description provided for @signInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInGoogle;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes cloud saves, leaderboard entries, entitlements cached on the server, and account data. Local careers remain until you delete them.'**
  String get deleteAccountWarning;

  /// No description provided for @contentVersion.
  ///
  /// In en, this message translates to:
  /// **'Content {version}'**
  String contentVersion(String version);

  /// No description provided for @offlineReady.
  ///
  /// In en, this message translates to:
  /// **'Full careers work offline'**
  String get offlineReady;

  /// No description provided for @retirement.
  ///
  /// In en, this message translates to:
  /// **'Retirement'**
  String get retirement;

  /// No description provided for @legacy.
  ///
  /// In en, this message translates to:
  /// **'Legacy'**
  String get legacy;

  /// No description provided for @contractOffers.
  ///
  /// In en, this message translates to:
  /// **'Contract offers'**
  String get contractOffers;

  /// No description provided for @stayAtClub.
  ///
  /// In en, this message translates to:
  /// **'Stay at my club'**
  String get stayAtClub;

  /// No description provided for @acceptOffer.
  ///
  /// In en, this message translates to:
  /// **'Accept offer'**
  String get acceptOffer;

  /// No description provided for @retireNow.
  ///
  /// In en, this message translates to:
  /// **'Retire now'**
  String get retireNow;

  /// No description provided for @seasonComplete.
  ///
  /// In en, this message translates to:
  /// **'Season complete'**
  String get seasonComplete;

  /// No description provided for @careerComplete.
  ///
  /// In en, this message translates to:
  /// **'Career complete'**
  String get careerComplete;

  /// No description provided for @shareCareer.
  ///
  /// In en, this message translates to:
  /// **'Share career card'**
  String get shareCareer;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @errorTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Your local career is safe; try again.'**
  String get errorTryAgain;
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
      <String>['en', 'es', 'fr', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
