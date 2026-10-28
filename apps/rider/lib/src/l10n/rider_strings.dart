import 'package:flutter/widgets.dart';
import 'package:ridema_core/ridema_core.dart';

/// Rider-only strings that are not (yet) in `ridema_core`'s ARB files.
///
/// Kept small and app-local so the shared package stays untouched. Language
/// follows the app locale (ar / fr / en, French fallback — D29).
class RiderStrings {
  const RiderStrings(this.languageCode);

  final String languageCode;

  static RiderStrings of(BuildContext context) => RiderStrings(Localizations.localeOf(context).languageCode);

  String _t(Map<String, String> m) => m[languageCode] ?? m['fr']!;

  String get pickFromContacts => _t({
        'en': 'From my contacts',
        'fr': 'Depuis mes contacts',
        'ar': 'من جهات الاتصال',
      });

  String get contactsPermissionDenied => _t({
        'en': 'Contacts are not allowed. Type the name and number instead.',
        'fr': 'Accès aux contacts refusé. Tapez le nom et le numéro.',
        'ar': 'الوصول إلى جهات الاتصال مرفوض. اكتب الاسم والرقم.',
      });

  String get contactNoPhone => _t({
        'en': 'This contact has no phone number.',
        'fr': 'Ce contact n’a pas de numéro.',
        'ar': 'جهة الاتصال هذه بدون رقم هاتف.',
      });

  String get contactPhoneInvalid => _t({
        'en': 'Enter a valid phone number (06…, 07… or +…).',
        'fr': 'Entrez un numéro valide (06…, 07… ou +…).',
        'ar': 'أدخل رقمًا صحيحًا (06… أو 07… أو +…).',
      });

  String get removeContact => _t({'en': 'Remove', 'fr': 'Retirer', 'ar': 'حذف'});

  String get keepRide => _t({
        'en': 'Keep my ride',
        'fr': 'Garder ma course',
        'ar': 'الاحتفاظ بالرحلة',
      });

  /// Off-app rides (REA P1 #5, D58): a driver asking the rider to cancel and pay directly.
  String get offAppWarning => _t({
        'en': 'Never cancel to pay the driver outside the app. Only rides in RideMA are tracked, with SOS and support.',
        'fr': 'N’annulez jamais pour payer le chauffeur hors de l’application. Seules les courses RideMA sont suivies, avec SOS et assistance.',
        'ar': 'لا تلغِ الرحلة أبدًا لتدفع للسائق خارج التطبيق. وحدها رحلات RideMA تُتابَع، مع زر الطوارئ والمساعدة.',
      });

  String get offAppTitle => _t({
        'en': 'Did the driver ask you to cancel?',
        'fr': 'Le chauffeur vous a demandé d’annuler ?',
        'ar': 'هل طلب منك السائق الإلغاء؟',
      });

  String get offAppBody => _t({
        'en': 'Don’t agree to continue the same trip outside the app. Without RideMA there is no trip log, no shared trip and no SOS alert to our team. Keep the ride in the app and pay the price shown here. If you cancel, we will check this ride.',
        'fr': 'N’acceptez pas de faire la même course hors de l’application. Sans RideMA, pas de suivi du trajet, pas de partage et pas d’alerte SOS à notre équipe. Gardez la course dans l’application et payez le prix affiché ici. Si vous annulez, nous vérifierons cette course.',
        'ar': 'لا توافق على إكمال نفس الرحلة خارج التطبيق. بدون RideMA لا يوجد سجل للرحلة ولا مشاركة لها ولا تنبيه طوارئ لفريقنا. احتفظ بالرحلة في التطبيق وادفع السعر المعروض هنا. إذا ألغيت، سنتحقق من هذه الرحلة.',
      });

  String get keepInApp => _t({
        'en': 'Keep the ride in the app',
        'fr': 'Garder la course dans l’app',
        'ar': 'الاحتفاظ بالرحلة في التطبيق',
      });

  String get driverCancelledTitle => _t({
        'en': 'Your driver cancelled',
        'fr': 'Votre chauffeur a annulé',
        'ar': 'ألغى سائقك الرحلة',
      });

  String get searchAgainBody => _t({
        'en': 'Search again with the same pickup, destination and fare? Drivers nearby will see your request right away.',
        'fr': 'Relancer la recherche avec le même départ, la même destination et le même prix ? Les chauffeurs proches verront votre demande tout de suite.',
        'ar': 'هل تريد البحث من جديد بنفس نقطة الانطلاق والوجهة والسعر؟ سيرى السائقون القريبون طلبك فورًا.',
      });

  String searchAgain(String price) => _t({
        'en': 'Search again ($price)',
        'fr': 'Relancer ($price)',
        'ar': 'البحث من جديد ($price)',
      });

  String get editRequest => _t({
        'en': 'Edit request',
        'fr': 'Modifier la demande',
        'ar': 'تعديل الطلب',
      });

  /// Move the pickup point once after acceptance (D61).
  String get changePickup => _t({
        'en': 'Change pickup point',
        'fr': 'Modifier le point de départ',
        'ar': 'تغيير نقطة الانطلاق',
      });

  String get changePickupTitle => _t({
        'en': 'New pickup point (once, close by, same price)',
        'fr': 'Nouveau point de départ (une fois, tout près, même prix)',
        'ar': 'نقطة انطلاق جديدة (مرة واحدة، قريبة، بنفس السعر)',
      });

  String get pickupMoved => _t({
        'en': 'Pickup point changed. Your driver has the new address.',
        'fr': 'Point de départ modifié. Votre chauffeur a la nouvelle adresse.',
        'ar': 'تم تغيير نقطة الانطلاق. لدى سائقك العنوان الجديد.',
      });

  String get cancelAnyway => _t({
        'en': 'Cancel anyway',
        'fr': 'Annuler quand même',
        'ar': 'إلغاء على أي حال',
      });

  String get cancelCountedTitle => _t({
        'en': 'Cancel after the driver arrived?',
        'fr': 'Annuler alors que le chauffeur est arrivé ?',
        'ar': 'الإلغاء بعد وصول السائق؟',
      });

  String get reportAndCancel => _t({
        'en': 'Report and cancel for free',
        'fr': 'Signaler et annuler gratuitement',
        'ar': 'الإبلاغ والإلغاء مجانًا',
      });

  String get carMismatchDetailsHint => _t({
        'en': 'What is different? (optional)',
        'fr': 'Qu’est-ce qui est différent ? (facultatif)',
        'ar': 'ما المختلف؟ (اختياري)',
      });

  String get raiseAndRetry => _t({
        'en': 'Raise fare and try again',
        'fr': 'Augmenter le prix et réessayer',
        'ar': 'رفع السعر والمحاولة مجددًا',
      });

  String get sameFareRetry => _t({
        'en': 'Try again with the same fare',
        'fr': 'Réessayer au même prix',
        'ar': 'المحاولة بنفس السعر',
      });

  String get backToHome => _t({'en': 'Back to home', 'fr': 'Retour à l’accueil', 'ar': 'العودة إلى الرئيسية'});

  String get mapUnavailable => _t({
        'en': 'Map not available on this build',
        'fr': 'Carte non disponible dans cette version',
        'ar': 'الخريطة غير متوفرة في هذه النسخة',
      });

  String get noAddressFound => _t({
        'en': 'No address found. Try another spelling.',
        'fr': 'Aucune adresse trouvée. Essayez une autre orthographe.',
        'ar': 'لم يتم العثور على عنوان. جرّب كتابة أخرى.',
      });

  String get findingLocation => _t({
        'en': 'Finding your location…',
        'fr': 'Recherche de votre position…',
        'ar': 'جارٍ تحديد موقعك…',
      });

  String get choosePickup => _t({
        'en': 'Choose your pickup point',
        'fr': 'Choisissez votre point de départ',
        'ar': 'اختر نقطة الانطلاق',
      });

  String get chooseDestination => _t({
        'en': 'Choose your destination',
        'fr': 'Choisissez votre destination',
        'ar': 'اختر وجهتك',
      });

  String get gpsPoint => _t({'en': 'GPS point', 'fr': 'Point GPS', 'ar': 'نقطة GPS'});

  /// Search stage line while no offer has come yet (D60).
  String get searchNearby => _t({
        'en': 'Drivers near you can see your request',
        'fr': 'Les chauffeurs proches voient votre demande',
        'ar': 'السائقون القريبون يرون طلبك',
      });

  String get searchNoneYet => _t({
        'en': 'No driver right next to you yet. We are widening the search…',
        'fr': 'Pas encore de chauffeur tout près. Nous élargissons la recherche…',
        'ar': 'لا يوجد سائق قريب جدًا بعد. نحن نوسّع البحث…',
      });

  String searchWider(int metres) {
    final km = (metres / 1000).toStringAsFixed(metres % 1000 == 0 ? 0 : 1);
    return _t({
      'en': 'Search widened to $km km around you',
      'fr': 'Recherche élargie à ${km.replaceAll('.', ',')} km autour de vous',
      'ar': 'تم توسيع البحث إلى $km كم حولك',
    });
  }

  String driversNotified(int count) => _t({
        'en': '$count drivers nearby see your request',
        'fr': '$count chauffeurs à proximité voient votre demande',
        'ar': '$count سائقين بالقرب منك يرون طلبك',
      });

  String moreOffersWaiting(int count) => _t({
        'en': '+$count more offers waiting',
        'fr': '+$count autres offres en attente',
        'ar': '+$count عروض أخرى في الانتظار',
      });

  String get tripCompletedTitle => _t({
        'en': 'You have arrived',
        'fr': 'Vous êtes arrivé',
        'ar': 'لقد وصلت',
      });

  String get offerExpiresIn => _t({'en': 'Offer valid', 'fr': 'Offre valable', 'ar': 'العرض صالح'});

  String get offerAboveYourFare => _t({
        'en': 'Above your fare',
        'fr': 'Au-dessus de votre prix',
        'ar': 'أعلى من سعرك',
      });

  String get yourFare => _t({'en': 'Your fare', 'fr': 'Votre prix', 'ar': 'سعرك'});

  String maxOffer(int amount) => _t({
        'en': 'Maximum: $amount DH',
        'fr': 'Maximum : $amount DH',
        'ar': 'الحد الأقصى: $amount درهم',
      });

  String get enterFare => _t({
        'en': 'Enter your fare in DH',
        'fr': 'Entrez votre prix en DH',
        'ar': 'أدخل سعرك بالدرهم',
      });

  String get decreaseFare => _t({'en': 'Lower by 5 DH', 'fr': 'Baisser de 5 DH', 'ar': 'تخفيض 5 دراهم'});
  String get increaseFare => _t({'en': 'Raise by 5 DH', 'fr': 'Augmenter de 5 DH', 'ar': 'زيادة 5 دراهم'});

  String get shareLinkCopied => _t({
        'en': 'Link created. Choose an app to send it.',
        'fr': 'Lien créé. Choisissez une application pour l’envoyer.',
        'ar': 'تم إنشاء الرابط. اختر تطبيقًا لإرساله.',
      });

  String get menu => _t({'en': 'Menu', 'fr': 'Menu', 'ar': 'القائمة'});

  String get myLocation => _t({'en': 'My location', 'fr': 'Ma position', 'ar': 'موقعي'});

  String get driverLabel => _t({'en': 'Driver', 'fr': 'Chauffeur', 'ar': 'السائق'});

  // ---------------------------------------------------------------- errors

  /// Translations for API codes the shared package does not map.
  String? errorForCode(String code) => switch (code) {
        'RETRY' || 'CONFLICT' || 'INVALID_STATE' => _t({
            'en': 'Something changed in the meantime. Please try again.',
            'fr': 'Quelque chose a changé entre-temps. Réessayez.',
            'ar': 'تغيّر شيء ما في الأثناء. حاول مجددًا.',
          }),
        'BAD_RESPONSE' || 'IDEMPOTENCY_KEY_REQUIRED' || 'NOTHING_TO_UPDATE' || 'VALUE_REQUIRED' || 'MULTIPART_REQUIRED' =>
          _t({
            'en': 'Something went wrong. Please try again.',
            'fr': 'Un problème est survenu. Réessayez.',
            'ar': 'حدث خطأ. حاول مجددًا.',
          }),
        'USER_NOT_FOUND' || 'CITY_NOT_FOUND' || 'LEGAL_NOT_FOUND' => _t({
            'en': 'Not found.',
            'fr': 'Introuvable.',
            'ar': 'غير موجود.',
          }),
        'PICKUP_TOO_FAR' => _t({
            'en': 'This place is too far from your first pickup point. Choose one closer by, or call your driver.',
            'fr': 'Ce lieu est trop loin du premier point de départ. Choisissez-en un plus proche ou appelez votre chauffeur.',
            'ar': 'هذا المكان بعيد جدًا عن نقطة الانطلاق الأولى. اختر مكانًا أقرب أو اتصل بسائقك.',
          }),
        'PICKUP_EDIT_USED' => _t({
            'en': 'You already changed the pickup point for this ride. Call your driver if needed.',
            'fr': 'Vous avez déjà modifié le point de départ pour cette course. Appelez votre chauffeur si besoin.',
            'ar': 'لقد غيّرت نقطة الانطلاق لهذه الرحلة من قبل. اتصل بسائقك عند الحاجة.',
          }),
        'PICKUP_LOCKED' => _t({
            'en': 'Your driver is almost there, so the pickup point can no longer change. Call them if needed.',
            'fr': 'Votre chauffeur est presque là : le point de départ ne peut plus changer. Appelez-le si besoin.',
            'ar': 'سائقك على وشك الوصول، لذا لا يمكن تغيير نقطة الانطلاق. اتصل به عند الحاجة.',
          }),
        'TOO_FAR_FROM_PICKUP' => _t({
            'en': 'Your driver is not at the pickup point yet.',
            'fr': 'Votre chauffeur n’est pas encore au point de départ.',
            'ar': 'سائقك لم يصل بعد إلى نقطة الانطلاق.',
          }),
        'NOT_CONNECTED' => _t({
            'en': 'Not connected. We keep trying…',
            'fr': 'Pas connecté. Nous réessayons…',
            'ar': 'غير متصل. نواصل المحاولة…',
          }),
        _ => null,
      };
}

/// Friendly, localized text for any error: shared translations first, then
/// rider-only codes, then the server message.
String riderErrorText(BuildContext context, Object error) {
  final l = context.l10n;
  if (error is ApiException) {
    final local = RiderStrings.of(context).errorForCode(error.code);
    // The shared code table is private: probe it with a sentinel message.
    const sentinel = '\u0000';
    final sharedKnows = errorText(l, ApiException(error.code, sentinel)) != sentinel;
    if (!sharedKnows && local != null) return local;
  }
  return errorText(l, error);
}
