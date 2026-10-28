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
    },
  };

  /// Keys present in every language (tests check completeness).
  static Set<String> keysFor(String lang) => _strings[lang]!.keys.toSet();
}
