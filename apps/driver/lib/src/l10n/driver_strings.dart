// Driver-app strings that are not (yet) in ridema_core's ARB files.
// Same three languages (D29). Keep wording simple; prices always "NN DH".
import 'package:flutter/widgets.dart';
import 'package:ridema_core/ridema_core.dart';

import '../controller/driver_controller.dart';
import '../controller/onboarding_validation.dart';

extension DriverStringsContext on BuildContext {
  /// App-local strings for the current locale.
  DriverStrings get ds => DriverStrings(Localizations.localeOf(this).languageCode);
}

class DriverStrings {
  const DriverStrings(this.lang);

  /// `ar`, `fr` or `en`.
  final String lang;

  String _t(String key) => (_strings[lang] ?? _strings['fr']!)[key] ?? _strings['en']![key] ?? key;
  String _f(String key, Map<String, Object> args) {
    var s = _t(key);
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  String get menu => _t('menu');
  String get locationUnavailable => _t('locationUnavailable');
  String get backgroundHint => _t('backgroundHint');
  String get mapPlaceholder => _t('mapPlaceholder');
  String get you => _t('you');
  String counterAbove(int amount) => _f('counterAbove', {'amount': amount});
  // Arrival-time promise with the bid (D66).
  String get etaChoiceTitle => _t('etaChoiceTitle');
  String get etaChoiceHint => _t('etaChoiceHint');
  String etaChoiceMin(int min) => _f('etaChoiceMin', {'min': min});
  String etaPromisedTo(String time) => _f('etaPromisedTo', {'time': time});
  String get youAreLate => _t('youAreLate');
  String get slowDown => _t('slowDown');
  // Request feed: hide / report, alert distance (D68).
  String get requestMore => _t('requestMore');
  String get hideRequest => _t('hideRequest');
  String get reportRequest => _t('reportRequest');
  String get reportRequestTitle => _t('reportRequestTitle');
  String reportReason(String reason) => _t(switch (reason) {
        'fake_request' => 'reportFake',
        'offensive' => 'reportOffensive',
        'wrong_place' => 'reportWrongPlace',
        _ => 'reportOther',
      });
  String get requestHidden => _t('requestHidden');
  String get requestReported => _t('requestReported');
  String get alertsMenu => _t('alertsMenu');
  String get alertsTitle => _t('alertsTitle');
  String get alertsAny => _t('alertsAny');
  String alertsKm(String km) => _f('alertsKm', {'km': km});
  String get alertsHint => _t('alertsHint');
  // "Ready to drive" checklist (D62).
  String get readyTitle => _t('readyTitle');
  String get readyMenu => _t('readyMenu');
  String get readyAllSet => _t('readyAllSet');
  String readyToFix(int count) => _f('readyToFix', {'count': count});
  String readyBanner(int count) => _f('readyBanner', {'count': count});
  String get readyGroupReceive => _t('readyGroupReceive');
  String get readyGroupBackground => _t('readyGroupBackground');
  String get readyFix => _t('readyFix');
  String get readyBatteryGuide => _t('readyBatteryGuide');
  String readyItem(String wire) => _t('ready_$wire');

  String pickupChanged(String? address) =>
      address == null || address.trim().isEmpty ? _t('pickupChanged') : _f('pickupChangedTo', {'address': address.trim()});
  String tooFarFromPickup(int metres) => _f('tooFarFromPickup', {'distance': distance(metres)});

  /// 350 m · 1.2 km (1,2 km in French).
  String distance(int metres) {
    if (metres < 1000) return '$metres ${_t('unitM')}';
    final km = (metres / 1000).toStringAsFixed(1);
    return '${lang == 'fr' ? km.replaceAll('.', ',') : km} ${_t('unitKm')}';
  }
  String get yourPrice => _t('yourPrice');
  String get amountDh => _t('amountDh');
  String get requestExpired => _t('requestExpired');
  String get offerSent => _t('offerSent');
  String get tripCompleteTitle => _t('tripCompleteTitle');
  String get arrivedTitle => _t('arrivedTitle');
  String noShowIn(String time) => _f('noShowIn', {'time': time});
  String get cancelRideTitle => _t('cancelRideTitle');
  String get keepRide => _t('keepRide');
  String get cancelledWithPenalty => _t('cancelledWithPenalty');
  String get cancelledNoPenalty => _t('cancelledNoPenalty');
  String get navigateWith => _t('navigateWith');
  String get googleMaps => _t('googleMaps');
  String get waze => _t('waze');
  String get cityLabel => _t('cityLabel');
  String get chooseDate => _t('chooseDate');
  String docsMissing(int count) => _f('docsMissing', {'count': count});
  String get docsAllSent => _t('docsAllSent');
  String get documentProblemsIntro => _t('documentProblemsIntro');
  String get earningsEmpty => _t('earningsEmpty');
  // Income: month view and daily goal (D82).
  String get earningsMonthTab => _t('earningsMonthTab');
  String get monthPrev => _t('monthPrev');
  String get monthNext => _t('monthNext');
  String get goalTitle => _t('goalTitle');
  String goalProgress(int done, int goal) => _f('goalProgress', {'done': done, 'goal': goal});
  String goalLeft(int left) => _f('goalLeft', {'left': left});
  String get goalReached => _t('goalReached');
  String get goalSet => _t('goalSet');
  String get goalEdit => _t('goalEdit');
  String get goalRemove => _t('goalRemove');
  String get goalHint => _t('goalHint');
  String get goalInvalid => _t('goalInvalid');
  // Preview while under review, first-ride tips (D86).
  String get previewTitle => _t('previewTitle');
  String get previewHint => _t('previewHint');
  String get previewEmpty => _t('previewEmpty');
  String previewTrip(String km) => _f('previewTrip', {'km': km});
  String previewAway(String km) => _f('previewAway', {'km': km});
  String previewAgo(int min) => min < 1 ? _t('previewNow') : _f('previewAgo', {'min': min});
  String get firstRideBanner => _t('firstRideBanner');
  String get firstRideTitle => _t('firstRideTitle');
  String get firstRideIntro => _t('firstRideIntro');
  String get firstRideDone => _t('firstRideDone');
  String firstRideTip(String id) => _t('tip_$id');
  String firstRideTipBody(String id) => _t('tip_${id}_body');
  // Demand map (D87).
  String get demandShow => _t('demandShow');
  String get demandHide => _t('demandHide');
  String demandLegend(int min) => _f('demandLegend', {'min': min});
  String get demandEmpty => _t('demandEmpty');
  String get refresh => _t('refresh');
  String get deviceCheckTitle => _t('deviceCheckTitle');
  String get serviceReopen => _t('serviceReopen');
  String get rideCancelledTitle => _t('rideCancelledTitle');
  String get pinLabel => _t('pinLabel');
  String get resubmit => _t('resubmit');
  String get draftIntro => _t('draftIntro');
  String get onTripTo => _t('onTripTo');
  String get yesCancel => _t('yesCancel');
  String get noShowConfirm => _t('noShowConfirm');
  String get supportLabel => _t('supportLabel');
  String get waitingRiderTitle => _t('waitingRiderTitle');
  String get noVehicleYet => _t('noVehicleYet');
  String get acNo => _t('acNo');
  String get acYes => _t('acYes');
  String get loadFailed => _t('loadFailed');
  String get batteryMenu => _t('batteryMenu');
  String get expiresIn30 => _t('expiresIn30');
  String get onlineSwitchHint => _t('onlineSwitchHint');
  String get pinIncomplete => _t('pinIncomplete');
  String get rateRiderHint => _t('rateRiderHint');
  String get fileTooLarge => _t('fileTooLarge');
  String get subscriptionMenu => _t('subscriptionMenu');
  String get onlineRestored => _t('onlineRestored');

  /// Onboarding validation key → text.
  String validation(AppLocalizations l, String key, {DateTime? today}) => switch (key) {
        OnboardingError.required => l.required,
        OnboardingError.driverTypeDisabled => l.errDriverTypeDisabled,
        OnboardingError.cinFormat => _t('cinFormat'),
        OnboardingError.licenceFuture => _t('dateFuture'),
        OnboardingError.licenceTooRecent => l.errorLicenceRecent,
        OnboardingError.yearInvalid => _t('yearInvalid'),
        OnboardingError.carTooOld => l.errorCarTooOld(const OnboardingRules().minCarYear(today ?? DateTime.now())),
        OnboardingError.doors => l.errorCarDoors,
        OnboardingError.noAc => l.errorCarNoAc,
        OnboardingError.plateFormat => _t('plateFormat'),
        OnboardingError.expiryRequired => l.errExpiryRequired,
        OnboardingError.expiryPast => _t('expiryPast'),
        OnboardingError.fileRequired => l.errFileRequired,
        _ => key,
      };

  /// Any error (API code, local [DriverFailure] code) → friendly text.
  String error(AppLocalizations l, Object e) {
    final f = DriverFailure.from(e);
    switch (f.code) {
      case DriverFailure.locationUnavailable:
        return locationUnavailable;
      case DriverFailure.counterTooLow:
        final d = f.details;
        final min = d is Map ? d['min'] : null;
        return min is int ? counterAbove(min - 1) : l.errCounterTooLow;
      case 'TOO_FAR_FROM_PICKUP':
        final d = f.details;
        final m = d is Map ? d['distance_m'] : null;
        return tooFarFromPickup(m is num ? m.round() : 0);
      case 'COUNTER_TOO_HIGH':
        final d = f.details;
        final max = d is Map ? d['max'] : null;
        return max is num ? '${l.errCounterTooHigh} ${l.counterMax(max.toInt())}' : l.errCounterTooHigh;
    }
    return errorText(l, ApiException(f.code, f.message, status: f.status, details: f.details));
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'fileTooLarge': 'This file is too large (max 8 MB). Take a photo instead.',
      'subscriptionMenu': 'Subscription',
      'onlineRestored': 'You are online again.',
      'menu': 'Menu',
      'locationUnavailable': 'We could not get your position. Check that location is on and allowed for RideMA.',
      'backgroundHint': 'Tip: allow location “All the time” so riders can follow you when the app is in the background.',
      'mapPlaceholder': 'Map preview (Google Maps is not configured in this build)',
      'you': 'You',
      'counterAbove': 'Enter an amount above {amount} DH.',
      'tooFarFromPickup': 'You are {distance} from the pickup point. Tap “I’ve arrived” when you get there.',
      'pickupChanged': 'The rider moved the pickup point. Check the new route.',
      'readyTitle': 'Ready to drive',
      'readyMenu': 'Ready to drive check',
      'readyAllSet': 'All set. You will get ride requests, even with the app in the background.',
      'readyToFix': '{count} to fix so you don’t miss ride requests',
      'readyBanner': 'Your phone may hide ride requests. Tap to fix ({count}).',
      'readyGroupReceive': 'To receive requests',
      'readyGroupBackground': 'To keep working in the background',
      'readyFix': 'Fix',
      'readyBatteryGuide': 'Battery setup for my phone brand',
      'ready_location_service': 'Location turned on',
      'ready_airplane': 'Airplane mode off',
      'ready_notifications': 'Notifications allowed for RideMA',
      'ready_request_channel': '“New ride requests” notifications on',
      'ready_location_always': 'Location allowed “All the time”',
      'ready_battery_optimized': 'Battery optimisation off for RideMA',
      'ready_background_restricted': 'Background activity allowed',
      'ready_power_save': 'Battery saver off',
      'ready_dnd': '“Do not disturb” off',
      'pickupChangedTo': 'New pickup point: {address}. Check the new route.',
      'unitM': 'm',
      'unitKm': 'km',
      'yourPrice': 'Your price',
      'amountDh': 'Amount (DH)',
      'requestExpired': 'This request has expired.',
      'offerSent': 'Offer sent. Waiting for the rider.',
      'tripCompleteTitle': 'Trip complete',
      'arrivedTitle': 'You have arrived. Waiting for the rider.',
      'noShowIn': '“Rider didn’t come” available in {time}',
      'cancelRideTitle': 'Cancel this ride?',
      'keepRide': 'Keep the ride',
      'cancelledWithPenalty': 'Ride cancelled. A penalty point was added.',
      'cancelledNoPenalty': 'Ride cancelled without penalty.',
      'navigateWith': 'Navigate with',
      'googleMaps': 'Google Maps',
      'waze': 'Waze',
      'cityLabel': 'City',
      'chooseDate': 'Choose a date',
      'docsMissing': '{count} document(s) still to upload.',
      'docsAllSent': 'All documents are uploaded.',
      'documentProblemsIntro': 'To go online, fix these documents:',
      'earningsEmpty': 'No trips in this period yet.',
      'earningsMonthTab': 'Month',
      'monthPrev': 'Previous month',
      'monthNext': 'Next month',
      'goalTitle': 'Daily goal',
      'goalProgress': '{done} / {goal} DH today',
      'goalLeft': '{left} DH to go',
      'goalReached': 'Goal reached. Well done!',
      'goalSet': 'Set a daily goal',
      'goalEdit': 'Change goal',
      'goalRemove': 'Remove goal',
      'goalHint': 'How much do you want to collect each day? (DH)',
      'goalInvalid': 'Enter an amount between 10 and 5000 DH.',
      'previewTitle': 'Requests right now',
      'previewHint': 'A preview while we check your documents: areas only, no rider details. You can make offers once your account is approved.',
      'previewEmpty': 'No open request in your city at the moment.',
      'previewTrip': '{km} km trip',
      'previewAway': 'about {km} km from you',
      'previewAgo': '{min} min ago',
      'previewNow': 'just now',
      'firstRideBanner': 'You are approved! 5 tips for your first ride',
      'firstRideTitle': 'Your first ride',
      'firstRideIntro': 'Tick each one when you are ready.',
      'firstRideDone': 'Got it',
      'tip_ready': 'Run the “Ready to drive” check',
      'tip_ready_body': 'Fix anything in red so requests reach you, even with the screen off.',
      'tip_online': 'Go online where riders are',
      'tip_online_body': 'Train stations, the medina gates and big shops get many requests.',
      'tip_offer': 'Answer quickly',
      'tip_offer_body': 'Accept the rider’s fare or send a counter-offer. The rider sees your offer for about a minute.',
      'tip_pin': 'Ask for the PIN before you start',
      'tip_pin_body': 'The rider tells you a 4-digit code. It confirms you picked up the right person.',
      'tip_cash': 'Collect cash, then rate the rider',
      'tip_cash_body': 'The app shows the total to collect, waiting fee included. RideMA takes 0 % commission.',
      'demandShow': 'Show where riders ask',
      'demandHide': 'Hide demand',
      'demandLegend': 'Where riders asked in the last {min} min',
      'demandEmpty': 'Few requests right now',
      'refresh': 'Refresh',
      'deviceCheckTitle': 'Phone check',
      'serviceReopen': 'Open RideMA to stay online.',
      'rideCancelledTitle': 'Ride cancelled',
      'pinLabel': 'PIN',
      'resubmit': 'Fix my application',
      'draftIntro': 'Complete these steps. We review your application before you can drive.',
      'onTripTo': 'Drive to the destination',
      'yesCancel': 'Yes, cancel',
      'noShowConfirm': 'Cancel because the rider did not come? There is no penalty.',
      'supportLabel': 'Support',
      'waitingRiderTitle': 'Offer sent',
      'noVehicleYet': 'No car added yet.',
      'acNo': 'No',
      'acYes': 'Yes',
      'loadFailed': 'Could not load. Check your connection and try again.',
      'batteryMenu': 'Battery settings',
      'expiresIn30': 'Expires within 30 days',
      'onlineSwitchHint': 'Tap to go online',
      'pinIncomplete': 'Enter the 4 digits.',
      'rateRiderHint': 'Your rating helps keep drivers safe.',
      'cinFormat': 'Type 2 to 4 letters or digits.',
      'dateFuture': 'The date cannot be in the future.',
      'yearInvalid': 'Enter a valid year.',
      'plateFormat': 'Type the plate as written on the car, for example 12345-A-6.',
      'expiryPast': 'This document has expired. Upload a valid one.',
      'etaChoiceTitle': 'I can be at the pickup in (optional)',
      'etaChoiceHint': 'The rider sees your promise. Arriving late is recorded.',
      'etaChoiceMin': '{min} min',
      'etaPromisedTo': 'You promised to be there by {time}',
      'youAreLate': 'You are late for the pickup. The rider can now cancel for free.',
      'slowDown': 'You are driving fast. Please slow down: your rider’s safety comes first.',
      'requestMore': 'More actions',
      'hideRequest': 'Hide this request',
      'reportRequest': 'Report this request',
      'reportRequestTitle': 'What is wrong with this request?',
      'reportFake': 'Looks fake or a joke',
      'reportOffensive': 'Offensive comment',
      'reportWrongPlace': 'Pickup or destination makes no sense',
      'reportOther': 'Something else',
      'requestHidden': 'Request hidden. You won’t see it again.',
      'requestReported': 'Thanks. Our team will check this request.',
      'alertsMenu': 'Request alerts',
      'alertsTitle': 'Alert me for pickups within',
      'alertsAny': 'Any distance',
      'alertsKm': '{km} km',
      'alertsHint': 'Farther requests still appear in the list, without a sound or notification.',
    },
    'fr': {
      'fileTooLarge': 'Fichier trop lourd (8 Mo max). Prenez plutôt une photo.',
      'subscriptionMenu': 'Abonnement',
      'onlineRestored': 'Vous êtes de nouveau en ligne.',
      'menu': 'Menu',
      'locationUnavailable': 'Impossible d’obtenir votre position. Vérifiez que la localisation est activée et autorisée pour RideMA.',
      'backgroundHint': 'Conseil : autorisez la position « Toujours » pour que les clients vous suivent quand l’app est en arrière-plan.',
      'mapPlaceholder': 'Aperçu de la carte (Google Maps n’est pas configuré dans cette version)',
      'you': 'Vous',
      'counterAbove': 'Entrez un montant supérieur à {amount} DH.',
      'tooFarFromPickup': 'Vous êtes à {distance} du point de prise en charge. Appuyez sur « Je suis arrivé » une fois sur place.',
      'pickupChanged': 'Le passager a déplacé le point de prise en charge. Vérifiez le nouvel itinéraire.',
      'readyTitle': 'Prêt à rouler',
      'readyMenu': 'Vérifier mon téléphone',
      'readyAllSet': 'Tout est prêt. Vous recevrez les demandes, même avec l’application en arrière-plan.',
      'readyToFix': '{count} à corriger pour ne pas manquer de demandes',
      'readyBanner': 'Votre téléphone peut masquer des demandes. Touchez pour corriger ({count}).',
      'readyGroupReceive': 'Pour recevoir les demandes',
      'readyGroupBackground': 'Pour fonctionner en arrière-plan',
      'readyFix': 'Corriger',
      'readyBatteryGuide': 'Réglages batterie pour ma marque',
      'ready_location_service': 'Localisation activée',
      'ready_airplane': 'Mode avion désactivé',
      'ready_notifications': 'Notifications autorisées pour RideMA',
      'ready_request_channel': 'Notifications « Nouvelles demandes » activées',
      'ready_location_always': 'Localisation autorisée « Toujours »',
      'ready_battery_optimized': 'Optimisation de la batterie désactivée pour RideMA',
      'ready_background_restricted': 'Activité en arrière-plan autorisée',
      'ready_power_save': 'Économiseur de batterie désactivé',
      'ready_dnd': '« Ne pas déranger » désactivé',
      'pickupChangedTo': 'Nouveau point de prise en charge : {address}. Vérifiez le nouvel itinéraire.',
      'unitM': 'm',
      'unitKm': 'km',
      'yourPrice': 'Votre prix',
      'amountDh': 'Montant (DH)',
      'requestExpired': 'Cette demande a expiré.',
      'offerSent': 'Offre envoyée. En attente du client.',
      'tripCompleteTitle': 'Course terminée',
      'arrivedTitle': 'Vous êtes arrivé. En attente du client.',
      'noShowIn': '« Le client n’est pas venu » disponible dans {time}',
      'cancelRideTitle': 'Annuler cette course ?',
      'keepRide': 'Garder la course',
      'cancelledWithPenalty': 'Course annulée. Un point de pénalité a été ajouté.',
      'cancelledNoPenalty': 'Course annulée sans pénalité.',
      'navigateWith': 'Naviguer avec',
      'googleMaps': 'Google Maps',
      'waze': 'Waze',
      'cityLabel': 'Ville',
      'chooseDate': 'Choisir une date',
      'docsMissing': 'Encore {count} document(s) à envoyer.',
      'docsAllSent': 'Tous les documents sont envoyés.',
      'documentProblemsIntro': 'Pour passer en ligne, réglez ces documents :',
      'earningsEmpty': 'Aucune course sur cette période.',
      'earningsMonthTab': 'Mois',
      'monthPrev': 'Mois précédent',
      'monthNext': 'Mois suivant',
      'goalTitle': 'Objectif du jour',
      'goalProgress': '{done} / {goal} DH aujourd’hui',
      'goalLeft': 'Encore {left} DH',
      'goalReached': 'Objectif atteint. Bravo !',
      'goalSet': 'Fixer un objectif par jour',
      'goalEdit': 'Modifier l’objectif',
      'goalRemove': 'Supprimer l’objectif',
      'goalHint': 'Combien voulez-vous encaisser par jour ? (DH)',
      'goalInvalid': 'Entrez un montant entre 10 et 5000 DH.',
      'previewTitle': 'Demandes en ce moment',
      'previewHint': 'Un aperçu pendant que nous vérifions vos documents : quartiers seulement, aucune donnée du passager. Vous pourrez faire des offres une fois votre compte validé.',
      'previewEmpty': 'Aucune demande ouverte dans votre ville pour le moment.',
      'previewTrip': 'course de {km} km',
      'previewAway': 'à environ {km} km de vous',
      'previewAgo': 'il y a {min} min',
      'previewNow': 'à l’instant',
      'firstRideBanner': 'Compte validé ! 5 conseils pour votre première course',
      'firstRideTitle': 'Votre première course',
      'firstRideIntro': 'Cochez chaque point quand vous êtes prêt.',
      'firstRideDone': 'C’est compris',
      'tip_ready': 'Faites la vérification « Prêt à rouler »',
      'tip_ready_body': 'Corrigez ce qui est en rouge pour recevoir les demandes, même écran éteint.',
      'tip_online': 'Passez en ligne là où sont les passagers',
      'tip_online_body': 'Les gares, les portes de la médina et les grands magasins reçoivent beaucoup de demandes.',
      'tip_offer': 'Répondez vite',
      'tip_offer_body': 'Acceptez le prix du passager ou faites une contre-offre. Le passager voit votre offre pendant environ une minute.',
      'tip_pin': 'Demandez le code PIN avant de démarrer',
      'tip_pin_body': 'Le passager vous donne un code à 4 chiffres. Il confirme que c’est la bonne personne.',
      'tip_cash': 'Encaissez en espèces, puis notez le passager',
      'tip_cash_body': 'L’application affiche le total à encaisser, frais d’attente compris. RideMA prend 0 % de commission.',
      'demandShow': 'Voir où les passagers demandent',
      'demandHide': 'Masquer la demande',
      'demandLegend': 'Demandes des {min} dernières minutes',
      'demandEmpty': 'Peu de demandes en ce moment',
      'refresh': 'Actualiser',
      'deviceCheckTitle': 'Vérification du téléphone',
      'serviceReopen': 'Ouvrez RideMA pour rester en ligne.',
      'rideCancelledTitle': 'Course annulée',
      'pinLabel': 'Code',
      'resubmit': 'Corriger ma demande',
      'draftIntro': 'Complétez ces étapes. Nous vérifions votre dossier avant que vous puissiez conduire.',
      'onTripTo': 'Roulez vers la destination',
      'yesCancel': 'Oui, annuler',
      'noShowConfirm': 'Annuler car le client n’est pas venu ? Il n’y a pas de pénalité.',
      'supportLabel': 'Assistance',
      'waitingRiderTitle': 'Offre envoyée',
      'noVehicleYet': 'Aucune voiture ajoutée.',
      'acNo': 'Non',
      'acYes': 'Oui',
      'loadFailed': 'Chargement impossible. Vérifiez votre connexion et réessayez.',
      'batteryMenu': 'Réglages batterie',
      'expiresIn30': 'Expire dans moins de 30 jours',
      'onlineSwitchHint': 'Touchez pour passer en ligne',
      'pinIncomplete': 'Entrez les 4 chiffres.',
      'rateRiderHint': 'Votre note aide à protéger les chauffeurs.',
      'cinFormat': 'Tapez 2 à 4 lettres ou chiffres.',
      'dateFuture': 'La date ne peut pas être dans le futur.',
      'yearInvalid': 'Entrez une année valide.',
      'plateFormat': 'Tapez la plaque comme sur la voiture, par exemple 12345-A-6.',
      'expiryPast': 'Ce document a expiré. Envoyez un document valide.',
      'etaChoiceTitle': 'Je peux être au départ dans (facultatif)',
      'etaChoiceHint': 'Le passager voit votre promesse. Les retards sont enregistrés.',
      'etaChoiceMin': '{min} min',
      'etaPromisedTo': 'Vous avez promis d’être là à {time}',
      'youAreLate': 'Vous êtes en retard au départ. Le passager peut maintenant annuler gratuitement.',
      'slowDown': 'Vous roulez vite. Ralentissez s’il vous plaît : la sécurité du passager passe d’abord.',
      'requestMore': 'Plus d’actions',
      'hideRequest': 'Masquer cette demande',
      'reportRequest': 'Signaler cette demande',
      'reportRequestTitle': 'Quel est le problème avec cette demande ?',
      'reportFake': 'Semble fausse ou une blague',
      'reportOffensive': 'Commentaire insultant',
      'reportWrongPlace': 'Départ ou destination incohérents',
      'reportOther': 'Autre chose',
      'requestHidden': 'Demande masquée. Vous ne la verrez plus.',
      'requestReported': 'Merci. Notre équipe va vérifier cette demande.',
      'alertsMenu': 'Alertes de demandes',
      'alertsTitle': 'M’alerter pour les départs à moins de',
      'alertsAny': 'Toute distance',
      'alertsKm': '{km} km',
      'alertsHint': 'Les demandes plus lointaines restent dans la liste, sans son ni notification.',
    },
    'ar': {
      'fileTooLarge': 'الملف كبير جدًا (8 ميغابايت كحد أقصى). التقط صورة بدلًا منه.',
      'subscriptionMenu': 'الاشتراك',
      'onlineRestored': 'أنت متصل من جديد.',
      'menu': 'القائمة',
      'locationUnavailable': 'تعذّر تحديد موقعك. تأكد من تشغيل الموقع والسماح به لتطبيق RideMA.',
      'backgroundHint': 'نصيحة: اسمح بالموقع «طوال الوقت» حتى يتابعك الزبناء عندما يكون التطبيق في الخلفية.',
      'mapPlaceholder': 'معاينة الخريطة (خرائط Google غير مفعّلة في هذه النسخة)',
      'you': 'أنت',
      'counterAbove': 'أدخل مبلغًا أكبر من {amount} درهم.',
      'tooFarFromPickup': 'أنت على بعد {distance} من نقطة الانطلاق. اضغط على «لقد وصلت» عندما تصل إليها.',
      'pickupChanged': 'غيّر الراكب نقطة الانطلاق. تحقق من المسار الجديد.',
      'readyTitle': 'جاهز للقيادة',
      'readyMenu': 'فحص الهاتف',
      'readyAllSet': 'كل شيء جاهز. ستصلك طلبات الرحلات حتى والتطبيق في الخلفية.',
      'readyToFix': '{count} للإصلاح حتى لا تفوتك الطلبات',
      'readyBanner': 'قد يُخفي هاتفك طلبات الرحلات. اضغط للإصلاح ({count}).',
      'readyGroupReceive': 'لاستقبال الطلبات',
      'readyGroupBackground': 'للعمل في الخلفية',
      'readyFix': 'إصلاح',
      'readyBatteryGuide': 'إعدادات البطارية حسب نوع هاتفي',
      'ready_location_service': 'الموقع مفعّل',
      'ready_airplane': 'وضع الطيران متوقف',
      'ready_notifications': 'الإشعارات مسموحة لـ RideMA',
      'ready_request_channel': 'إشعارات «طلبات رحلات جديدة» مفعّلة',
      'ready_location_always': 'الموقع مسموح «طوال الوقت»',
      'ready_battery_optimized': 'تحسين البطارية متوقف لـ RideMA',
      'ready_background_restricted': 'النشاط في الخلفية مسموح',
      'ready_power_save': 'موفّر البطارية متوقف',
      'ready_dnd': '«عدم الإزعاج» متوقف',
      'pickupChangedTo': 'نقطة الانطلاق الجديدة: {address}. تحقق من المسار الجديد.',
      'unitM': 'م',
      'unitKm': 'كم',
      'yourPrice': 'ثمنك',
      'amountDh': 'المبلغ (درهم)',
      'requestExpired': 'انتهت صلاحية هذا الطلب.',
      'offerSent': 'تم إرسال العرض. في انتظار الزبون.',
      'tripCompleteTitle': 'انتهت الرحلة',
      'arrivedTitle': 'لقد وصلت. في انتظار الزبون.',
      'noShowIn': '«الزبون لم يأتِ» متاح بعد {time}',
      'cancelRideTitle': 'إلغاء هذه الرحلة؟',
      'keepRide': 'الاحتفاظ بالرحلة',
      'cancelledWithPenalty': 'تم إلغاء الرحلة. أضيفت نقطة جزاء.',
      'cancelledNoPenalty': 'تم إلغاء الرحلة بدون جزاء.',
      'navigateWith': 'التوجيه عبر',
      'googleMaps': 'خرائط Google',
      'waze': 'Waze',
      'cityLabel': 'المدينة',
      'chooseDate': 'اختر تاريخًا',
      'docsMissing': 'ما زال {count} وثيقة للإرسال.',
      'docsAllSent': 'تم إرسال كل الوثائق.',
      'documentProblemsIntro': 'لتصبح متصلًا، صحّح هذه الوثائق:',
      'earningsEmpty': 'لا توجد رحلات في هذه الفترة.',
      'earningsMonthTab': 'الشهر',
      'monthPrev': 'الشهر السابق',
      'monthNext': 'الشهر التالي',
      'goalTitle': 'هدف اليوم',
      'goalProgress': '{done} / {goal} درهم اليوم',
      'goalLeft': 'باقي {left} درهم',
      'goalReached': 'تم بلوغ الهدف. أحسنت!',
      'goalSet': 'حدّد هدفًا يوميًا',
      'goalEdit': 'تغيير الهدف',
      'goalRemove': 'حذف الهدف',
      'goalHint': 'كم تريد أن تحصّل كل يوم؟ (درهم)',
      'goalInvalid': 'أدخل مبلغًا بين 10 و5000 درهم.',
      'previewTitle': 'الطلبات الآن',
      'previewHint': 'معاينة أثناء التحقق من وثائقك: الأحياء فقط، دون أي معلومات عن الراكب. يمكنك تقديم العروض بعد قبول حسابك.',
      'previewEmpty': 'لا يوجد طلب مفتوح في مدينتك حاليًا.',
      'previewTrip': 'رحلة {km} كلم',
      'previewAway': 'على بعد {km} كلم منك تقريبًا',
      'previewAgo': 'منذ {min} د',
      'previewNow': 'الآن',
      'firstRideBanner': 'تم قبول حسابك! 5 نصائح لرحلتك الأولى',
      'firstRideTitle': 'رحلتك الأولى',
      'firstRideIntro': 'ضع علامة على كل نقطة عندما تكون جاهزًا.',
      'firstRideDone': 'فهمت',
      'tip_ready': 'قم بفحص «جاهز للقيادة»',
      'tip_ready_body': 'أصلح كل ما هو باللون الأحمر حتى تصلك الطلبات، حتى والشاشة مطفأة.',
      'tip_online': 'اتصل حيث يوجد الركاب',
      'tip_online_body': 'محطات القطار وأبواب المدينة القديمة والمتاجر الكبرى تتلقى طلبات كثيرة.',
      'tip_offer': 'أجب بسرعة',
      'tip_offer_body': 'اقبل ثمن الراكب أو قدّم عرضًا مضادًا. يرى الراكب عرضك لمدة دقيقة تقريبًا.',
      'tip_pin': 'اطلب الرمز قبل الانطلاق',
      'tip_pin_body': 'يعطيك الراكب رمزًا من 4 أرقام. يؤكد أن الراكب الذي معك هو الشخص الصحيح.',
      'tip_cash': 'استلم الثمن نقدًا ثم قيّم الراكب',
      'tip_cash_body': 'يعرض التطبيق المبلغ الإجمالي، بما فيه رسوم الانتظار. عمولة RideMA هي 0 %.',
      'demandShow': 'أظهر أين يطلب الركاب',
      'demandHide': 'إخفاء الطلب',
      'demandLegend': 'أماكن الطلبات في آخر {min} دقيقة',
      'demandEmpty': 'طلبات قليلة الآن',
      'refresh': 'تحديث',
      'deviceCheckTitle': 'فحص الهاتف',
      'serviceReopen': 'افتح RideMA لتبقى متصلًا.',
      'rideCancelledTitle': 'أُلغيت الرحلة',
      'pinLabel': 'الرمز',
      'resubmit': 'تصحيح طلبي',
      'draftIntro': 'أكمل هذه الخطوات. نراجع ملفك قبل أن تبدأ السياقة.',
      'onTripTo': 'توجّه إلى الوجهة',
      'yesCancel': 'نعم، إلغاء',
      'noShowConfirm': 'إلغاء لأن الزبون لم يأتِ؟ لا يوجد جزاء.',
      'supportLabel': 'الدعم',
      'waitingRiderTitle': 'تم إرسال العرض',
      'noVehicleYet': 'لم تتم إضافة سيارة بعد.',
      'acNo': 'لا',
      'acYes': 'نعم',
      'loadFailed': 'تعذّر التحميل. تحقق من الاتصال وحاول مرة أخرى.',
      'batteryMenu': 'إعدادات البطارية',
      'expiresIn30': 'تنتهي خلال أقل من 30 يومًا',
      'onlineSwitchHint': 'اضغط لتصبح متصلًا',
      'pinIncomplete': 'أدخل الأرقام الأربعة.',
      'rateRiderHint': 'تقييمك يساعد على حماية السائقين.',
      'cinFormat': 'اكتب من 2 إلى 4 حروف أو أرقام.',
      'dateFuture': 'لا يمكن أن يكون التاريخ في المستقبل.',
      'yearInvalid': 'أدخل سنة صحيحة.',
      'plateFormat': 'اكتب رقم اللوحة كما هو على السيارة، مثلًا 12345-A-6.',
      'expiryPast': 'هذه الوثيقة منتهية الصلاحية. أرسل وثيقة صالحة.',
      'etaChoiceTitle': 'يمكنني الوصول إلى نقطة الانطلاق خلال (اختياري)',
      'etaChoiceHint': 'يرى الراكب وعدك. يُسجَّل التأخر.',
      'etaChoiceMin': '{min} د',
      'etaPromisedTo': 'وعدت بالوصول قبل {time}',
      'youAreLate': 'أنت متأخر عن نقطة الانطلاق. يمكن للراكب الآن الإلغاء مجانًا.',
      'slowDown': 'أنت تسير بسرعة. خفّف السرعة من فضلك: سلامة الراكب أولًا.',
      'requestMore': 'إجراءات أخرى',
      'hideRequest': 'إخفاء هذا الطلب',
      'reportRequest': 'الإبلاغ عن هذا الطلب',
      'reportRequestTitle': 'ما المشكلة في هذا الطلب؟',
      'reportFake': 'يبدو مزيفًا أو مزحة',
      'reportOffensive': 'تعليق مسيء',
      'reportWrongPlace': 'نقطة الانطلاق أو الوجهة غير منطقية',
      'reportOther': 'شيء آخر',
      'requestHidden': 'تم إخفاء الطلب. لن تراه مجددًا.',
      'requestReported': 'شكرًا. سيتحقق فريقنا من هذا الطلب.',
      'alertsMenu': 'تنبيهات الطلبات',
      'alertsTitle': 'نبّهني للطلبات ضمن مسافة',
      'alertsAny': 'أي مسافة',
      'alertsKm': '{km} كم',
      'alertsHint': 'تبقى الطلبات الأبعد في القائمة، بدون صوت أو إشعار.',
    },
  };

  /// Keys present in every language (tests check completeness).
  static Set<String> keysFor(String lang) => _strings[lang]!.keys.toSet();
}
