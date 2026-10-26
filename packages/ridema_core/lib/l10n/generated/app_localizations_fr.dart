// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuler';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get retry => 'Réessayer';

  @override
  String get save => 'Enregistrer';

  @override
  String get close => 'Fermer';

  @override
  String get back => 'Retour';

  @override
  String get next => 'Suivant';

  @override
  String get done => 'Terminé';

  @override
  String get send => 'Envoyer';

  @override
  String get confirm => 'Confirmer';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get loading => 'Chargement…';

  @override
  String get openSettings => 'Ouvrir les réglages';

  @override
  String get read => 'Lire';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié';

  @override
  String get share => 'Partager';

  @override
  String get edit => 'Modifier';

  @override
  String get delete => 'Supprimer';

  @override
  String get required => 'Obligatoire';

  @override
  String get optional => 'Facultatif';

  @override
  String priceDh(int amount) {
    return '$amount DH';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String kmShort(String km) {
    return '$km km';
  }

  @override
  String ratingWithCount(int count, String rating) {
    return '$rating ★ ($count)';
  }

  @override
  String tripsCount(int count) {
    return '$count courses';
  }

  @override
  String get newRating => 'Nouveau';

  @override
  String get statusLabel => 'Statut';

  @override
  String get dateLabel => 'Date';

  @override
  String get noConnectionBanner =>
      'Pas de connexion internet. Nous réessayons…';

  @override
  String get languageTitle => 'Choisissez votre langue';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageLabel => 'Langue';

  @override
  String get languageChangeLater =>
      'Vous pourrez la changer plus tard dans Profil.';

  @override
  String get bootLoading => 'Démarrage…';

  @override
  String bootOffline(String app) {
    return 'Impossible de joindre $app. Vérifiez votre connexion internet.';
  }

  @override
  String get updateTitle => 'Mise à jour nécessaire';

  @override
  String updateBody(String app, String version) {
    return 'Cette version de $app est trop ancienne. Installez la version $version pour continuer.';
  }

  @override
  String get updateDownload => 'Télécharger la mise à jour';

  @override
  String updateDownloading(int percent) {
    return 'Téléchargement… $percent %';
  }

  @override
  String get updateInstall => 'Installer';

  @override
  String get updateOpenStore => 'Ouvrir le store';

  @override
  String updateAllowInstall(String app) {
    return 'Android va vous demander d’autoriser l’installation d’applications depuis $app. Autorisez, puis revenez et appuyez sur Installer.';
  }

  @override
  String get updateFailed =>
      'Le téléchargement a échoué. Vérifiez votre connexion et réessayez.';

  @override
  String get updateAvailable => 'Une nouvelle version est disponible.';

  @override
  String get updateNoLink => 'Demandez la nouvelle version au support.';

  @override
  String welcomeTitle(String app) {
    return 'Bienvenue sur $app';
  }

  @override
  String get welcomeRiderTagline =>
      'Vous proposez le prix. Les chauffeurs proches répondent.';

  @override
  String get welcomeDriverTagline =>
      'Recevez des courses près de vous. Acceptez le prix ou proposez le vôtre. 0 % de commission.';

  @override
  String get welcomeSignUp => 'Créer un compte';

  @override
  String get welcomeLogIn => 'J’ai déjà un compte';

  @override
  String get welcomeCash => 'Paiement en espèces, directement au chauffeur.';

  @override
  String get signUpTitle => 'Créer votre compte';

  @override
  String get fullNameLabel => 'Nom complet';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get confirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get passwordHint => 'Au moins 10 caractères';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get errorNameShort => 'Entrez votre nom complet.';

  @override
  String get errorEmailInvalid => 'Cette adresse e-mail n’est pas valide.';

  @override
  String get errorPasswordShort => 'Utilisez au moins 10 caractères.';

  @override
  String get errorPasswordMismatch => 'Les deux mots de passe sont différents.';

  @override
  String get errorCodeFormat => 'Entrez les 6 chiffres.';

  @override
  String get consentsTitle => 'Avant de commencer';

  @override
  String get consentsIntro =>
      'Lisez et acceptez chaque point. Appuyez sur « Lire » pour voir le texte complet.';

  @override
  String get consentTerms => 'J’accepte les Conditions d’utilisation';

  @override
  String get consentPrivacy => 'J’accepte la Politique de confidentialité';

  @override
  String get consentDataTransfer =>
      'J’accepte que certaines de mes données soient traitées par des services situés hors du Maroc';

  @override
  String get consentDataTransferExplain =>
      'Google Maps affiche la carte, Firebase (Google) envoie les notifications et WhatsApp (Meta) envoie votre code de téléphone. Ces sociétés peuvent stocker des données hors du Maroc. Sans elles, l’application ne peut pas fonctionner.';

  @override
  String consentBackgroundLocation(String app) {
    return 'J’accepte que $app utilise ma position en arrière-plan quand je suis en ligne';
  }

  @override
  String get consentBackgroundExplain =>
      'Les clients proches peuvent vous trouver et suivre la course, même si l’application est fermée. Quand vous passez hors ligne, nous arrêtons.';

  @override
  String get consentsAllRequired =>
      'Toutes les cases sont nécessaires pour utiliser l’application.';

  @override
  String get consentsAccept => 'Accepter et créer mon compte';

  @override
  String get consentsLoadFailed =>
      'Impossible de charger les textes. Vérifiez votre connexion et réessayez.';

  @override
  String consentVersion(String version) {
    return 'Version $version';
  }

  @override
  String get consentsOutdated =>
      'Un texte a été mis à jour. Merci de le relire.';

  @override
  String get verifyEmailTitle => 'Vérifiez votre e-mail';

  @override
  String verifyEmailBody(String email) {
    return 'Nous avons envoyé un code à 6 chiffres à $email. Entrez-le ci-dessous ou appuyez sur le lien dans l’e-mail.';
  }

  @override
  String get verifyEmailSpam => 'Rien reçu ? Regardez dans les spams.';

  @override
  String get codeLabel => 'Code à 6 chiffres';

  @override
  String get verifyButton => 'Vérifier';

  @override
  String get resendCode => 'Envoyer un nouveau code';

  @override
  String resendIn(int seconds) {
    return 'Nouveau code dans $seconds s';
  }

  @override
  String get codeSent => 'Un nouveau code a été envoyé.';

  @override
  String get emailVerified => 'E-mail vérifié';

  @override
  String get iVerifiedWithLink => 'J’ai utilisé le lien de l’e-mail';

  @override
  String get loginTitle => 'Connexion';

  @override
  String get loginButton => 'Se connecter';

  @override
  String get forgotPasswordLink => 'Mot de passe oublié ?';

  @override
  String get noAccountLink => 'Pas encore de compte ? Créez-en un';

  @override
  String wrongAppRider(String app) {
    return 'C’est un compte chauffeur. Utilisez l’application $app Chauffeur.';
  }

  @override
  String get wrongAppDriver =>
      'C’est un compte client. Créez un compte chauffeur avec un autre e-mail.';

  @override
  String get twoFactorTitle => 'Code de sécurité';

  @override
  String get twoFactorEmailBody =>
      'Nous avons envoyé un code sur votre e-mail. Entrez-le ci-dessous.';

  @override
  String twoFactorTotpBody(String app) {
    return 'Ouvrez votre application d’authentification et entrez le code à 6 chiffres de $app.';
  }

  @override
  String get forgotTitle => 'Réinitialiser le mot de passe';

  @override
  String get forgotBody =>
      'Entrez votre e-mail. Si un compte existe, nous vous enverrons un code.';

  @override
  String get forgotSend => 'Envoyer le code';

  @override
  String get resetTitle => 'Choisir un nouveau mot de passe';

  @override
  String resetBody(String email) {
    return 'Entrez le code envoyé à $email et votre nouveau mot de passe.';
  }

  @override
  String get newPasswordLabel => 'Nouveau mot de passe';

  @override
  String get resetDone =>
      'Votre mot de passe a été changé. Vous pouvez vous connecter.';

  @override
  String get resetButton => 'Changer le mot de passe';

  @override
  String get verifyPhoneTitle => 'Vérifier votre téléphone';

  @override
  String get verifyPhoneBody =>
      'Nous allons envoyer un code par WhatsApp à ce numéro.';

  @override
  String get verifyPhoneWhyRider =>
      'Un numéro vérifié est nécessaire avant votre première course.';

  @override
  String get verifyPhoneWhyDriver =>
      'Un numéro vérifié est nécessaire avant de passer en ligne.';

  @override
  String get phoneLabel => 'Numéro de téléphone';

  @override
  String get phoneHint => '6XXXXXXXX';

  @override
  String get errorPhoneInvalid =>
      'Entrez les 9 chiffres après +212 (par exemple 612345678).';

  @override
  String get phoneCodesLimit =>
      'Vous pouvez demander jusqu’à 3 codes par jour pour un même numéro. Chaque code est valable 10 minutes. Le numéro doit avoir WhatsApp.';

  @override
  String get sendCodeWhatsapp => 'Envoyer le code par WhatsApp';

  @override
  String phoneCodeSentTo(String phone) {
    return 'Code envoyé par WhatsApp au $phone.';
  }

  @override
  String get changeNumber => 'Changer de numéro';

  @override
  String get phoneVerified => 'Téléphone vérifié';

  @override
  String get phonePrivacy =>
      'Votre numéro reste privé : les appels passent par l’application.';

  @override
  String get phoneChangeHint =>
      'Pour changer un numéro vérifié, envoyez une demande de correction depuis Profil › Mes données.';

  @override
  String get locationTitle => 'Votre position';

  @override
  String get locationRiderBody =>
      'Nous utilisons votre position quand l’application est ouverte pour définir votre point de départ.';

  @override
  String get locationRiderDetail =>
      'Votre chauffeur voit votre point de départ seulement pendant une course. Vous pouvez aussi taper votre adresse.';

  @override
  String locationDriverBody(String app) {
    return '$app utilise votre position même quand l’application est fermée ou non utilisée lorsque vous êtes en ligne, pour que les clients proches vous trouvent et suivent la course.';
  }

  @override
  String get locationDriverDetail =>
      'Quand vous passez hors ligne, nous arrêtons d’utiliser votre position. À l’écran suivant, choisissez « Toujours autoriser ».';

  @override
  String get locationDeniedRider =>
      'La localisation est désactivée. Vous pouvez taper votre adresse de départ.';

  @override
  String get locationNeededDriver =>
      'La localisation est nécessaire pour passer en ligne';

  @override
  String locationNeededDriverBody(String app) {
    return 'Dans les Réglages, mettez la position sur « Toujours autoriser » pour $app.';
  }

  @override
  String get locationServiceOff =>
      'La localisation (GPS) de votre téléphone est désactivée.';

  @override
  String get turnOnLocation => 'Activer la localisation';

  @override
  String get allowLocation => 'Autoriser la localisation';

  @override
  String get notifTitle => 'Restez informé';

  @override
  String get notifRiderBody =>
      'Nous vous prévenons quand un chauffeur fait une offre, arrive, ou quand votre course change.';

  @override
  String get notifDriverBody =>
      'Nous vous prévenons quand une nouvelle demande arrive près de vous, même si l’application est en arrière-plan.';

  @override
  String get notifAllow => 'Autoriser les notifications';

  @override
  String get notifDeniedBanner =>
      'Les notifications sont désactivées. Vous risquez de manquer des offres.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileName => 'Nom';

  @override
  String get profileEmail => 'E-mail';

  @override
  String get profilePhone => 'Téléphone';

  @override
  String get phoneNotVerified => 'Non vérifié';

  @override
  String get phoneVerifiedBadge => 'Vérifié';

  @override
  String get verifyNow => 'Vérifier maintenant';

  @override
  String get profileSecurity => 'Connexion en deux étapes';

  @override
  String get profileChangePassword => 'Changer le mot de passe';

  @override
  String get profileMyData => 'Mes données';

  @override
  String get profileDeleteAccount => 'Supprimer mon compte';

  @override
  String get profileLegal => 'Informations légales';

  @override
  String get profileTrips => 'Mes courses';

  @override
  String profileAppVersion(String version) {
    return 'Version de l’application $version';
  }

  @override
  String get profileRating => 'Votre note';

  @override
  String get logout => 'Se déconnecter';

  @override
  String get logoutConfirm => 'Voulez-vous vous déconnecter ?';

  @override
  String get editName => 'Modifier votre nom';

  @override
  String get saved => 'Enregistré';

  @override
  String get sessionEnded => 'Votre session a pris fin. Reconnectez-vous.';

  @override
  String get twoFactorSettingsTitle => 'Connexion en deux étapes';

  @override
  String get twoFactorExplain =>
      'Après votre mot de passe, nous demandons un second code. Même si quelqu’un connaît votre mot de passe, il ne peut pas se connecter.';

  @override
  String get twoFactorOff => 'Désactivée';

  @override
  String get twoFactorEmail => 'Code par e-mail';

  @override
  String get twoFactorTotp => 'Application d’authentification';

  @override
  String twoFactorCurrent(String method) {
    return 'Actuellement : $method';
  }

  @override
  String get twoFactorUseEmail => 'Utiliser les codes par e-mail';

  @override
  String get twoFactorUseTotp => 'Utiliser une application d’authentification';

  @override
  String get twoFactorTurnOff => 'Désactiver la connexion en deux étapes';

  @override
  String get twoFactorTotpStep1 =>
      '1. Ajoutez cette clé dans votre application d’authentification (Google Authenticator, Microsoft Authenticator…).';

  @override
  String get twoFactorSecret => 'Clé secrète';

  @override
  String get twoFactorOpenApp => 'Ouvrir dans mon application';

  @override
  String get twoFactorTotpStep2 =>
      '2. Entrez le code à 6 chiffres affiché dans l’application.';

  @override
  String get twoFactorEnabled => 'La connexion en deux étapes est activée.';

  @override
  String get twoFactorDisabled => 'La connexion en deux étapes est désactivée.';

  @override
  String get passwordConfirmPrompt =>
      'Entrez votre mot de passe pour confirmer.';

  @override
  String get changePasswordTitle => 'Changer le mot de passe';

  @override
  String get currentPasswordLabel => 'Mot de passe actuel';

  @override
  String get passwordChanged => 'Mot de passe changé.';

  @override
  String get myDataTitle => 'Mes données';

  @override
  String get myDataIntro =>
      'Selon la loi marocaine 09-08, vous pouvez obtenir une copie de vos données personnelles et nous demander de les corriger.';

  @override
  String get downloadMyData => 'Télécharger mes données';

  @override
  String get myDataReady => 'Votre fichier de données est prêt.';

  @override
  String get dataRequestsTitle => 'Mes demandes';

  @override
  String get dataRequestsEmpty => 'Aucune demande pour l’instant.';

  @override
  String get newDataRequest => 'Nouvelle demande';

  @override
  String get dataRequestAccess => 'Accès à mes données';

  @override
  String get dataRequestCorrection => 'Corriger mes données';

  @override
  String get dataRequestDeletion => 'Supprimer mes données';

  @override
  String get dataRequestDetails => 'Expliquez votre demande';

  @override
  String get dataRequestDetailsHint =>
      'Par exemple : mon nom est mal écrit, la bonne orthographe est…';

  @override
  String get dataRequestSent =>
      'Demande envoyée. Nous répondons sous 30 jours.';

  @override
  String get dataRequestOpen => 'En cours';

  @override
  String get dataRequestDone => 'Traitée';

  @override
  String get dataRequestRejected => 'Refusée';

  @override
  String dataRequestResponse(String text) {
    return 'Réponse : $text';
  }

  @override
  String get deleteTitle => 'Supprimer mon compte';

  @override
  String get deleteIntro =>
      'Votre compte est supprimé immédiatement. C’est définitif.';

  @override
  String get deleteWhatGoes =>
      'Supprimé maintenant : votre nom, e-mail, numéro de téléphone, mot de passe, appareils, documents, adresses et points GPS des courses.';

  @override
  String get deleteWhatStays =>
      'Conservé sans votre nom, pendant la durée exigée par la loi : les traces des courses (date, prix) pour que les reçus et litiges restent valables.';

  @override
  String get deleteConfirmCheck => 'Je comprends que c’est définitif';

  @override
  String get deleteButton => 'Supprimer mon compte';

  @override
  String get deleteDone => 'Votre compte a été supprimé.';

  @override
  String get legalTitle => 'Informations légales';

  @override
  String get legalTerms => 'Conditions d’utilisation';

  @override
  String get legalPrivacy => 'Politique de confidentialité';

  @override
  String get legalDataTransfer => 'Transfert de données hors du Maroc';

  @override
  String get legalBackgroundLocation => 'Localisation en arrière-plan';

  @override
  String get companyTitle => 'Société';

  @override
  String get companyName => 'Raison sociale';

  @override
  String get companyRc => 'RC';

  @override
  String get companyIce => 'ICE';

  @override
  String get companyAddress => 'Adresse';

  @override
  String get supportPhone => 'Téléphone du support';

  @override
  String get supportEmail => 'E-mail du support';

  @override
  String get receiptTitle => 'Reçu';

  @override
  String receiptNumber(String number) {
    return 'Reçu n° $number';
  }

  @override
  String get receiptFrom => 'Départ';

  @override
  String get receiptTo => 'Arrivée';

  @override
  String get receiptDistance => 'Distance';

  @override
  String get receiptDuration => 'Durée';

  @override
  String get receiptPrice => 'Prix';

  @override
  String get receiptDriver => 'Chauffeur';

  @override
  String get receiptRider => 'Client';

  @override
  String get receiptVehicle => 'Véhicule';

  @override
  String get receiptPaidCash => 'Payé en espèces au chauffeur';

  @override
  String receiptNoCommission(String app) {
    return '$app ne prend aucune commission et n’encaisse pas le prix des courses.';
  }

  @override
  String get receiptShare => 'Partager le reçu';

  @override
  String get tripHistoryTitle => 'Mes courses';

  @override
  String get tripHistoryEmpty => 'Aucune course pour l’instant.';

  @override
  String get loadMore => 'Voir plus';

  @override
  String get rideStatusSearching => 'Recherche d’un chauffeur';

  @override
  String get rideStatusAccepted => 'Chauffeur en route';

  @override
  String get rideStatusArrived => 'Chauffeur arrivé';

  @override
  String get rideStatusInProgress => 'En course';

  @override
  String get rideStatusCompleted => 'Terminée';

  @override
  String get rideStatusCancelled => 'Annulée';

  @override
  String get rideStatusExpired => 'Aucun chauffeur trouvé';

  @override
  String get homeFrom => 'Départ';

  @override
  String get homeTo => 'Destination';

  @override
  String get homeCurrentLocation => 'Ma position actuelle';

  @override
  String get homeWhereTo => 'Où allez-vous ?';

  @override
  String get homeSearchAddress => 'Chercher une adresse';

  @override
  String get homePickOnMap => 'Choisir sur la carte';

  @override
  String get offerYourFare => 'Proposez votre prix';

  @override
  String suggestedPrice(int amount) {
    return 'Prix conseillé : $amount DH';
  }

  @override
  String minOffer(int amount) {
    return 'Minimum : $amount DH';
  }

  @override
  String get commentForDriver => 'Commentaire pour le chauffeur (facultatif)';

  @override
  String get commentHint => 'Par exemple : j’ai une grande valise';

  @override
  String get findDriver => 'Trouver un chauffeur';

  @override
  String tripEstimate(String km, int minutes) {
    return '$km km · environ $minutes min';
  }

  @override
  String get searchingTitle => 'Recherche de chauffeurs…';

  @override
  String searchingTimeLeft(String time) {
    return 'Encore $time';
  }

  @override
  String get raiseFare => 'Augmenter le prix';

  @override
  String get raiseFareTitle => 'Augmenter votre prix';

  @override
  String get raiseFareHint =>
      'Un prix plus élevé attire plus de réponses. Vous ne pouvez pas le baisser.';

  @override
  String get cancelRequest => 'Annuler la demande';

  @override
  String get cancelRequestConfirm => 'Annuler votre demande ?';

  @override
  String get offersTitle => 'Offres';

  @override
  String get offerCounter => 'Contre-offre';

  @override
  String offerEta(int minutes) {
    return 'À $minutes min';
  }

  @override
  String get accept => 'Accepter';

  @override
  String get decline => 'Refuser';

  @override
  String get noOffersYet =>
      'En attente d’offres. Les chauffeurs proches voient votre demande.';

  @override
  String get requestExpiredTitle => 'Aucun chauffeur n’a accepté';

  @override
  String get requestExpiredBody => 'Réessayez avec un prix plus élevé.';

  @override
  String get offerNoLongerAvailable => 'Cette offre n’est plus disponible.';

  @override
  String get driverOnTheWay => 'Votre chauffeur arrive';

  @override
  String get driverArrivedTitle => 'Votre chauffeur est là';

  @override
  String get onTripTitle => 'En route vers votre destination';

  @override
  String etaMinutes(int minutes) {
    return 'Arrive dans $minutes min';
  }

  @override
  String get pickupPin => 'Code de prise en charge';

  @override
  String get pickupPinHint =>
      'Donnez ce code au chauffeur pour démarrer la course.';

  @override
  String get callButton => 'Appeler';

  @override
  String get shareTrip => 'Partager la course';

  @override
  String get sosButton => 'SOS';

  @override
  String get cancelRide => 'Annuler';

  @override
  String get cancelFreeInfo =>
      'Vous pouvez annuler gratuitement jusqu’à l’arrivée du chauffeur.';

  @override
  String get cancelCountedWarning =>
      'Le chauffeur est arrivé. Si vous annulez maintenant, ce sera compté.';

  @override
  String get cancelReasonTitle => 'Pourquoi annulez-vous ?';

  @override
  String get reasonChangedMind => 'J’ai changé d’avis';

  @override
  String get reasonDriverTooFar => 'Le chauffeur est trop loin';

  @override
  String get reasonDriverAsked => 'Le chauffeur m’a demandé d’annuler';

  @override
  String get reasonWrongPickup => 'Mauvais point de départ';

  @override
  String get reasonRiderNoShow => 'Le client n’est pas venu';

  @override
  String get reasonCarMismatch => 'La voiture ne correspond pas';

  @override
  String get reasonSafety => 'Je ne me sens pas en sécurité';

  @override
  String get reasonOther => 'Autre raison';

  @override
  String get carMismatch => 'La voiture ne correspond pas ?';

  @override
  String get carMismatchBody =>
      'Si la plaque ou la voiture est différente, ne montez pas. Signalez-le : vous pourrez ensuite annuler gratuitement.';

  @override
  String get reportSent => 'Merci, notre équipe a été prévenue.';

  @override
  String get cancelWarningRecent =>
      'Vous avez annulé plusieurs courses récemment. Réservez seulement quand vous êtes prêt.';

  @override
  String get rideCancelledByDriver =>
      'Le chauffeur a annulé. Vous pouvez refaire une demande.';

  @override
  String get rideCancelledByRider => 'Le client a annulé la course.';

  @override
  String get rateDriver => 'Comment était votre chauffeur ?';

  @override
  String get rateRider => 'Comment était le client ?';

  @override
  String get rateComment => 'Commentaire (facultatif)';

  @override
  String get rateSubmit => 'Envoyer la note';

  @override
  String get rateSkip => 'Passer';

  @override
  String fareToPay(int amount) {
    return 'Prix : $amount DH. Payez en espèces au chauffeur.';
  }

  @override
  String get thanksRating => 'Merci !';

  @override
  String get idCheckRequiredBody =>
      'Pour la sécurité, nous avons besoin d’une photo de votre carte d’identité avant votre prochaine course.';

  @override
  String get shareTitle => 'Partager votre course';

  @override
  String get shareBody =>
      'Ajoutez jusqu’à 5 contacts. Ils reçoivent un lien pour suivre votre course en direct jusqu’à 1 heure après la fin.';

  @override
  String get contactName => 'Nom';

  @override
  String get contactPhone => 'Téléphone';

  @override
  String get addContact => 'Ajouter un contact';

  @override
  String get shareCreate => 'Créer le lien et partager';

  @override
  String shareMessage(String app, String url) {
    return 'Suivez ma course $app en direct : $url';
  }

  @override
  String get shareMaxContacts => 'Vous pouvez ajouter jusqu’à 5 contacts.';

  @override
  String get sosTitle => 'Urgence';

  @override
  String sosBody(String app) {
    return 'Appuyez sur un service : votre téléphone l’appelle et l’équipe $app reçoit votre position en direct.';
  }

  @override
  String get sosPolice => 'Police';

  @override
  String get sosGendarmerie => 'Gendarmerie';

  @override
  String get sosAmbulance => 'Ambulance';

  @override
  String get sosAlertSent =>
      'Alerte envoyée. Notre équipe voit votre position.';

  @override
  String get sosAlertFailed =>
      'L’alerte n’a pas pu être envoyée. Appelez directement le numéro.';

  @override
  String get sosSharingLocation =>
      'Votre position est partagée toutes les 10 secondes tant que cet écran est ouvert.';

  @override
  String get sosSending => 'Envoi de l’alerte…';

  @override
  String get callCalling => 'Appel en cours…';

  @override
  String get callRinging => 'Ça sonne…';

  @override
  String get callIncoming => 'Appel entrant';

  @override
  String get callConnecting => 'Connexion…';

  @override
  String get callActive => 'En communication';

  @override
  String get callEnded => 'Appel terminé';

  @override
  String get callRejected => 'Appel refusé';

  @override
  String get callFailed => 'L’appel n’a pas pu aboutir.';

  @override
  String get callMute => 'Muet';

  @override
  String get callUnmute => 'Réactiver le micro';

  @override
  String get callSpeaker => 'Haut-parleur';

  @override
  String get callHangUp => 'Raccrocher';

  @override
  String get callAnswer => 'Répondre';

  @override
  String get callDecline => 'Refuser';

  @override
  String get callMicDenied => 'Autorisez le micro pour passer des appels.';

  @override
  String get callPrivacy => 'Votre numéro n’est pas partagé.';

  @override
  String get callYourDriver => 'Votre chauffeur';

  @override
  String get callYourRider => 'Votre client';

  @override
  String get plateLabel => 'Plaque';

  @override
  String get carLabel => 'Voiture';

  @override
  String get colourLabel => 'Couleur';

  @override
  String get goOnline => 'Passer en ligne';

  @override
  String get goOffline => 'Passer hors ligne';

  @override
  String get onlineLabel => 'En ligne';

  @override
  String get offlineLabel => 'Hors ligne';

  @override
  String onlineNotificationTitle(String app) {
    return '$app — vous êtes en ligne';
  }

  @override
  String get onlineNotificationBody =>
      'Vous recevez les demandes proches de vous.';

  @override
  String get offlineHint => 'Passez en ligne pour recevoir des demandes.';

  @override
  String get requestsTitle => 'Demandes de course';

  @override
  String get noRequests => 'Aucune demande pour le moment. Restez en ligne.';

  @override
  String pickupDistance(String km, int minutes) {
    return '$km km jusqu’au client · $minutes min';
  }

  @override
  String tripDistance(String km) {
    return 'Course : $km km';
  }

  @override
  String get pickupLabel => 'Départ';

  @override
  String get destinationLabel => 'Destination';

  @override
  String get riderLabel => 'Client';

  @override
  String get riderComment => 'Commentaire du client';

  @override
  String acceptFor(int amount) {
    return 'Accepter pour $amount DH';
  }

  @override
  String get proposePrice => 'Ou proposez votre prix';

  @override
  String counterPlus(int amount) {
    return '+$amount DH';
  }

  @override
  String get otherAmount => 'Autre montant';

  @override
  String counterOfferFor(int amount) {
    return 'Proposer $amount DH';
  }

  @override
  String counterMax(int amount) {
    return 'Maximum $amount DH';
  }

  @override
  String waitingForRider(String time) {
    return 'En attente du client… $time';
  }

  @override
  String get withdraw => 'Retirer mon offre';

  @override
  String get bidAccepted => 'Le client a accepté votre offre !';

  @override
  String get bidLost => 'Le client a choisi un autre chauffeur.';

  @override
  String get bidDeclined => 'Le client a refusé votre offre.';

  @override
  String get bidExpired => 'Votre offre a expiré.';

  @override
  String get bidOutdated =>
      'Le client a augmenté le prix. Faites une nouvelle offre.';

  @override
  String get requestClosedTaken => 'Un autre chauffeur a pris cette course.';

  @override
  String get requestClosedGone => 'Cette demande n’est plus disponible.';

  @override
  String get navigate => 'Itinéraire';

  @override
  String get goingToPickup => 'Allez au point de départ';

  @override
  String get iveArrived => 'Je suis arrivé';

  @override
  String get enterPinTitle => 'Entrez le code du client';

  @override
  String get enterPinHint =>
      'Demandez au client le code à 4 chiffres affiché dans son application.';

  @override
  String get startTrip => 'Démarrer la course';

  @override
  String get riderNoShow => 'Le client n’est pas venu';

  @override
  String get riderNoShowInfo =>
      'Après 5 minutes d’attente, vous pouvez annuler sans pénalité.';

  @override
  String waitTime(String time) {
    return 'Attente : $time';
  }

  @override
  String get completeTrip => 'Terminer la course';

  @override
  String collectCash(int amount) {
    return 'Encaissez $amount DH en espèces';
  }

  @override
  String get driverCancelWarning =>
      'Si vous annulez maintenant, vous recevez un point de pénalité. Trop d’annulations vous bloquent un moment.';

  @override
  String blockedUntil(String time) {
    return 'Vous êtes en pause jusqu’à $time à cause des annulations.';
  }

  @override
  String adminMessageTitle(String app) {
    return 'Message de $app';
  }

  @override
  String get earningsTitle => 'Gains';

  @override
  String get earningsToday => 'Aujourd’hui';

  @override
  String get earningsWeek => '7 derniers jours';

  @override
  String earningsTrips(int count) {
    return '$count courses';
  }

  @override
  String earningsCash(int amount) {
    return '$amount DH en espèces';
  }

  @override
  String get earningsNoCommission =>
      '0 % de commission : tout ce que vous encaissez est à vous.';

  @override
  String get documentsTitle => 'Mes documents';

  @override
  String get docCinFront => 'CIN (recto)';

  @override
  String get docCinBack => 'CIN (verso)';

  @override
  String get docLicence => 'Permis de conduire';

  @override
  String get docCarteGrise => 'Carte grise';

  @override
  String get docInsurance => 'Assurance';

  @override
  String get docVisiteTechnique => 'Visite technique';

  @override
  String get docSelfie => 'Selfie';

  @override
  String get docStatusPending => 'En vérification';

  @override
  String get docStatusApproved => 'Validé';

  @override
  String get docStatusRejected => 'Refusé';

  @override
  String get docStatusExpired => 'Expiré';

  @override
  String get docStatusMissing => 'Manquant';

  @override
  String docExpiresOn(String date) {
    return 'Expire le $date';
  }

  @override
  String docExpiringSoon(int days, String doc) {
    return '$doc expire dans $days jours. Envoyez le nouveau dès maintenant.';
  }

  @override
  String get docExpiredBlocked =>
      'Un document a expiré. Vous ne pouvez pas passer en ligne avant d’en envoyer un valide.';

  @override
  String get docUpload => 'Envoyer';

  @override
  String get docReupload => 'Renvoyer';

  @override
  String get docExpiryDate => 'Date d’expiration';

  @override
  String docRejectReason(String reason) {
    return 'Motif : $reason';
  }

  @override
  String get docTakePhoto => 'Prendre une photo';

  @override
  String get docChooseFile => 'Choisir un fichier';

  @override
  String get docPhotoTips =>
      'Posez le document sur une table, avec une bonne lumière. Les 4 coins doivent être visibles et le texte lisible.';

  @override
  String get docUploaded => 'Document envoyé pour vérification.';

  @override
  String get onboardingTitle => 'Devenir chauffeur';

  @override
  String onboardingStep(int step, int total) {
    return 'Étape $step sur $total';
  }

  @override
  String get driverTypeTitle => 'Type de chauffeur';

  @override
  String get driverTypeTaxi => 'Taxi';

  @override
  String get driverTypeLicensedOperator => 'Transport touristique / VTC agréé';

  @override
  String get driverTypePrivateCar => 'Voiture particulière';

  @override
  String get personalInfoTitle => 'Vos informations';

  @override
  String get cinLast4Label => 'Les 4 derniers caractères de votre CIN';

  @override
  String get cinLast4Hint =>
      'Nous gardons seulement ces caractères, pas le numéro complet.';

  @override
  String get licenceIssuedLabel => 'Date de délivrance du permis';

  @override
  String get vehicleTitle => 'Votre voiture';

  @override
  String get vehicleMake => 'Marque';

  @override
  String get vehicleModel => 'Modèle';

  @override
  String get vehicleYear => 'Année';

  @override
  String get vehicleColour => 'Couleur';

  @override
  String get vehiclePlate => 'Immatriculation';

  @override
  String get vehicleDoors => 'Nombre de portes';

  @override
  String get vehicleAc => 'Climatisation';

  @override
  String errorCarTooOld(int year) {
    return 'La voiture doit être de $year ou plus récente.';
  }

  @override
  String get errorCarDoors => 'La voiture doit avoir 4 portes.';

  @override
  String get errorCarNoAc => 'La voiture doit être climatisée.';

  @override
  String get errorLicenceRecent => 'Votre permis doit avoir au moins 3 ans.';

  @override
  String get documentsStepTitle => 'Vos documents';

  @override
  String get submitForReview => 'Envoyer pour vérification';

  @override
  String get underReviewTitle => 'En cours de vérification';

  @override
  String get underReviewBody =>
      'Nous vérifions vos documents. Nous vous préviendrons, en général sous 1 à 2 jours ouvrables.';

  @override
  String get rejectedTitle => 'Demande non acceptée';

  @override
  String rejectedBody(String reason) {
    return 'Motif : $reason. Corrigez puis renvoyez.';
  }

  @override
  String get suspendedTitle => 'Compte suspendu';

  @override
  String get suspendedBody =>
      'Votre compte chauffeur est suspendu. Contactez le support pour en savoir plus.';

  @override
  String get approvedTitle => 'Vous êtes validé !';

  @override
  String batteryTitle(String app) {
    return 'Garder $app actif';
  }

  @override
  String get batteryIntro =>
      'Certains téléphones ferment les applications en arrière-plan pour économiser la batterie. Suivez ces étapes une fois pour ne pas manquer de demandes quand vous êtes en ligne.';

  @override
  String get batteryChooseBrand => 'Choisissez la marque de votre téléphone';

  @override
  String get batteryOther => 'Autre marque';

  @override
  String batteryOpenSettings(String app) {
    return 'Ouvrir les réglages de $app';
  }

  @override
  String get batteryNamesDiffer =>
      'Les noms peuvent changer un peu selon la version du téléphone. Cherchez le plus proche.';

  @override
  String get batteryDone => 'C’est fait';

  @override
  String batteryXiaomi1(String app) {
    return 'Appuyez longuement sur l’icône $app, puis sur « Infos sur l’appli » (ⓘ).';
  }

  @override
  String get batteryXiaomi2 =>
      'Appuyez sur « Économiseur de batterie » et choisissez « Pas de restrictions ».';

  @override
  String get batteryXiaomi3 => 'Activez « Démarrage automatique ».';

  @override
  String get batteryXiaomi4 =>
      'Dans « Autres autorisations », autorisez « Démarrer en arrière-plan » et « Afficher sur l’écran de verrouillage ».';

  @override
  String get batteryXiaomi5 =>
      'Appuyez sur « Autorisations » › « Position » › « Toujours autoriser ».';

  @override
  String batteryXiaomi6(String app) {
    return 'Ouvrez les applis récentes, appuyez longuement sur la carte $app et touchez le cadenas.';
  }

  @override
  String batteryTecno1(String app) {
    return 'Appuyez longuement sur l’icône $app, puis sur « Infos sur l’appli ».';
  }

  @override
  String get batteryTecno2 =>
      'Appuyez sur « Batterie » et choisissez « Sans restriction » (ou activez « Autoriser l’activité en arrière-plan »).';

  @override
  String batteryTecno3(String app) {
    return 'Dans Paramètres › Gestion des applis › « Démarrage auto », activez $app.';
  }

  @override
  String batteryTecno4(String app) {
    return 'Ouvrez « Phone Master » › « Économie d’énergie » et retirez $app des applis fermées automatiquement.';
  }

  @override
  String get batteryTecno5 =>
      'Appuyez sur « Autorisations » › « Position » › « Toujours autoriser ».';

  @override
  String batteryTecno6(String app) {
    return 'Ouvrez les applis récentes et tirez la carte $app vers le bas (ou touchez le cadenas) pour la verrouiller.';
  }

  @override
  String get batteryInfinix1 =>
      'Ouvrez Paramètres › « Batterie » › « Lancement des applis » (ou « Gestion du démarrage auto »).';

  @override
  String batteryInfinix2(String app) {
    return 'Trouvez $app, choisissez « Gérer manuellement » et activez « Lancement auto », « Lancement secondaire » et « Exécution en arrière-plan ».';
  }

  @override
  String batteryInfinix3(String app) {
    return 'Appui long sur l’icône $app › « Infos sur l’appli » › « Batterie » › « Autoriser l’activité en arrière-plan ».';
  }

  @override
  String batteryInfinix4(String app) {
    return 'Dans « Phone Master », désactivez le nettoyage automatique pour $app.';
  }

  @override
  String get batteryInfinix5 =>
      'Dans « Autorisations » › « Position », choisissez « Toujours autoriser ».';

  @override
  String batteryInfinix6(String app) {
    return 'Ouvrez les applis récentes et verrouillez la carte $app.';
  }

  @override
  String batteryOppo1(String app) {
    return 'Appuyez longuement sur l’icône $app, puis sur « Infos sur l’appli ».';
  }

  @override
  String get batteryOppo2 =>
      'Appuyez sur « Utilisation de la batterie » et activez « Autoriser l’activité en arrière-plan », « Autoriser l’activité au premier plan » et « Autoriser le lancement auto ».';

  @override
  String batteryOppo3(String app) {
    return 'Sur les anciens téléphones : Paramètres › « Batterie » › « Plus de paramètres » › « Optimiser l’utilisation de la batterie » › $app › « Ne pas optimiser ».';
  }

  @override
  String get batteryOppo4 =>
      'Appuyez sur « Autorisations » › « Position » › « Toujours autoriser ».';

  @override
  String batteryOppo5(String app) {
    return 'Ouvrez les applis récentes, touchez le menu ⋮ de la carte $app et choisissez « Verrouiller ».';
  }

  @override
  String batterySamsung1(String app) {
    return 'Appuyez longuement sur l’icône $app, puis sur « Infos sur l’appli ».';
  }

  @override
  String get batterySamsung2 =>
      'Appuyez sur « Batterie » et choisissez « Non restreinte ».';

  @override
  String get batterySamsung3 =>
      'Allez dans Paramètres › « Batterie » (ou « Maintenance de l’appareil » › « Batterie ») › « Limites d’utilisation en arrière-plan ».';

  @override
  String batterySamsung4(String app) {
    return 'Vérifiez que $app n’est pas dans « Applis en veille » ou « Applis en veille prolongée », et ajoutez-la aux « Applis jamais en veille ».';
  }

  @override
  String get batterySamsung5 =>
      'Dans Infos sur l’appli › « Autorisations » › « Position », choisissez « Toujours autoriser ».';

  @override
  String batteryGeneric1(String app) {
    return 'Ouvrez Paramètres › « Applications » › $app (ou appui long sur l’icône › « Infos sur l’appli »).';
  }

  @override
  String get batteryGeneric2 =>
      'Dans « Batterie », choisissez « Non restreinte » ou « Ne pas optimiser », ou autorisez l’activité en arrière-plan.';

  @override
  String batteryGeneric3(String app) {
    return 'Si vous voyez « Démarrage auto » ou « Lancement au démarrage », activez-le pour $app.';
  }

  @override
  String get batteryGeneric4 =>
      'Dans « Autorisations » › « Position », choisissez « Toujours autoriser ».';

  @override
  String batteryGeneric5(String app) {
    return 'Quand vous êtes en ligne, ne fermez pas $app depuis les applis récentes.';
  }

  @override
  String get subscriptionTitle => 'Abonnement';

  @override
  String subscriptionPrice(int amount, int days) {
    return '$amount DH pour $days jours';
  }

  @override
  String subscriptionFreeRides(int count) {
    return '$count courses gratuites par jour';
  }

  @override
  String subscriptionRidesToday(int count, int limit) {
    return 'Courses aujourd’hui : $count / $limit';
  }

  @override
  String get subscriptionActive => 'Votre abonnement est actif.';

  @override
  String get subscriptionInactive => 'Aucun abonnement actif.';

  @override
  String get subscriptionPayWith => 'Payer avec';

  @override
  String get payCashplus => 'Espèces chez CashPlus';

  @override
  String get payWafacash => 'Espèces chez Wafacash';

  @override
  String get payCard => 'Carte bancaire';

  @override
  String get payWallet => 'Portefeuille mobile';

  @override
  String get payUnavailable => 'Pas encore disponible';

  @override
  String subscriptionCashCode(
    String agent,
    int amount,
    String code,
    int hours,
  ) {
    return 'Allez dans une agence $agent et donnez ce code : $code. Montant : $amount DH. Valable $hours heures.';
  }

  @override
  String get subscriptionPending => 'Paiement en attente';

  @override
  String get subscriptionOpenPayment => 'Ouvrir la page de paiement';

  @override
  String get subscriptionOff =>
      'L’abonnement n’est pas nécessaire pour l’instant. Toutes les courses sont gratuites.';

  @override
  String get deviceMockTitle => 'Désactivez le faux GPS';

  @override
  String get deviceMockBody =>
      'Une application qui simule votre position est active. Désactivez-la dans les Options pour les développeurs, puis réessayez.';

  @override
  String get deviceRootedTitle =>
      'Ce téléphone ne peut pas être utilisé pour conduire';

  @override
  String get deviceRootedBody =>
      'Ce téléphone a été modifié (rooté). Pour la sécurité de tous, utilisez un autre téléphone.';

  @override
  String get deviceCheckAgain => 'Vérifier à nouveau';

  @override
  String get errNetworkError =>
      'Pas de connexion internet. Vérifiez votre réseau et réessayez.';

  @override
  String get errTimeout => 'Le serveur met trop de temps. Réessayez.';

  @override
  String get errInternal =>
      'Un problème est survenu de notre côté. Réessayez dans un instant.';

  @override
  String get errRateLimited =>
      'Trop de tentatives. Attendez un peu et réessayez.';

  @override
  String get errValidationError =>
      'Certaines informations manquent ou ne sont pas valides.';

  @override
  String get errUpgradeRequired =>
      'Mettez l’application à jour pour continuer.';

  @override
  String get errAuthRequired => 'Connectez-vous.';

  @override
  String get errTokenInvalid => 'Votre session a expiré. Reconnectez-vous.';

  @override
  String get errSessionExpired => 'Votre session a expiré. Reconnectez-vous.';

  @override
  String get errRefreshInvalid => 'Votre session a pris fin. Reconnectez-vous.';

  @override
  String get errRefreshReused =>
      'Pour votre sécurité, vous avez été déconnecté. Reconnectez-vous.';

  @override
  String get errSessionRevoked => 'Votre session a pris fin. Reconnectez-vous.';

  @override
  String get errAccountDisabled =>
      'Ce compte est suspendu. Contactez le support.';

  @override
  String get errWrongRole =>
      'Ce compte ne peut pas être utilisé dans cette application.';

  @override
  String get errInvalidCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get errEmailNotVerified => 'Vérifiez d’abord votre e-mail.';

  @override
  String get errEmailTaken =>
      'Un compte utilise déjà cet e-mail. Connectez-vous ou réinitialisez votre mot de passe.';

  @override
  String get errLoginLocked =>
      'Trop de tentatives. Réessayez dans 15 minutes ou réinitialisez votre mot de passe.';

  @override
  String get errMfaCodeInvalid => 'Code incorrect. Vérifiez-le et réessayez.';

  @override
  String get errMfaLocked =>
      'Trop de codes incorrects. Réessayez dans 15 minutes.';

  @override
  String get errMfaTokenInvalid => 'Cette étape a expiré. Reconnectez-vous.';

  @override
  String get errCodeInvalid => 'Code incorrect. Vérifiez-le et réessayez.';

  @override
  String get errCodeExpired => 'Ce code a expiré. Demandez-en un nouveau.';

  @override
  String get errCodeTooManyAttempts =>
      'Trop d’essais incorrects. Demandez un nouveau code.';

  @override
  String get errResendTooSoon =>
      'Attendez une minute avant de demander un nouveau code.';

  @override
  String get errLinkInvalid =>
      'Ce lien a expiré. Demandez un nouveau code dans l’application.';

  @override
  String get errConsentRequired => 'Acceptez tous les points obligatoires.';

  @override
  String get errConsentOutdated =>
      'Un texte a été mis à jour. Merci de le relire.';

  @override
  String get errPhoneAlreadyVerified =>
      'Votre téléphone est déjà vérifié. Pour le changer, envoyez une demande de correction depuis Profil › Mes données.';

  @override
  String get errPhoneInUse => 'Ce numéro est déjà utilisé par un autre compte.';

  @override
  String get errPhoneCodeLimit =>
      'Vous avez atteint 3 codes aujourd’hui pour ce numéro. Réessayez demain.';

  @override
  String get errOtpSendFailed =>
      'Impossible d’envoyer le code WhatsApp. Vérifiez que le numéro a WhatsApp et réessayez.';

  @override
  String get errPhoneNotVerified =>
      'Vérifiez d’abord votre numéro de téléphone.';

  @override
  String get errIdCheckRequired =>
      'Nous avons besoin d’une photo de votre CIN avant votre prochaine course.';

  @override
  String get errOfferTooLow => 'Votre prix est trop bas pour cette course.';

  @override
  String get errOfferTooHigh => 'Votre prix est trop élevé pour cette course.';

  @override
  String get errOfferNotHigher =>
      'Le nouveau prix doit être plus élevé que l’actuel.';

  @override
  String get errRideAlreadyActive => 'Vous avez déjà une course en cours.';

  @override
  String get errOutOfServiceArea =>
      'Ce lieu est hors de notre zone de service pour l’instant.';

  @override
  String get errTripTooLong =>
      'Cette course est trop longue pour l’application.';

  @override
  String get errBidNotAvailable => 'Cette offre n’est plus disponible.';

  @override
  String get errRideNotSearching =>
      'Cette course ne cherche plus de chauffeur.';

  @override
  String get errDriverBusy =>
      'Ce chauffeur vient de prendre une autre course. Choisissez une autre offre.';

  @override
  String get errCannotCancel => 'Cette course ne peut plus être annulée.';

  @override
  String get errNoShowTooEarly =>
      'Vous pourrez utiliser « Le client n’est pas venu » après 5 minutes d’attente.';

  @override
  String get errRideNotActive => 'Cette course n’est plus active.';

  @override
  String get errRideNotFound => 'Course introuvable.';

  @override
  String get errRideNotCompleted => 'Le reçu est disponible après la course.';

  @override
  String get errAlreadyRated => 'Vous avez déjà noté cette course.';

  @override
  String get errRatingWindowClosed =>
      'Il est trop tard pour noter cette course.';

  @override
  String get errBidAlreadyActive =>
      'Vous avez déjà fait une offre sur cette course.';

  @override
  String get errBidDeclinedBefore =>
      'Le client a refusé votre offre sur cette course.';

  @override
  String get errTooManyBids => 'Vous avez fait trop d’offres sur cette course.';

  @override
  String get errCounterTooLow =>
      'Votre prix doit être plus élevé que l’offre du client.';

  @override
  String get errCounterTooHigh =>
      'Votre prix est trop élevé pour cette course.';

  @override
  String get errTooFar => 'Vous êtes trop loin du point de départ.';

  @override
  String get errSubscriptionRequired =>
      'Vous avez atteint les courses gratuites du jour. Abonnez-vous pour continuer.';

  @override
  String get errDriverNotApproved =>
      'Votre compte chauffeur n’est pas encore validé.';

  @override
  String get errDriverBlocked =>
      'Vous êtes en pause un moment à cause des annulations.';

  @override
  String get errDriverOffline => 'Passez d’abord en ligne.';

  @override
  String get errDocumentsInvalid =>
      'Un document manque, a expiré ou n’est pas encore validé.';

  @override
  String get errDocumentsMissing => 'Certains documents manquent.';

  @override
  String get errDocumentExpired => 'Ce document a expiré.';

  @override
  String get errProfileIncomplete => 'Complétez d’abord vos informations.';

  @override
  String get errVehicleMissing => 'Ajoutez d’abord votre voiture.';

  @override
  String get errProfileLocked =>
      'Votre profil est en vérification et ne peut pas être modifié.';

  @override
  String get errAlreadySubmitted => 'Votre demande a déjà été envoyée.';

  @override
  String get errDriverTypeDisabled =>
      'Ce type de chauffeur n’est pas encore ouvert dans votre ville.';

  @override
  String get errLicenceTooRecent => 'Votre permis doit avoir au moins 3 ans.';

  @override
  String get errCarTooOld => 'La voiture est trop ancienne.';

  @override
  String get errCarDoors => 'La voiture doit avoir 4 portes.';

  @override
  String get errCarNoAc => 'La voiture doit être climatisée.';

  @override
  String get errExpiryRequired => 'Entrez la date d’expiration.';

  @override
  String get errFileType => 'Envoyez une photo (JPEG, PNG) ou un PDF.';

  @override
  String get errFileRequired => 'Choisissez un fichier.';

  @override
  String get errMockLocation => 'Désactivez le faux GPS pour continuer.';

  @override
  String get errRootedDevice =>
      'Ce téléphone ne peut pas être utilisé pour conduire.';

  @override
  String get errIntegrityFailed =>
      'Impossible de vérifier ce téléphone. Utilisez l’application du store officiel ou de notre site.';

  @override
  String get errSelfieRequired => 'Prenez un selfie avant de passer en ligne.';

  @override
  String get errPinInvalid => 'Code incorrect. Redemandez au client.';

  @override
  String get errPinLocked =>
      'Trop de codes incorrects. Notre équipe a été prévenue.';

  @override
  String get errActiveRide =>
      'Terminez ou annulez d’abord votre course en cours.';

  @override
  String get errFeatureDisabled =>
      'Cette fonction est désactivée pour l’instant.';

  @override
  String get errSosNotFound => 'Cette alerte est fermée.';

  @override
  String get errShareNotFound => 'Ce lien a expiré.';

  @override
  String get errTooManyPending =>
      'Vous avez déjà des demandes en attente. Attendez la réponse.';

  @override
  String get errRequestInProgress =>
      'Traitement en cours. Réessayez dans un instant.';

  @override
  String get errIdempotencyKeyReused => 'Un problème est survenu. Réessayez.';

  @override
  String get errNotFound => 'Introuvable.';

  @override
  String get errCityInactive =>
      'Le service n’est pas encore ouvert dans cette ville.';

  @override
  String get errNotADriver => 'Ce n’est pas un compte chauffeur.';
}
