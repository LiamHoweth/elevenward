// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Elevenward';

  @override
  String get career => 'Carrière';

  @override
  String get world => 'Monde';

  @override
  String get life => 'Vie';

  @override
  String get more => 'Plus';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get careerSlots => 'Emplacements de carrière';

  @override
  String get careerSlotsIntro =>
      'Deux carrières complètes sont gratuites. Votre progression reste sur cet appareil, sauf si vous choisissez la synchronisation cloud.';

  @override
  String get newCareer => 'Nouvelle carrière';

  @override
  String get emptySlot => 'Emplacement vide';

  @override
  String seasonWeek(int season, int week) {
    return 'Saison $season · Journée $week';
  }

  @override
  String get createPlayer => 'Créez votre joueur';

  @override
  String get playerName => 'Nom';

  @override
  String get positionAndStyle => 'Poste et style';

  @override
  String get nationalTeam => 'Équipe nationale';

  @override
  String get startingClub => 'Club de départ';

  @override
  String get difficulty => 'Difficulté';

  @override
  String get startCareer => 'Commencer';

  @override
  String get story => 'Histoire';

  @override
  String get professional => 'Professionnel';

  @override
  String get worldClass => 'Classe mondiale';

  @override
  String get chooseEdge => 'Choisissez votre avantage.';

  @override
  String get weeklyFocusBody =>
      'Votre priorité influence la progression, la forme, la sélection et vos chances quand votre moment arrive.';

  @override
  String get trainingLoad => 'Charge d’entraînement';

  @override
  String get setFocus => 'Définir la priorité';

  @override
  String get nextMatch => 'Prochain match';

  @override
  String get home => 'Domicile';

  @override
  String get away => 'Extérieur';

  @override
  String get leagueTable => 'Classement';

  @override
  String get allCompetitions => 'Toutes les compétitions';

  @override
  String get nationalTeams => 'Équipes nationales';

  @override
  String get majorTournament => 'Tournoi majeur tous les quatre ans';

  @override
  String get market => 'Marché du mode de vie';

  @override
  String get relationships => 'Relations';

  @override
  String get agent => 'Agent';

  @override
  String get sponsors => 'Sponsors';

  @override
  String get owned => 'Acheté';

  @override
  String get buy => 'Acheter';

  @override
  String get notEnoughMoney => 'Fonds insuffisants';

  @override
  String get permanentUpgrades => 'Améliorations cosmétiques permanentes';

  @override
  String get extraCareerSlots => 'Emplacements supplémentaires';

  @override
  String get extraCareerSlotsBody =>
      'Passe de deux à cinq carrières sur l’appareil. Aucun avantage de jeu.';

  @override
  String get supporterPack => 'Pack Supporter';

  @override
  String get supporterPackBody =>
      'Ajoute uniquement des avatars, thèmes, archives et cartes à partager.';

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get settings => 'Réglages';

  @override
  String get language => 'Langue';

  @override
  String get analyticsConsent => 'Partager des statistiques anonymes';

  @override
  String get analyticsBody =>
      'Des comptages facultatifs aident à équilibrer le jeu. Sans publicité, identifiant de suivi, contacts ni position précise.';

  @override
  String get accountAndCloud => 'Compte et cloud';

  @override
  String get guestMode => 'Partie hors ligne en mode invité';

  @override
  String signedInAs(String alias) {
    return 'Connecté comme $alias';
  }

  @override
  String get signInApple => 'Se connecter avec Apple';

  @override
  String get signInGoogle => 'Se connecter avec Google';

  @override
  String get syncNow => 'Synchroniser';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountWarning =>
      'Cette action supprime définitivement les sauvegardes cloud, classements et données du compte. Les carrières locales restent jusqu’à leur suppression.';

  @override
  String contentVersion(String version) {
    return 'Contenu $version';
  }

  @override
  String get offlineReady => 'Les carrières complètes fonctionnent hors ligne';

  @override
  String get retirement => 'Retraite';

  @override
  String get legacy => 'Héritage';

  @override
  String get contractOffers => 'Offres de contrat';

  @override
  String get stayAtClub => 'Rester dans mon club';

  @override
  String get acceptOffer => 'Accepter l’offre';

  @override
  String get retireNow => 'Prendre ma retraite';

  @override
  String get seasonComplete => 'Saison terminée';

  @override
  String get careerComplete => 'Carrière terminée';

  @override
  String get shareCareer => 'Partager la carte';

  @override
  String get close => 'Fermer';

  @override
  String get errorTryAgain =>
      'Une erreur s’est produite. Votre carrière locale est en sécurité ; réessayez.';
}
